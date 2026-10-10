import AVFoundation
import SwiftUI

/// Scans a collection code shown by the driver. The camera session starts when the tab opens.
struct ScanView: View {
  @State private var scanner = CollectionScanner()

  var body: some View {
    CameraPreview(session: scanner.session)
      .overlay(alignment: .bottom) {
        Text(scanner.lastCode ?? "Point the camera at the driver's code")
          .padding()
      }
      .onAppear { scanner.start() }
      .onDisappear { scanner.stop() }
  }
}

@Observable
final class CollectionScanner {
  let session = AVCaptureSession()
  var lastCode: String?

  func start() {
    guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
          let input = try? AVCaptureDeviceInput(device: camera) else { return }
    if session.canAddInput(input) { session.addInput(input) }
    session.startRunning()
  }

  func stop() {
    session.stopRunning()
  }
}
