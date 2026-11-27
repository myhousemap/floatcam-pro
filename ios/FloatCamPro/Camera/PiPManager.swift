import UIKit
import CoreMedia
import AVKit
import AVFoundation
import SwiftUI

public final class SampleBufferContainerView: UIView {
    public override class var layerClass: AnyClass {
        return AVSampleBufferDisplayLayer.self
    }
    
    public var sampleBufferLayer: AVSampleBufferDisplayLayer {
        return layer as! AVSampleBufferDisplayLayer
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        sampleBufferLayer.videoGravity = .resizeAspectFill
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        sampleBufferLayer.videoGravity = .resizeAspectFill
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        sampleBufferLayer.frame = bounds
    }
    
    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            DispatchQueue.main.async {
                PiPManager.shared.isPiPPossible = PiPManager.shared.pipController?.isPictureInPicturePossible ?? false
            }
        }
    }
}

public final class PiPManager: NSObject, ObservableObject {
    public static let shared = PiPManager()
    
    @Published public var isPiPActive: Bool = false
    @Published public var isPiPSupported: Bool = false
    @Published public var isPiPPossible: Bool = false
    @Published public var isLaunchingPiP: Bool = false
    
    public var pipController: AVPictureInPictureController?
    public weak var sampleBufferLayer: AVSampleBufferDisplayLayer?
    private weak var containerView: SampleBufferContainerView?
    private var hasEnqueuedFirstFrame: Bool = false
    private var possibleObservation: NSKeyValueObservation?
    private var pendingStartPiP: Bool = false
    
    public override init() {
        super.init()
        isPiPSupported = AVPictureInPictureController.isPictureInPictureSupported()
        configureAudioSession()
    }
    
    public func configureAudioSession(audioEnabled: Bool = false) {
        do {
            let session = AVAudioSession.sharedInstance()
            if audioEnabled {
                try session.setCategory(.playAndRecord, mode: .videoRecording, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            } else {
                try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            }
            try session.setActive(true)
        } catch {
            print("AudioSession configuration notice: \(error)")
        }
    }
    
    @MainActor
    public func setupPiP(with containerView: SampleBufferContainerView, settings: CameraSettings) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        self.isPiPSupported = true
        self.containerView = containerView
        let layer = containerView.sampleBufferLayer
        self.sampleBufferLayer = layer
        
        configureAudioSession(audioEnabled: settings.audioEnabled)
        
        // Connect ContentSource using sampleBufferDisplayLayer and playbackDelegate
        let contentSource = AVPictureInPictureController.ContentSource(
            sampleBufferDisplayLayer: layer,
            playbackDelegate: self
        )
        
        let controller = AVPictureInPictureController(contentSource: contentSource)
        controller.delegate = self
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.requiresLinearPlayback = false
        
        self.possibleObservation?.invalidate()
        self.possibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] ctrl, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isPiPPossible = ctrl.isPictureInPicturePossible
                if ctrl.isPictureInPicturePossible && self.pendingStartPiP {
                    self.pendingStartPiP = false
                    self.isLaunchingPiP = false
                    ctrl.startPictureInPicture()
                    HapticManager.shared.lightTap()
                }
            }
        }
        
        self.pipController = controller
        self.isPiPPossible = controller.isPictureInPicturePossible
    }
    
    public func enqueue(sampleBuffer: CMSampleBuffer) {
        guard let layer = sampleBufferLayer else { return }
        if layer.status == .failed {
            layer.flush()
        }
        if layer.isReadyForMoreMediaData {
            layer.enqueue(sampleBuffer)
            if !hasEnqueuedFirstFrame {
                hasEnqueuedFirstFrame = true
                DispatchQueue.main.async {
                    self.isPiPPossible = self.pipController?.isPictureInPicturePossible ?? false
                    if self.pendingStartPiP, let controller = self.pipController, controller.isPictureInPicturePossible {
                        self.pendingStartPiP = false
                        self.isLaunchingPiP = false
                        controller.startPictureInPicture()
                        HapticManager.shared.lightTap()
                    }
                }
            }
        }
    }
    
    public func updateSettings(settings: CameraSettings) {
    }
    
    public func updateHUD(isRecording: Bool, duration: TimeInterval, lens: CameraLens, resolution: VideoResolution? = nil) {
    }
    
    @MainActor
    public func startPiP() {
        configureAudioSession()
        RemoteControlManager.shared.setupRemoteCommands()
        RemoteControlManager.shared.updateNowPlaying()
        
        guard let controller = pipController else {
            print("PiP controller is nil")
            return
        }
        
        if controller.isPictureInPicturePossible {
            pendingStartPiP = false
            isLaunchingPiP = false
            controller.startPictureInPicture()
            HapticManager.shared.lightTap()
            return
        }
        
        pendingStartPiP = true
        isLaunchingPiP = true
        
        // Fast retry loop: checks every 50ms up to 60 times (3.0s)
        var attempts = 0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            attempts += 1
            if let controller = self.pipController, controller.isPictureInPicturePossible {
                timer.invalidate()
                DispatchQueue.main.async {
                    self.pendingStartPiP = false
                    self.isLaunchingPiP = false
                    controller.startPictureInPicture()
                    HapticManager.shared.lightTap()
                }
            } else if attempts >= 60 {
                timer.invalidate()
                DispatchQueue.main.async {
                    self.pendingStartPiP = false
                    self.isLaunchingPiP = false
                    print("PiP launch wait completed. isPictureInPicturePossible=\(self.pipController?.isPictureInPicturePossible ?? false)")
                }
            }
        }
    }
    
    @MainActor
    public func stopPiP() {
        pendingStartPiP = false
        isLaunchingPiP = false
        pipController?.stopPictureInPicture()
        HapticManager.shared.lightTap()
    }
    
    public func invalidatePlaybackState() {
        pipController?.invalidatePlaybackState()
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

// MARK: - AVPictureInPictureSampleBufferPlaybackDelegate
extension PiPManager: AVPictureInPictureSampleBufferPlaybackDelegate {
    public func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        return CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }
    
    public func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        return !CameraManager.shared.isRecording || CameraManager.shared.isPaused
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        DispatchQueue.main.async {
            if !CameraManager.shared.isRecording {
                CameraManager.shared.startRecording()
            } else {
                if playing {
                    CameraManager.shared.resumeRecording()
                } else {
                    CameraManager.shared.pauseRecording()
                }
            }
        }
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            if CameraManager.shared.isRecording {
                CameraManager.shared.stopRecording()
            } else {
                CameraManager.shared.flipCamera()
            }
            completionHandler()
        }
    }
}

// MARK: - AVPictureInPictureControllerDelegate
extension PiPManager: AVPictureInPictureControllerDelegate {
    public func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isPiPActive = true
            self.isLaunchingPiP = false
        }
    }
    
    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isPiPActive = true
            self.pendingStartPiP = false
            self.isLaunchingPiP = false
            RemoteControlManager.shared.setupRemoteCommands()
            RemoteControlManager.shared.updateNowPlaying()
            HapticManager.shared.successNotification()
        }
    }
    
    public func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
    }
    
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DispatchQueue.main.async {
            self.isPiPActive = false
            self.pendingStartPiP = false
            self.isLaunchingPiP = false
        }
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        DispatchQueue.main.async {
            print("PiP failed: \(error)")
            self.isPiPActive = false
            self.pendingStartPiP = false
            self.isLaunchingPiP = false
        }
    }
    
    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }
}
