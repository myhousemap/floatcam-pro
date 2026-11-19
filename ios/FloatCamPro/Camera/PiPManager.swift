import AVKit
import SwiftUI

@MainActor
public final class PiPManager: NSObject, ObservableObject {
    public static let shared = PiPManager()
    
    @Published public var isPiPActive: Bool = false
    @Published public var isPiPSupported: Bool = false
    
    private var pipController: AVPictureInPictureController?
    private var pipVideoCallViewController: AVPictureInPictureVideoCallViewController?
    private var sourceView: UIView?
    
    public override init() {
        super.init()
        isPiPSupported = AVPictureInPictureController.isPictureInPictureSupported()
    }
    
    public func setupPiP(with session: AVCaptureSession) {
        guard isPiPSupported else { return }
        
        let previewView = UIView(frame: CGRect(x: 0, y: 0, width: 220, height: 220))
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = previewView.bounds
        previewLayer.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(previewLayer)
        self.sourceView = previewView
        
        let callVC = AVPictureInPictureVideoCallViewController()
        callVC.preferredContentSize = CGSize(width: 220, height: 220)
        callVC.view.addSubview(previewView)
        
        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: previewView,
            contentViewController: callVC
        )
        
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        
        self.pipController = controller
        self.pipVideoCallViewController = callVC
    }
    
    public func startPiP() {
        guard let controller = pipController, controller.isPictureInPicturePossible else { return }
        controller.startPictureInPicture()
        HapticManager.shared.lightTap()
    }
    
    public func stopPiP() {
        pipController?.stopPictureInPicture()
        HapticManager.shared.lightTap()
    }
}

extension PiPManager: AVPictureInPictureControllerDelegate {
    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = true
    }
    
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = false
    }
}
