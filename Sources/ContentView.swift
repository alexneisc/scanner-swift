import SwiftUI
import AVFoundation

struct PreviewView: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer?
    final class V: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()
            layer.sublayers?.forEach { $0.frame = bounds }
        }
    }
    func makeUIView(context: Context) -> V {
        let v = V()
        if let layer { layer.frame = v.bounds; v.layer.addSublayer(layer) }
        return v
    }
    func updateUIView(_ uiView: V, context: Context) {}
}

struct ContentView: View {
    @StateObject private var scanner = Scanner()
    @State private var scanning = false
    @State private var torchOn = false
    @State private var last: Entry?
    @State private var message = ""
    @State private var history: [Entry] = []

    var body: some View {
        ZStack {
            if scanning {
                PreviewView(layer: scanner.previewLayer).ignoresSafeArea()
                VStack(spacing: 12) {
                    Spacer()
                    Button { torchOn = scanner.setTorch(!torchOn) } label: {
                        Text("Flash: \(torchOn ? "On" : "Off")").modifier(OverlayButton())
                    }
                    Button { scanner.cancel() } label: { Text("Cancel").modifier(OverlayButton()) }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: start) {
                            Text("Scan").font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                                .frame(maxWidth: .infinity, minHeight: 100)
                                .background(Color(red: 10/255, green: 132/255, blue: 255/255))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        if !message.isEmpty { Text(message).foregroundColor(.red).padding(.top, 12) }
                        if let last {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(last.type).fontWeight(.semibold)
                                Text(last.text).font(.system(size: 18))
                                Text("\(last.ms) ms").foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12)).padding(.top, 20)
                        }
                        if !history.isEmpty {
                            Text("History").font(.system(size: 16, weight: .semibold)).padding(.top, 24).padding(.bottom, 8)
                            ForEach(history) { h in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(h.type) · \(h.ms) ms").font(.system(size: 14, weight: .semibold))
                                    Text(h.text).font(.system(size: 14)).foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                                Divider()
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private func start() {
        message = ""
        torchOn = false
        Task {
            guard await scanner.requestPermission() else {
                message = "Camera access denied. Enable it in Settings > Scanner Swift."
                return
            }
            do {
                let entry = try await scanner.scan { scanning = true }
                last = entry
                history = Array(([entry] + history).prefix(10))
            } catch ScanFailure.cancelled {
                message = "Scan cancelled"
            } catch ScanFailure.message(let m) {
                message = "Error: \(m)"
            } catch {
                message = "Error: \(error.localizedDescription)"
            }
            torchOn = false
            scanning = false
        }
    }
}

struct OverlayButton: ViewModifier {
    func body(content: Content) -> some View {
        content.font(.system(size: 20)).foregroundColor(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 20)
            .background(Color.black.opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
