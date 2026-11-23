import SwiftUI
import AVFoundation

public struct PiPView: UIViewRepresentable {
    public let session: AVCaptureSession
    public let settings: CameraSettings
    
    public init(session: AVCaptureSession, settings: CameraSettings) {
        self.session = session
        self.settings = settings
    }
    
    public func makeUIView(context: Context) -> SampleBufferContainerView {
        let view = SampleBufferContainerView(frame: .zero)
        PiPManager.shared.setupPiP(with: view, settings: settings)
        return view
    }
    
    public func updateUIView(_ uiView: SampleBufferContainerView, context: Context) {
        PiPManager.shared.updateSettings(settings: settings)
    }
}
