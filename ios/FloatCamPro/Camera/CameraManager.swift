import AVFoundation
import UIKit
import CoreMedia
import CoreVideo
import AudioToolbox

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
    private let videoDataQueue = DispatchQueue(label: "com.floatcam.pro.videoDataQueue", qos: .userInteractive)
    private let recordingQueue = DispatchQueue(label: "com.floatcam.pro.recordingQueue", qos: .userInitiated)
    
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let audioDataOutput = AVCaptureAudioDataOutput()
    
    private var recordingTimer: Timer?
    private var tempVideoURL: URL?
    private var assetWriter: AVAssetWriter?
    private var assetWriterVideoInput: AVAssetWriterInput?
    private var assetWriterAudioInput: AVAssetWriterInput?
    private var isAssetWriterSessionStarted: Bool = false
    private var activeSettings: CameraSettings?
    
    private override init() {
        super.init()
    }
    
    public func startSession(settings: CameraSettings) {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        self.activeSettings = settings
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.session.isRunning else { return }
            
            self.session.beginConfiguration()
            
            // Resolution preset
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
            
            // Audio Input (Safe check: only add if audio is authorized and enabled)
            if settings.audioEnabled {
                self.setupAudioInput()
            }
            
            // Multitasking Camera Access (allows camera feed to stay live during PiP over other apps)
            if self.session.isMultitaskingCameraAccessSupported {
                self.session.isMultitaskingCameraAccessEnabled = true
            }
            
            // Photo Output
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }
            
            // Video Data Output (Feeds AVSampleBufferDisplayLayer for PiP & AssetWriter)
            if self.session.canAddOutput(self.videoDataOutput) {
                self.videoDataOutput.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ]
                self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
                self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataQueue)
                self.session.addOutput(self.videoDataOutput)
                
                if let connection = self.videoDataOutput.connection(with: .video) {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                    if connection.isVideoMirroringSupported {
                        connection.automaticallyAdjustsVideoMirroring = false
                        connection.isVideoMirrored = (settings.lens == .front && settings.mirrorFrontCamera)
                    }
                }
            }
            
            // Audio Data Output
            if settings.audioEnabled && self.session.canAddOutput(self.audioDataOutput) {
                self.audioDataOutput.setSampleBufferDelegate(self, queue: self.videoDataQueue)
                self.session.addOutput(self.audioDataOutput)
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
        if isRecording {
            stopRecording()
        }
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
            
            if let connection = self.videoDataOutput.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = (targetLens == .front)
                }
            }
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
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "FloatCam_VID_\(Int(Date().timeIntervalSince1970)).mp4"
        let outputURL = tempDir.appendingPathComponent(fileName)
        self.tempVideoURL = outputURL
        
        recordingQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                if FileManager.default.fileExists(atPath: outputURL.path) {
                    try? FileManager.default.removeItem(at: outputURL)
                }
                let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
                self.assetWriter = writer
                self.assetWriterVideoInput = nil
                self.assetWriterAudioInput = nil
                self.isAssetWriterSessionStarted = false
            } catch {
                print("Failed to initialize AVAssetWriter: \(error)")
                return
            }
            
            DispatchQueue.main.async {
                self.isRecording = true
                self.recordingDuration = 0
                PiPManager.shared.updateHUD(isRecording: true, duration: 0, lens: self.currentLens)
                RemoteControlManager.shared.updateNowPlaying()
                HapticManager.shared.recordHaptic()
                
                self.recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    guard let self = self else { return }
                    self.recordingDuration += 1
                    PiPManager.shared.updateHUD(isRecording: true, duration: self.recordingDuration, lens: self.currentLens)
                }
            }
        }
    }
    
    private func stopRecording() {
        guard isRecording else { return }
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingTimer?.invalidate()
            self.recordingTimer = nil
            PiPManager.shared.updateHUD(isRecording: false, duration: 0, lens: self.currentLens)
            RemoteControlManager.shared.updateNowPlaying()
            HapticManager.shared.recordHaptic()
        }
        
        recordingQueue.async { [weak self] in
            guard let self = self, let writer = self.assetWriter else { return }
            
            self.assetWriterVideoInput?.markAsFinished()
            self.assetWriterAudioInput?.markAsFinished()
            
            writer.finishWriting { [weak self] in
                guard let self = self else { return }
                let url = self.tempVideoURL
                self.assetWriter = nil
                self.assetWriterVideoInput = nil
                self.assetWriterAudioInput = nil
                self.isAssetWriterSessionStarted = false
                
                if let url = url, writer.status == .completed {
                    DispatchQueue.main.async {
                        MediaManager.shared.saveVideo(at: url) { _ in }
                    }
                }
            }
        }
    }
    
    private func appendVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        recordingQueue.async { [weak self] in
            guard let self = self, self.isRecording, let writer = self.assetWriter else { return }
            
            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            if !self.isAssetWriterSessionStarted {
                if self.assetWriterVideoInput == nil {
                    var width = 1080
                    var height = 1920
                    if let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
                        let dim = CMVideoFormatDescriptionGetDimensions(formatDesc)
                        width = Int(dim.width)
                        height = Int(dim.height)
                    }
                    
                    let videoSettings: [String: Any] = [
                        AVVideoCodecKey: AVVideoCodecType.h264,
                        AVVideoWidthKey: width,
                        AVVideoHeightKey: height,
                        AVVideoCompressionPropertiesKey: [
                            AVVideoAverageBitRateKey: 6_000_000,
                            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                        ]
                    ]
                    let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                    vInput.expectsMediaDataInRealTime = true
                    if writer.canAdd(vInput) {
                        writer.add(vInput)
                        self.assetWriterVideoInput = vInput
                    }
                    
                    if self.activeSettings?.audioEnabled == true && self.assetWriterAudioInput == nil {
                        let audioSettings: [String: Any] = [
                            AVFormatIDKey: kAudioFormatMPEG4AAC,
                            AVNumberOfChannelsKey: 2,
                            AVSampleRateKey: 44100.0,
                            AVEncoderBitRateKey: 128_000
                        ]
                        let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
                        aInput.expectsMediaDataInRealTime = true
                        if writer.canAdd(aInput) {
                            writer.add(aInput)
                            self.assetWriterAudioInput = aInput
                        }
                    }
                }
                
                if writer.status == .unknown {
                    writer.startWriting()
                }
                if writer.status == .writing {
                    writer.startSession(atSourceTime: pts)
                    self.isAssetWriterSessionStarted = true
                }
            }
            
            if self.isAssetWriterSessionStarted, writer.status == .writing, let input = self.assetWriterVideoInput, input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        }
    }
    
    private func appendAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        recordingQueue.async { [weak self] in
            guard let self = self, self.isRecording, self.isAssetWriterSessionStarted,
                  let writer = self.assetWriter, writer.status == .writing,
                  let input = self.assetWriterAudioInput, input.isReadyForMoreMediaData else { return }
            input.append(sampleBuffer)
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

// MARK: - Video and Audio Data Output Sample Buffer Delegates
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output == self.videoDataOutput {
            PiPManager.shared.enqueue(sampleBuffer: sampleBuffer)
            if self.isRecording {
                self.appendVideoSampleBuffer(sampleBuffer)
            }
        } else if output == self.audioDataOutput {
            if self.isRecording {
                self.appendAudioSampleBuffer(sampleBuffer)
            }
        }
    }
}
