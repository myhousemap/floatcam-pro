import Foundation
import MediaPlayer
import AVFoundation

@MainActor
public final class RemoteControlManager: NSObject {
    public static let shared = RemoteControlManager()
    
    private var isConfigured: Bool = false
    
    private override init() {
        super.init()
    }
    
    public func setupRemoteCommands() {
        guard !isConfigured else {
            updateNowPlaying()
            return
        }
        
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // 1. Play Command -> Start Recording
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            Task { @MainActor in
                if !CameraManager.shared.isRecording {
                    CameraManager.shared.toggleRecording()
                    RemoteControlManager.shared.updateNowPlaying()
                }
            }
            return .success
        }
        
        // 2. Pause Command -> Stop Recording
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            Task { @MainActor in
                if CameraManager.shared.isRecording {
                    CameraManager.shared.toggleRecording()
                    RemoteControlManager.shared.updateNowPlaying()
                }
            }
            return .success
        }
        
        // 3. Toggle Play/Pause (e.g. AirPods tap / Earbuds squeeze) -> Toggle Record
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in
                CameraManager.shared.toggleRecording()
                RemoteControlManager.shared.updateNowPlaying()
            }
            return .success
        }
        
        // 4. Next Track Command -> Flip Camera (Front <-> Back)
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { _ in
            Task { @MainActor in
                CameraManager.shared.flipCamera()
                RemoteControlManager.shared.updateNowPlaying()
            }
            return .success
        }
        
        // 5. Previous Track Command -> Take High-Res Photo Snapshot
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { _ in
            Task { @MainActor in
                CameraManager.shared.takePhoto()
                RemoteControlManager.shared.updateNowPlaying()
            }
            return .success
        }
        
        isConfigured = true
        updateNowPlaying()
    }
    
    public func updateNowPlaying() {
        let isRec = CameraManager.shared.isRecording
        let lens = CameraManager.shared.currentLens.rawValue
        let duration = CameraManager.shared.recordingDuration
        
        var info = [String: Any]()
        
        if isRec {
            info[MPMediaItemPropertyTitle] = "● RECORDING LIVE"
            info[MPMediaItemPropertyArtist] = "⏱ \(formatDuration(duration)) • \(lens) Camera"
            info[MPMediaItemPropertyAlbumTitle] = "Tap Pause to Stop • Next to Flip Lens"
            info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
            info[MPMediaItemPropertyPlaybackDuration] = max(1.0, duration)
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = duration
        } else {
            info[MPMediaItemPropertyTitle] = "FloatCam Pro — Camera Active"
            info[MPMediaItemPropertyArtist] = "\(lens) Camera Ready"
            info[MPMediaItemPropertyAlbumTitle] = "Control Center: Play to Record • Next to Flip"
            info[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
