import AVFoundation
import Photos
import UIKit

public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()
    
    @Published public var cameraGranted: Bool = false
    @Published public var microphoneGranted: Bool = false
    @Published public var photoLibraryGranted: Bool = false
    
    public var allRequiredGranted: Bool {
        cameraGranted && photoLibraryGranted
    }
    
    private init() {
        checkPermissions()
    }
    
    public func checkPermissions() {
        // Camera
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.cameraGranted = (cameraStatus == .authorized)
        }
        
        // Microphone (using AVCaptureDevice to prevent AVAudioSession crashes)
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        DispatchQueue.main.async {
            self.microphoneGranted = (micStatus == .authorized)
        }
        
        // Photo Library
        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        DispatchQueue.main.async {
            self.photoLibraryGranted = (photoStatus == .authorized || photoStatus == .limited)
        }
    }
    
    public func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.cameraGranted = granted
                completion(granted)
            }
        }
    }
    
    public func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                self.microphoneGranted = granted
                completion(granted)
            }
        }
    }
    
    public func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                let granted = (status == .authorized || status == .limited)
                self.photoLibraryGranted = granted
                if granted {
                    MediaManager.shared.loadMedia()
                }
                completion(granted)
            }
        }
    }
    
    public func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
