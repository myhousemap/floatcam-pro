import SwiftUI
import AVFoundation

public struct PiPView: UIViewRepresentable {
    public let session: AVCaptureSession
    public let settings: CameraSettings
    
    public init(session: AVCaptureSession, settings: CameraSettings) {
        self.session = session
        self.settings = settings
    }
    
    public func makeUIView(context: Context) -> PiPUITargetView {
        let view = PiPUITargetView()
        view.backgroundColor = .black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = (settings.lens == .front && settings.mirrorFrontCamera)
        }
        view.layer.addSublayer(previewLayer)
        view.previewLayer = previewLayer
        
        PiPManager.shared.setupPiP(with: view, session: session, settings: settings)
        return view
    }
    
    public func updateUIView(_ uiView: PiPUITargetView, context: Context) {
        uiView.updateLayout()
        if let connection = uiView.previewLayer?.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = (settings.lens == .front && settings.mirrorFrontCamera)
        }
    }
}

public class PiPUITargetView: UIView {
    public var previewLayer: AVCaptureVideoPreviewLayer?
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
    }
    
    public func updateLayout() {
        previewLayer?.frame = bounds
        PiPManager.shared.updatePiPFrame(bounds: bounds)
    }
    
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            PiPManager.shared.isPiPPossible = PiPManager.shared.pipController?.isPictureInPicturePossible ?? false
        }
    }
}
