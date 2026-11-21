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
        if let connection = uiView.previewLayer?.connection, connection.isVideoMirroringSupported {
            let mirrored = (settings.lens == .front && settings.mirrorFrontCamera)
            if connection.isVideoMirrored != mirrored {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = mirrored
            }
        }
    }
}

public class PiPUITargetView: UIView {
    public var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastBounds: CGRect = .zero
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds != lastBounds, bounds.width > 0, bounds.height > 0 else { return }
        lastBounds = bounds
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
