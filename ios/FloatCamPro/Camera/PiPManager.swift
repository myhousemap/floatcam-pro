import AVKit
import AVFoundation
import SwiftUI

@MainActor
public final class PiPManager: NSObject, ObservableObject {
    public static let shared = PiPManager()
    
    @Published public var isPiPActive: Bool = false
    @Published public var isPiPSupported: Bool = false
    @Published public var isPiPPossible: Bool = false
    
    public var pipController: AVPictureInPictureController?
    private var callVC: AVPictureInPictureVideoCallViewController?
    private var pipPreviewLayer: AVCaptureVideoPreviewLayer?
    private weak var activeSourceView: UIView?
    
    public override init() {
        super.init()
        isPiPSupported = AVPictureInPictureController.isPictureInPictureSupported()
    }
    
    public func configureAudioSessionForPiP() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session for PiP: \(error)")
        }
    }
    
    public func setupPiP(with sourceView: UIView, session: AVCaptureSession, settings: CameraSettings) {
        guard isPiPSupported else { return }
        
        self.activeSourceView = sourceView
        configureAudioSessionForPiP()
        
        // 1. Create Video Call View Controller
        let callViewController = AVPictureInPictureVideoCallViewController()
        let targetSize = pipSize(for: settings.shape)
        callViewController.preferredContentSize = targetSize
        
        // 2. Add Preview View & Layer to Call VC
        let pipView = UIView(frame: CGRect(origin: .zero, size: targetSize))
        pipView.backgroundColor = .black
        pipView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        callViewController.view.addSubview(pipView)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = pipView.bounds
        previewLayer.videoGravity = .resizeAspectFill
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = (settings.lens == .front && settings.mirrorFrontCamera)
        }
        pipView.layer.addSublayer(previewLayer)
        self.pipPreviewLayer = previewLayer
        
        // Style Call VC
        callViewController.view.layer.cornerRadius = (settings.shape == .circle) ? 28 : 20
        callViewController.view.layer.masksToBounds = true
        callViewController.view.layer.borderColor = UIColor(Color(hex: settings.borderColorHex)).cgColor
        callViewController.view.layer.borderWidth = settings.borderWidth
        
        self.callVC = callViewController
        
        // 3. Create ContentSource with ON-SCREEN sourceView
        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: callViewController
        )
        
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        
        self.pipController = controller
        self.isPiPPossible = controller.isPictureInPicturePossible
    }
    
    public func updatePiPFrame(bounds: CGRect) {
        pipPreviewLayer?.frame = bounds
    }
    
    public func startPiP() {
        configureAudioSessionForPiP()
        
        guard let controller = pipController else { return }
        
        if controller.isPictureInPicturePossible {
            controller.startPictureInPicture()
            HapticManager.shared.lightTap()
        } else {
            // Retry after short runloop cycle when view finishes attaching to window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self, let ctrl = self.pipController else { return }
                if ctrl.isPictureInPicturePossible {
                    ctrl.startPictureInPicture()
                    HapticManager.shared.lightTap()
                }
            }
        }
    }
    
    public func stopPiP() {
        pipController?.stopPictureInPicture()
        HapticManager.shared.lightTap()
    }
    
    public func pipSize(for shape: ShapePreset) -> CGSize {
        switch shape {
        case .circle, .square1x1:
            return CGSize(width: 180, height: 180)
        case .portrait9x16:
            return CGSize(width: 135, height: 240)
        case .landscape16x9:
            return CGSize(width: 240, height: 135)
        }
    }
}

extension PiPManager: AVPictureInPictureControllerDelegate {
    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = true
    }
    
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = false
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("PiP failed: \(error)")
        isPiPActive = false
    }
}
