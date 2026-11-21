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
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var cameraContainerView: UIView?
    private weak var hostView: UIView?
    private var possibleObservation: NSKeyValueObservation?
    private var pendingStartPiP: Bool = false
    
    private var statusBadge: UIView?
    private var statusLabel: UILabel?
    
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
    
    public func setupPiP(with hostView: UIView, session: AVCaptureSession, settings: CameraSettings) {
        guard isPiPSupported else { return }
        self.hostView = hostView
        configureAudioSessionAsync()
        
        // 1. Create Video Call View Controller
        let callVC = AVPictureInPictureVideoCallViewController()
        let targetSize = pipSize(for: settings.shape)
        callVC.preferredContentSize = targetSize
        
        // 2. Setup Camera Container View
        let cameraView = UIView(frame: hostView.bounds)
        cameraView.backgroundColor = .black
        cameraView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = cameraView.bounds
        if let connection = preview.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = (settings.lens == .front && settings.mirrorFrontCamera)
        }
        cameraView.layer.addSublayer(preview)
        self.previewLayer = preview
        self.cameraContainerView = cameraView
        
        // 3. Add HUD Overlay inside PiP window
        let hudView = UIView(frame: CGRect(x: 10, y: 10, width: 110, height: 24))
        hudView.backgroundColor = UIColor(white: 0.08, alpha: 0.75)
        hudView.layer.cornerRadius = 12
        hudView.layer.masksToBounds = true
        hudView.layer.borderWidth = 1
        hudView.layer.borderColor = UIColor(white: 0.3, alpha: 0.5).cgColor
        
        let dot = UIView(frame: CGRect(x: 8, y: 8, width: 8, height: 8))
        dot.backgroundColor = UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.0)
        dot.layer.cornerRadius = 4
        dot.layer.masksToBounds = true
        hudView.addSubview(dot)
        
        let label = UILabel(frame: CGRect(x: 22, y: 4, width: 80, height: 16))
        label.text = "FloatCam Live"
        label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        hudView.addSubview(label)
        
        cameraView.addSubview(hudView)
        self.statusBadge = hudView
        self.statusLabel = label
        
        // 4. Mount cameraView into callVC.view
        callVC.view.addSubview(cameraView)
        cameraView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cameraView.topAnchor.constraint(equalTo: callVC.view.topAnchor),
            cameraView.bottomAnchor.constraint(equalTo: callVC.view.bottomAnchor),
            cameraView.leadingAnchor.constraint(equalTo: callVC.view.leadingAnchor),
            cameraView.trailingAnchor.constraint(equalTo: callVC.view.trailingAnchor)
        ])
        
        // Style Call VC
        applyStyling(to: callVC.view, settings: settings, size: targetSize)
        self.callVC = callVC
        
        // 5. While in the app, display callVC.view directly inside hostView
        callVC.view.frame = hostView.bounds
        callVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostView.addSubview(callVC.view)
        
        // 6. Connect ContentSource: hostView is the sourceView in the window!
        let contentSource = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: hostView,
            contentViewController: callVC
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
    
    public func updateSettings(settings: CameraSettings) {
        guard let callVC = callVC else { return }
        let size = pipSize(for: settings.shape)
        callVC.preferredContentSize = size
        applyStyling(to: callVC.view, settings: settings, size: size)
        
        if let connection = previewLayer?.connection, connection.isVideoMirroringSupported {
            let mirrored = (settings.lens == .front && settings.mirrorFrontCamera)
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }
    
    private func applyStyling(to view: UIView, settings: CameraSettings, size: CGSize) {
        view.layer.cornerRadius = (settings.shape == .circle) ? (size.width / 2) : 22
        view.layer.masksToBounds = true
        view.layer.borderColor = UIColor(Color(hex: settings.borderColorHex)).cgColor
        view.layer.borderWidth = settings.borderWidth
    }
    
    public func updatePiPFrame(bounds: CGRect) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        previewLayer?.frame = bounds
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
            pendingStartPiP = true
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
        
        // Re-attach callVC.view back into hostView when returning from floating mode
        if let callVC = callVC, let hostView = hostView, callVC.view.superview !== hostView {
            callVC.view.frame = hostView.bounds
            callVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            hostView.addSubview(callVC.view)
            previewLayer?.frame = callVC.view.bounds
        }
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        print("PiP failed: \(error)")
        isPiPActive = false
        pendingStartPiP = false
    }
}
