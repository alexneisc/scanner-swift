import AVFoundation
import UIKit

struct Entry: Identifiable {
    let id = UUID()
    let type: String
    let text: String
    let ms: Int
}

enum ScanFailure: Error { case cancelled, message(String) }

private let formats: [(AVMetadataObject.ObjectType, String)] = [
    (.upce, "UPC-E"), (.ean8, "EAN-8"), (.ean13, "EAN-13"),
    (.code39, "Code 39"), (.code93, "Code 93"), (.code128, "Code 128"),
    (.interleaved2of5, "ITF"), (.aztec, "Aztec"), (.dataMatrix, "Data Matrix"),
    (.pdf417, "PDF417"), (.qr, "QR"),
    (.gs1DataBar, "GS1 DataBar"), (.gs1DataBarLimited, "GS1 DataBar Limited"),
    (.gs1DataBarExpanded, "GS1 DataBar Expanded"),
]

final class Scanner: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    let session = AVCaptureSession()
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    private var device: AVCaptureDevice?
    private var continuation: CheckedContinuation<Entry, Error>?
    private var t0: CFAbsoluteTime = 0

    func requestPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    /// Timer starts here (after permission). `onReady` is called on main once the session is configured.
    func scan(onReady: () -> Void) async throws -> Entry {
        t0 = CFAbsoluteTimeGetCurrent()
        try configure()
        onReady()
        return try await withCheckedThrowingContinuation { c in
            continuation = c
            DispatchQueue.global(qos: .userInitiated).async { [session] in session.startRunning() }
        }
    }

    private func configure() throws {
        let types: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera,
        ]
        guard let dev = types.lazy.compactMap({ AVCaptureDevice.default($0, for: .video, position: .back) }).first
        else { throw ScanFailure.message("No camera available") }
        print("[Scanner] camera: \(dev.deviceType.rawValue)")
        let input = try AVCaptureDeviceInput(device: dev)
        guard session.canAddInput(input) else { throw ScanFailure.message("Cannot add camera input") }
        session.addInput(input)
        do {
            try dev.lockForConfiguration()
            if dev.isVirtualDevice, let first = dev.virtualDeviceSwitchOverVideoZoomFactors.first {
                dev.videoZoomFactor = CGFloat(truncating: first)
            }
            if dev.isAutoFocusRangeRestrictionSupported { dev.autoFocusRangeRestriction = .near }
            dev.unlockForConfiguration()
        } catch {}
        let out = AVCaptureMetadataOutput()
        guard session.canAddOutput(out) else { throw ScanFailure.message("Cannot add metadata output") }
        session.addOutput(out)
        out.setMetadataObjectsDelegate(self, queue: .main)
        out.metadataObjectTypes = formats.map(\.0).filter { out.availableMetadataObjectTypes.contains($0) }
        device = dev
        // Preview layer is attached to the session BEFORE startRunning (so the session starts with its final connections).
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        previewLayer = layer
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard continuation != nil,
              let obj = objects.first as? AVMetadataMachineReadableCodeObject,
              let text = obj.stringValue else { return }
        let ms = Int(((CFAbsoluteTimeGetCurrent() - t0) * 1000).rounded())
        let label = formats.first { $0.0 == obj.type }?.1 ?? obj.type.rawValue
        finish(.success(Entry(type: label, text: text, ms: ms)))
    }

    func cancel() { finish(.failure(ScanFailure.cancelled)) }

    /// Torch on the same device object the running session uses.
    func setTorch(_ on: Bool) -> Bool {
        guard let d = device, d.hasTorch else { return false }
        do {
            try d.lockForConfiguration()
            defer { d.unlockForConfiguration() }
            if on { try d.setTorchModeOn(level: 1.0) } else { d.torchMode = .off }
            return on
        } catch { return false }
    }

    private func finish(_ r: Result<Entry, Error>) {
        guard let c = continuation else { return }
        continuation = nil
        _ = setTorch(false)
        session.stopRunning()
        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        device = nil
        previewLayer = nil
        c.resume(with: r)
    }
}
