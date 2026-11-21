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
    private var possibleObservation: NSKeyValueObservation?
    private var pendingStartPiP: Bool = false
    
    public override init() {
        super.init()
        isPiPSupported = AVPictureInPictureController.isPictureInPictureSupported()
        configureAudioSessionAsync()
    }
    
    public func configureAudioSessionAsync() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .videoChat, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
                try session.setActive(true)
            } catch {
                print("AudioSession configuration notice: \(error)")
            }
        }
    }
    
    public func setupPiP(with sourceView: UIView, session: AVCaptureSession, settings: CameraSettings) {
        guard isPiPSupported else { return }
        
        self.activeSourceView = sourceView
        configureAudioSessionAsync()
        
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
        callViewController.view.layer.cornerRadius = (settings.shape == .circle) ? (targetSize.width / 2) : 22
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
        
        // KVO Observer for isPictureInPicturePossible
        self.possibleObservation?.invalidate()
        self.possibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] ctrl, _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.isPiPPossible = ctrl.isPictureInPicturePossible
                if ctrl.isPictureInPicturePossible && self.pendingStartPiP {
                    self.pendingStartPiP = false
                    ctrl.startPictureInPicture()
                }
            }
        }
        
        self.pipController = controller
        self.isPiPPossible = controller.isPictureInPicturePossible
    }
    
    public func updatePiPFrame(bounds: CGRect) {
        pipPreviewLayer?.frame = bounds
    }
    
    public func startPiP() {
        configureAudioSessionAsync()
        
        guard let controller = pipController else {
            pendingStartPiP = true
            return
        }
        
        if controller.isPictureInPicturePossible {
            controller.startPictureInPicture()
            HapticManager.shared.lightTap()
        } else {
            // Queue start as soon as Pegasus PiP daemon confirms possible
            pendingStartPiP = true
            // Also attempt fallback after short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self = self, let ctrl = self.pipController else { return }
                if ctrl.isPictureInPicturePossible && !self.isPiPActive {
                    self.pendingStartPiP = false
                    ctrl.startPictureInPicture()
                    HapticManager.shared.lightTap()
                }
            }
        }
    }
    
    public func stopPiP() {
        pendingStartPiP = false
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
        pendingStartPiP = false
        HapticManager.shared.successNotification()
    }
    
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        isPiPActive = false
        pendingStartPiP = false
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("PiP failed: \(error)")
        isPiPActive = false
        pendingStartPiP = false
    }
}
