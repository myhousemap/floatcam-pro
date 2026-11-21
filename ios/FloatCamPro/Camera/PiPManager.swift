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
    
    // Dynamic HUD Overlays
    private var statusBadge: UIView?
    private var statusDot: UIView?
    private var statusLabel: UILabel?
    private var lensBadge: UIView?
    private var lensLabel: UILabel?
    private var hintBadge: UIView?
    private var hintLabel: UILabel?
    
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
        
        // 3. Dynamic Live HUD Badges inside PiP window
        // 3a. Top Left Status Badge (Live status / REC timer)
        let hudView = UIView()
        hudView.backgroundColor = UIColor(white: 0.08, alpha: 0.8)
        hudView.layer.cornerRadius = 11
        hudView.layer.masksToBounds = true
        hudView.layer.borderWidth = 1
        hudView.layer.borderColor = UIColor(white: 0.35, alpha: 0.6).cgColor
        hudView.translatesAutoresizingMaskIntoConstraints = false
        
        let dot = UIView()
        dot.backgroundColor = UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.0)
        dot.layer.cornerRadius = 4
        dot.layer.masksToBounds = true
        dot.translatesAutoresizingMaskIntoConstraints = false
        hudView.addSubview(dot)
        
        let label = UILabel()
        label.text = "FLOATCAM LIVE"
        label.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        hudView.addSubview(label)
        
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: hudView.leadingAnchor, constant: 7),
            dot.centerYAnchor.constraint(equalTo: hudView.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            
            label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: hudView.trailingAnchor, constant: -7),
            label.centerYAnchor.constraint(equalTo: hudView.centerYAnchor)
        ])
        
        cameraView.addSubview(hudView)
        self.statusBadge = hudView
        self.statusDot = dot
        self.statusLabel = label
        
        // 3b. Top Right Lens Badge
        let lensView = UIView()
        lensView.backgroundColor = UIColor(white: 0.08, alpha: 0.8)
        lensView.layer.cornerRadius = 11
        lensView.layer.masksToBounds = true
        lensView.layer.borderWidth = 1
        lensView.layer.borderColor = UIColor(white: 0.35, alpha: 0.6).cgColor
        lensView.translatesAutoresizingMaskIntoConstraints = false
        
        let lensLbl = UILabel()
        lensLbl.text = "\(settings.lens == .front ? "FRONT" : "REAR") • \(settings.resolution.rawValue)"
        lensLbl.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        lensLbl.textColor = UIColor(white: 0.95, alpha: 1.0)
        lensLbl.translatesAutoresizingMaskIntoConstraints = false
        lensView.addSubview(lensLbl)
        
        NSLayoutConstraint.activate([
            lensLbl.leadingAnchor.constraint(equalTo: lensView.leadingAnchor, constant: 7),
            lensLbl.trailingAnchor.constraint(equalTo: lensView.trailingAnchor, constant: -7),
            lensLbl.centerYAnchor.constraint(equalTo: lensView.centerYAnchor)
        ])
        
        cameraView.addSubview(lensView)
        self.lensBadge = lensView
        self.lensLabel = lensLbl
        
        // 3c. Bottom Gestures Hint Pill
        let hintView = UIView()
        hintView.backgroundColor = UIColor(white: 0.05, alpha: 0.72)
        hintView.layer.cornerRadius = 9
        hintView.layer.masksToBounds = true
        hintView.translatesAutoresizingMaskIntoConstraints = false
        
        let hintLbl = UILabel()
        hintLbl.text = "Pinch to Resize • Tap ↗ for Studio"
        hintLbl.font = UIFont.systemFont(ofSize: 8.5, weight: .semibold)
        hintLbl.textColor = UIColor(white: 0.9, alpha: 0.95)
        hintLbl.textAlignment = .center
        hintLbl.translatesAutoresizingMaskIntoConstraints = false
        hintView.addSubview(hintLbl)
        
        NSLayoutConstraint.activate([
            hintLbl.leadingAnchor.constraint(equalTo: hintView.leadingAnchor, constant: 6),
            hintLbl.trailingAnchor.constraint(equalTo: hintView.trailingAnchor, constant: -6),
            hintLbl.centerYAnchor.constraint(equalTo: hintView.centerYAnchor)
        ])
        
        cameraView.addSubview(hintView)
        self.hintBadge = hintView
        self.hintLabel = hintLbl
        
        // AutoLayout Anchors inside cameraView
        NSLayoutConstraint.activate([
            hudView.topAnchor.constraint(equalTo: cameraView.topAnchor, constant: 8),
            hudView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor, constant: 8),
            hudView.heightAnchor.constraint(equalToConstant: 22),
            
            lensView.topAnchor.constraint(equalTo: cameraView.topAnchor, constant: 8),
            lensView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor, constant: -8),
            lensView.heightAnchor.constraint(equalToConstant: 22),
            
            hintView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor, constant: -6),
            hintView.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
            hintView.heightAnchor.constraint(equalToConstant: 18),
            hintView.leadingAnchor.constraint(greaterThanOrEqualTo: cameraView.leadingAnchor, constant: 8),
            hintView.trailingAnchor.constraint(lessThanOrEqualTo: cameraView.trailingAnchor, constant: -8)
        ])
        
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
                    HapticManager.shared.lightTap()
                }
            }
        }
        
        self.pipController = controller
        self.isPiPPossible = controller.isPictureInPicturePossible
        
        // If start was requested before controller was ready, trigger immediately
        if self.pendingStartPiP && controller.isPictureInPicturePossible {
            self.pendingStartPiP = false
            controller.startPictureInPicture()
            HapticManager.shared.lightTap()
        }
    }
    
    public func updateHUD(isRecording: Bool, duration: TimeInterval, lens: CameraLens, resolution: VideoResolution? = nil) {
        if isRecording {
            statusBadge?.backgroundColor = UIColor(red: 0.88, green: 0.12, blue: 0.18, alpha: 0.9)
            statusBadge?.layer.borderColor = UIColor.white.withAlphaComponent(0.6).cgColor
            statusDot?.backgroundColor = .white
            let mins = Int(duration) / 60
            let secs = Int(duration) % 60
            statusLabel?.text = String(format: "REC %02d:%02d", mins, secs)
        } else {
            statusBadge?.backgroundColor = UIColor(white: 0.08, alpha: 0.8)
            statusBadge?.layer.borderColor = UIColor(white: 0.35, alpha: 0.6).cgColor
            statusDot?.backgroundColor = UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.0)
            statusLabel?.text = "FLOATCAM LIVE"
        }
        
        let resStr = resolution?.rawValue ?? "1080p"
        lensLabel?.text = "\(lens == .front ? "FRONT" : "REAR") • \(resStr)"
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
        
        updateHUD(
            isRecording: CameraManager.shared.isRecording,
            duration: CameraManager.shared.recordingDuration,
            lens: settings.lens,
            resolution: settings.resolution
        )
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
        RemoteControlManager.shared.setupRemoteCommands()
        RemoteControlManager.shared.updateNowPlaying()
        
        pendingStartPiP = true
        
        if let controller = pipController, controller.isPictureInPicturePossible {
            pendingStartPiP = false
            controller.startPictureInPicture()
            HapticManager.shared.lightTap()
            return
        }
        
        // Continuous retry: checks every 100ms up to 30 times (3 seconds) until PiP is ready
        var attempts = 0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            attempts += 1
            if let controller = self.pipController, controller.isPictureInPicturePossible {
                timer.invalidate()
                self.pendingStartPiP = false
                controller.startPictureInPicture()
                HapticManager.shared.lightTap()
            } else if attempts >= 30 {
                timer.invalidate()
                self.pendingStartPiP = false
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
        RemoteControlManager.shared.setupRemoteCommands()
        RemoteControlManager.shared.updateNowPlaying()
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
