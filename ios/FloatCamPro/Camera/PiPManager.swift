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
    
    // Android-style HUD views inside PiP window (Matching overlay_camera_view.xml)
    private var topBarView: UIView?
    private var recordingBadge: UIView?
    private var recordingDot: UIView?
    private var recordingTimerLabel: UILabel?
    private var liveStandbyLabel: UILabel?
    private var torchIconView: UIImageView?
    private var mirrorIconView: UIImageView?
    private var shapeIconView: UIImageView?
    private var closeIconView: UIImageView?
    
    private var bottomBarView: UIView?
    private var flipIconView: UIImageView?
    private var shutterIconView: UIView?
    private var recordButtonContainer: UIView?
    private var recordButtonInner: UIView?
    
    private var resizeHandleIcon: UIImageView?
    
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
        
        // 3. Android-Matching HUD Overlays (Matching overlay_camera_view.xml)
        
        // 3a. TOP HUD BAR (Matches topBar in overlay_camera_view.xml)
        let topBar = UIView()
        topBar.backgroundColor = UIColor(red: 11/255, green: 13/255, blue: 18/255, alpha: 0.85)
        topBar.layer.cornerRadius = 13
        topBar.layer.masksToBounds = true
        topBar.layer.borderWidth = 1
        topBar.layer.borderColor = UIColor(red: 79/255, green: 140/255, blue: 255/255, alpha: 0.3).cgColor
        topBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Recording Badge (Matches bg_recording_badge)
        let recBadge = UIView()
        recBadge.backgroundColor = UIColor(red: 214/255, green: 40/255, blue: 57/255, alpha: 0.9)
        recBadge.layer.cornerRadius = 10
        recBadge.layer.masksToBounds = true
        recBadge.translatesAutoresizingMaskIntoConstraints = false
        recBadge.isHidden = true
        
        let recDot = UIView()
        recDot.backgroundColor = .white
        recDot.layer.cornerRadius = 3.5
        recDot.layer.masksToBounds = true
        recDot.translatesAutoresizingMaskIntoConstraints = false
        recBadge.addSubview(recDot)
        
        let recTimer = UILabel()
        recTimer.text = "00:00"
        recTimer.font = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold)
        recTimer.textColor = .white
        recTimer.translatesAutoresizingMaskIntoConstraints = false
        recBadge.addSubview(recTimer)
        
        NSLayoutConstraint.activate([
            recDot.leadingAnchor.constraint(equalTo: recBadge.leadingAnchor, constant: 6),
            recDot.centerYAnchor.constraint(equalTo: recBadge.centerYAnchor),
            recDot.widthAnchor.constraint(equalToConstant: 7),
            recDot.heightAnchor.constraint(equalToConstant: 7),
            
            recTimer.leadingAnchor.constraint(equalTo: recDot.trailingAnchor, constant: 4),
            recTimer.trailingAnchor.constraint(equalTo: recBadge.trailingAnchor, constant: -6),
            recTimer.centerYAnchor.constraint(equalTo: recBadge.centerYAnchor)
        ])
        topBar.addSubview(recBadge)
        self.recordingBadge = recBadge
        self.recordingDot = recDot
        self.recordingTimerLabel = recTimer
        
        // Standby Brand Label when not recording
        let standbyLbl = UILabel()
        standbyLbl.text = "FLOATCAM"
        standbyLbl.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        standbyLbl.textColor = UIColor(red: 79/255, green: 140/255, blue: 255/255, alpha: 1.0)
        standbyLbl.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(standbyLbl)
        self.liveStandbyLabel = standbyLbl
        
        // Top Action Icons: Torch, Mirror, Shape, Close
        let iconStack = UIStackView()
        iconStack.axis = .horizontal
        iconStack.spacing = 6
        iconStack.alignment = .center
        iconStack.translatesAutoresizingMaskIntoConstraints = false
        
        let torchImg = createHudIcon(systemName: "flashlight.off.fill")
        let mirrorImg = createHudIcon(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
        let shapeImg = createHudIcon(systemName: "aspectratio")
        let closeImg = createHudIcon(systemName: "xmark")
        
        iconStack.addArrangedSubview(torchImg)
        iconStack.addArrangedSubview(mirrorImg)
        iconStack.addArrangedSubview(shapeImg)
        iconStack.addArrangedSubview(closeImg)
        topBar.addSubview(iconStack)
        
        self.torchIconView = torchImg
        self.mirrorIconView = mirrorImg
        self.shapeIconView = shapeImg
        self.closeIconView = closeImg
        
        NSLayoutConstraint.activate([
            recBadge.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 4),
            recBadge.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            recBadge.heightAnchor.constraint(equalToConstant: 20),
            
            standbyLbl.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 8),
            standbyLbl.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            iconStack.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -6),
            iconStack.centerYAnchor.constraint(equalTo: topBar.centerYAnchor)
        ])
        
        cameraView.addSubview(topBar)
        self.topBarView = topBar
        
        // 3b. BOTTOM HUD BAR (Matches bottomBar in overlay_camera_view.xml)
        let bottomBar = UIView()
        bottomBar.backgroundColor = UIColor(red: 11/255, green: 13/255, blue: 18/255, alpha: 0.85)
        bottomBar.layer.cornerRadius = 16
        bottomBar.layer.masksToBounds = true
        bottomBar.layer.borderWidth = 1
        bottomBar.layer.borderColor = UIColor(red: 79/255, green: 140/255, blue: 255/255, alpha: 0.3).cgColor
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        
        let bottomStack = UIStackView()
        bottomStack.axis = .horizontal
        bottomStack.spacing = 14
        bottomStack.alignment = .center
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Flip Camera Button Icon
        let flipImg = createHudIcon(systemName: "camera.rotate.fill", size: 14)
        bottomStack.addArrangedSubview(flipImg)
        self.flipIconView = flipImg
        
        // Photo Shutter Icon (White circular button)
        let shutterView = UIView()
        shutterView.backgroundColor = .white
        shutterView.layer.cornerRadius = 13
        shutterView.layer.masksToBounds = true
        shutterView.layer.borderWidth = 2
        shutterView.layer.borderColor = UIColor(red: 79/255, green: 140/255, blue: 255/255, alpha: 1.0).cgColor
        shutterView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            shutterView.widthAnchor.constraint(equalToConstant: 26),
            shutterView.heightAnchor.constraint(equalToConstant: 26)
        ])
        bottomStack.addArrangedSubview(shutterView)
        self.shutterIconView = shutterView
        
        // Video Record Button Icon (Red outer ring + inner solid red / stop square)
        let recContainer = UIView()
        recContainer.backgroundColor = UIColor(red: 255/255, green: 77/255, blue: 90/255, alpha: 1.0)
        recContainer.layer.cornerRadius = 13
        recContainer.layer.masksToBounds = true
        recContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            recContainer.widthAnchor.constraint(equalToConstant: 26),
            recContainer.heightAnchor.constraint(equalToConstant: 26)
        ])
        
        let recInner = UIView()
        recInner.backgroundColor = .white
        recInner.layer.cornerRadius = 5
        recInner.layer.masksToBounds = true
        recInner.translatesAutoresizingMaskIntoConstraints = false
        recContainer.addSubview(recInner)
        NSLayoutConstraint.activate([
            recInner.centerXAnchor.constraint(equalTo: recContainer.centerXAnchor),
            recInner.centerYAnchor.constraint(equalTo: recContainer.centerYAnchor),
            recInner.widthAnchor.constraint(equalToConstant: 10),
            recInner.heightAnchor.constraint(equalToConstant: 10)
        ])
        bottomStack.addArrangedSubview(recContainer)
        self.recordButtonContainer = recContainer
        self.recordButtonInner = recInner
        
        bottomBar.addSubview(bottomStack)
        NSLayoutConstraint.activate([
            bottomStack.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            bottomStack.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor)
        ])
        
        cameraView.addSubview(bottomBar)
        self.bottomBarView = bottomBar
        
        // 3c. Corner Resize Handle (Bottom-Right, Matches ic_resize_handle)
        let resizeImg = UIImageView(image: UIImage(systemName: "arrow.up.left.and.arrow.down.right"))
        resizeImg.tintColor = UIColor(white: 0.85, alpha: 0.8)
        resizeImg.contentMode = .scaleAspectFit
        resizeImg.translatesAutoresizingMaskIntoConstraints = false
        cameraView.addSubview(resizeImg)
        self.resizeHandleIcon = resizeImg
        
        // Layout Top Bar, Bottom Bar & Resize Handle
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: cameraView.topAnchor, constant: 6),
            topBar.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor, constant: 8),
            topBar.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor, constant: -8),
            topBar.heightAnchor.constraint(equalToConstant: 26),
            
            bottomBar.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor, constant: -6),
            bottomBar.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
            bottomBar.widthAnchor.constraint(equalToConstant: 130),
            bottomBar.heightAnchor.constraint(equalToConstant: 34),
            
            resizeImg.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor, constant: -5),
            resizeImg.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor, constant: -5),
            resizeImg.widthAnchor.constraint(equalToConstant: 14),
            resizeImg.heightAnchor.constraint(equalToConstant: 14)
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
        
        if self.pendingStartPiP && controller.isPictureInPicturePossible {
            self.pendingStartPiP = false
            controller.startPictureInPicture()
            HapticManager.shared.lightTap()
        }
    }
    
    private func createHudIcon(systemName: String, size: CGFloat = 12) -> UIImageView {
        let imgView = UIImageView(image: UIImage(systemName: systemName))
        imgView.tintColor = .white
        imgView.contentMode = .scaleAspectFit
        imgView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imgView.widthAnchor.constraint(equalToConstant: size),
            imgView.heightAnchor.constraint(equalToConstant: size)
        ])
        return imgView
    }
    
    public func updateHUD(isRecording: Bool, duration: TimeInterval, lens: CameraLens, resolution: VideoResolution? = nil) {
        if isRecording {
            recordingBadge?.isHidden = false
            liveStandbyLabel?.isHidden = true
            let mins = Int(duration) / 60
            let secs = Int(duration) % 60
            recordingTimerLabel?.text = String(format: "%02d:%02d", mins, secs)
            
            // Record button turns to stop square
            recordButtonInner?.layer.cornerRadius = 2
        } else {
            recordingBadge?.isHidden = true
            liveStandbyLabel?.isHidden = false
            recordButtonInner?.layer.cornerRadius = 5
        }
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
        
        // Continuous retry loop: checks every 100ms up to 30 times (3 seconds)
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
