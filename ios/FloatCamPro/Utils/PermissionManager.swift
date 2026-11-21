import AVFoundation
import Photos
import UIKit

@MainActor
public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()
    
    @Published public var cameraGranted: Bool = false
    @Published public var microphoneGranted: Bool = false
    @Published public var photoLibraryGranted: Bool = false
    
    @Published public var cameraDenied: Bool = false
    @Published public var microphoneDenied: Bool = false
    @Published public var photoLibraryDenied: Bool = false
    
    public var allRequiredGranted: Bool {
        cameraGranted && photoLibraryGranted
    }
    
    private init() {
        checkPermissions()
    }
    
    public func checkPermissions() {
        // Camera
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        self.cameraGranted = (cameraStatus == .authorized)
        self.cameraDenied = (cameraStatus == .denied || cameraStatus == .restricted)
        
        // Microphone
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        self.microphoneGranted = (micStatus == .authorized)
        self.microphoneDenied = (micStatus == .denied || micStatus == .restricted)
        
        // Photo Library
        let photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        self.photoLibraryGranted = (photoStatus == .authorized || photoStatus == .limited)
        self.photoLibraryDenied = (photoStatus == .denied || photoStatus == .restricted)
    }
    
    public func requestAllPermissions() {
        requestCameraPermission { [weak self] _ in
            self?.requestPhotoLibraryPermission { [weak self] _ in
                self?.requestMicrophonePermission()
            }
        }
    }
    
    public func requestCameraPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            self.cameraGranted = true
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.cameraGranted = granted
                    completion(granted)
                }
            }
        case .denied, .restricted:
            self.cameraGranted = false
            completion(false)
            self.openAppSettings()
        @unknown default:
            break
        }
    }
    
    public func requestMicrophonePermission(completion: @escaping (Bool) -> Void = { _ in }) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            self.microphoneGranted = true
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor in
                    self.microphoneGranted = granted
                    completion(granted)
                }
            }
        case .denied, .restricted:
            self.microphoneGranted = false
            completion(false)
            self.openAppSettings()
        @unknown default:
            break
        }
    }
    
    public func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            self.photoLibraryGranted = true
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                Task { @MainActor in
                    let granted = (newStatus == .authorized || newStatus == .limited)
                    self.photoLibraryGranted = granted
                    completion(granted)
                }
            }
        case .denied, .restricted:
            self.photoLibraryGranted = false
            completion(false)
            self.openAppSettings()
        @unknown default:
            break
        }
    }
    
    public func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
}
