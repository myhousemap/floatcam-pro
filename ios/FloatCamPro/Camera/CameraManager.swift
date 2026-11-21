import AVFoundation
import UIKit

public final class CameraManager: NSObject, ObservableObject {
    public static let shared = CameraManager()
    
    @Published public var isRunning: Bool = false
    @Published public var isRecording: Bool = false
    @Published public var recordingDuration: TimeInterval = 0
    @Published public var isTorchOn: Bool = false
    @Published public var currentLens: CameraLens = .front
    @Published public var currentZoom: CGFloat = 1.0
    @Published public var lastCapturedPhoto: UIImage?
    
    public let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.floatcam.pro.sessionQueue")
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let movieFileOutput = AVCaptureMovieFileOutput()
    
    private var recordingTimer: Timer?
    private var tempVideoURL: URL?
    
    private override init() {
        super.init()
    }
    
    public func startSession(settings: CameraSettings) {
        // Prevent starting camera session if authorization is not yet granted
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.session.isRunning else { return }
            
            self.session.beginConfiguration()
            
            // Resolution
            switch settings.resolution {
            case .hd720p:
                if self.session.canSetSessionPreset(.hd1280x720) {
                    self.session.sessionPreset = .hd1280x720
                }
            case .fhd1080p:
                if self.session.canSetSessionPreset(.hd1920x1080) {
                    self.session.sessionPreset = .hd1920x1080
                }
            case .uhd4k:
                if self.session.canSetSessionPreset(.hd4K3840x2160) {
                    self.session.sessionPreset = .hd4K3840x2160
                } else if self.session.canSetSessionPreset(.hd1920x1080) {
                    self.session.sessionPreset = .hd1920x1080
                }
            }
            
            // Video Input
            self.setupVideoInput(for: settings.lens)
            
            // Audio Input (Safe check: only add if audio is authorized)
            if settings.audioEnabled {
                self.setupAudioInput()
            }
            
            // Multitasking Camera Access (allows camera feed to stay live during PiP over other apps)
            if self.session.isMultitaskingCameraAccessSupported {
                self.session.isMultitaskingCameraAccessEnabled = true
            }
            
            // Outputs
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            if self.session.canAddOutput(self.movieFileOutput) {
                self.session.addOutput(self.movieFileOutput)
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
            
            DispatchQueue.main.async {
                self.isRunning = self.session.isRunning
                self.currentLens = settings.lens
                PiPManager.shared.updateHUD(isRecording: false, duration: 0, lens: settings.lens, resolution: settings.resolution)
                RemoteControlManager.shared.updateNowPlaying()
            }
        }
    }
    
    public func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isRunning = false
                }
            }
        }
    }
    
    public func flipCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let targetLens: CameraLens = (self.currentLens == .front) ? .back : .front
            
            self.session.beginConfiguration()
            if let currentInput = self.videoDeviceInput {
                self.session.removeInput(currentInput)
            }
            self.setupVideoInput(for: targetLens)
            self.session.commitConfiguration()
            
            DispatchQueue.main.async {
                self.currentLens = targetLens
                self.isTorchOn = false
                PiPManager.shared.updateHUD(isRecording: self.isRecording, duration: self.recordingDuration, lens: targetLens)
                RemoteControlManager.shared.updateNowPlaying()
            }
        }
    }
    
    public func toggleTorch() {
        guard currentLens == .back,
              let device = videoDeviceInput?.device,
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            let newTorch = !isTorchOn
            device.torchMode = newTorch ? .on : .off
            device.unlockForConfiguration()
            DispatchQueue.main.async {
                self.isTorchOn = newTorch
            }
        } catch {
            print("Torch error: \(error)")
        }
    }
    
    public func setZoom(_ factor: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            let clamped = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor))
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
            DispatchQueue.main.async {
                self.currentZoom = clamped
            }
        } catch {
            print("Zoom error: \(error)")
        }
    }
    
    public func takePhoto() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
            HapticManager.shared.recordHaptic()
        }
    }
    
    public func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        guard !isRecording, AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "FloatCam_VID_\(Int(Date().timeIntervalSince1970)).mp4"
            let outputURL = tempDir.appendingPathComponent(fileName)
            self.tempVideoURL = outputURL
            
            self.movieFileOutput.startRecording(to: outputURL, recordingDelegate: self)
            HapticManager.shared.recordHaptic()
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.recordingDuration = 0
                PiPManager.shared.updateHUD(isRecording: true, duration: 0, lens: self.currentLens)
                RemoteControlManager.shared.updateNowPlaying()
                
                self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    self.recordingDuration += 1
                    PiPManager.shared.updateHUD(isRecording: true, duration: self.recordingDuration, lens: self.currentLens)
                    RemoteControlManager.shared.updateNowPlaying()
                }
            }
        }
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.movieFileOutput.stopRecording()
            HapticManager.shared.recordHaptic()
            
            DispatchQueue.main.async {
                self.isRecording = false
                self.recordingTimer?.invalidate()
                self.recordingTimer = nil
                PiPManager.shared.updateHUD(isRecording: false, duration: 0, lens: self.currentLens)
                RemoteControlManager.shared.updateNowPlaying()
            }
        }
    }
    
    private func setupVideoInput(for lens: CameraLens) {
        let position: AVCaptureDevice.Position = (lens == .front) ? .front : .back
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if session.canAddInput(input) {
            session.addInput(input)
            self.videoDeviceInput = input
        }
    }
    
    private func setupAudioInput() {
        // Only attach audio input if audio permission is explicitly granted
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { return }
        guard let device = AVCaptureDevice.default(for: .audio),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if session.canAddInput(input) {
            session.addInput(input)
            self.audioDeviceInput = input
        }
    }
}

// MARK: - Photo Capture Delegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        
        DispatchQueue.main.async {
            self.lastCapturedPhoto = image
            MediaManager.shared.savePhoto(image) { _ in }
        }
    }
}

// MARK: - Video Recording Delegate
extension CameraManager: AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error == nil {
            DispatchQueue.main.async {
                MediaManager.shared.saveVideo(at: outputFileURL) { _ in }
            }
        } else {
            print("Video recording failed: \(String(describing: error))")
        }
    }
}
