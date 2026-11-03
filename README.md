# Scanner Swift

A native iOS barcode and QR scanner written in Swift (SwiftUI and AVFoundation). It is a test project for comparing a native app with the same app built on another technology. It has one screen and no network, database or analytics.

## What it does

- A large **Scan** button opens a full-screen camera preview with **Flash** and **Cancel** buttons.
- After a scan it shows the code type, the decoded text and the time in milliseconds from the start of the scan to the result. The time starts after the camera permission is granted, so the permission dialog is not counted.
- The last 10 scans are kept in memory, newest first. Nothing is saved to disk.
- The flashlight stays on until the scan ends or is cancelled, then turns off.

## Camera setup

The scanner uses the first rear camera it finds in this order: triple, dual-wide, dual, wide-angle. On a virtual camera it starts at the zoom factor of the main lens and restricts autofocus to near range, so iOS can switch to the ultra-wide lens for close-up codes. The flashlight is driven through the same camera device the session uses. A different device object froze the preview in testing.

The code is in `Sources/Scanner.swift`.

## Run it on your iPhone

You need a Mac with Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), and an iPhone with iOS 17 or later. A free Apple ID is enough, but the app then expires after 7 days. The camera does not work in the Simulator, so the app builds there but cannot scan.

It was built with Xcode 27.2 and tested on an iPhone 14 Pro. Other versions are untested.

1. Clone the repository and generate the Xcode project:

   ```sh
   git clone https://github.com/alexneisc/scanner-swift.git
   cd scanner-swift
   xcodegen generate
   open ScannerSwift.xcodeproj
   ```

2. On the iPhone, turn on Developer Mode (Settings > Privacy & Security > Developer Mode), then connect it to the Mac and trust the computer.
3. In Xcode, select the **ScannerSwift** target, open **Signing & Capabilities**, and choose your team.
4. Change the bundle identifier from `com.oleksii.scannerswift` to one of your own, for example `com.yourname.scannerswift`. The original is registered to another team and will not sign for you.
5. Choose your iPhone as the run destination.
6. For timing comparisons, build in Release: **Product > Scheme > Edit Scheme > Run > Build Configuration > Release**. Run once from Xcode, stop it, then open the app from the home screen so no debugger is attached.
7. On first launch, allow camera access. If iOS warns about an untrusted developer, trust your profile in Settings > General > VPN & Device Management.

Running `xcodegen generate` again resets the signing settings, so set the team and bundle identifier again afterward.

### Command line alternative

```sh
xcodegen generate
xcodebuild -project ScannerSwift.xcodeproj -scheme ScannerSwift -configuration Release \
  -destination 'id=<DEVICE_ID>' -derivedDataPath build -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=<YOUR_TEAM_ID> PRODUCT_BUNDLE_IDENTIFIER=com.yourname.scannerswift build
xcrun devicectl device install app --device <DEVICE_ID> "build/Build/Products/Release-iphoneos/Scanner Swift.app"
xcrun devicectl device process launch --device <DEVICE_ID> com.yourname.scannerswift
```

Find the device ID with `xcrun xctrace list devices`. Your team ID is in your Apple Developer account and in the Xcode signing settings.
