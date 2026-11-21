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
        PiPManager.shared.setupPiP(with: view, session: session, settings: settings)
        return view
    }
    
    public func updateUIView(_ uiView: PiPUITargetView, context: Context) {
        PiPManager.shared.updateSettings(settings: settings)
    }
}

public class PiPUITargetView: UIView {
    private var lastBounds: CGRect = .zero
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds != lastBounds, bounds.width > 0, bounds.height > 0 else { return }
        lastBounds = bounds
        PiPManager.shared.updatePiPFrame(bounds: bounds)
    }
    
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            PiPManager.shared.isPiPPossible = PiPManager.shared.pipController?.isPictureInPicturePossible ?? false
        }
    }
}
