import SwiftUI

public struct StudioView: View {
    @Binding var settings: CameraSettings
    @Binding var isOverlayActive: Bool
    @ObservedObject var cameraManager = CameraManager.shared
    @ObservedObject var pipManager = PiPManager.shared
    @ObservedObject var permissionManager = PermissionManager.shared
    
    public init(settings: Binding<CameraSettings>, isOverlayActive: Binding<Bool>) {
        self._settings = settings
        self._isOverlayActive = isOverlayActive
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Top Title & Status Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FloatCam Pro")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.textPrimary)
                        Text("Studio Control Center")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Status Pill
                    HStack(spacing: 6) {
                        Circle()
                            .fill(pipManager.isPiPActive ? Color.successGreen : (isOverlayActive ? Color.primaryBlue : (cameraManager.isRunning ? Color.successGreen : Color.textMuted)))
                            .frame(width: 8, height: 8)
                        
                        let statusText: String = {
                            if pipManager.isPiPActive { return "FLOATING OVER APPS" }
                            if isOverlayActive { return "IN-APP OVERLAY" }
                            if cameraManager.isRunning { return "CAMERA READY" }
                            return "STANDBY"
                        }()
                        
                        Text(statusText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(pipManager.isPiPActive || cameraManager.isRunning ? Color.successGreen : (isOverlayActive ? Color.primaryBlue : Color.textMuted))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(pipManager.isPiPActive || cameraManager.isRunning ? Color.successGreen.opacity(0.15) : Color.obsidianSurfaceVariant)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(pipManager.isPiPActive || cameraManager.isRunning ? Color.successGreen.opacity(0.5) : Color.obsidianBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                // Camera Permission Warning Banner if missing
                if !permissionManager.cameraGranted {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.badge.ellipsis")
                            .font(.system(size: 20))
                            .foregroundColor(.recordingRed)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Camera Permission Required")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.textPrimary)
                            Text("Grant camera access to preview and record.")
                                .font(.system(size: 11))
                                .foregroundColor(.textSecondary)
                        }
                        Spacer()
                        Button(action: {
                            permissionManager.requestCameraPermission()
                        }) {
                            Text("Enable")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.primaryBlue)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(12)
                    .background(Color.obsidianSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14).stroke(Color.recordingRed.opacity(0.4), lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
                
                // Live Interactive Visual Mockup Card with Live Viewfinder
                studioMockupCard
                    .padding(.horizontal)
                
                // Studio Live Camera Deck (Flip, Record Video, Shutter, Torch)
                studioControlDeck
                    .padding(.horizontal)
                
                // Primary Action Buttons
                VStack(spacing: 12) {
                    // 1. Picture-in-Picture Float Button (iOS System-Wide) - PRIMARY FOR OVER OTHER APPS
                    Button(action: {
                        if !cameraManager.isRunning {
                            cameraManager.startSession(settings: settings)
                        }
                        if pipManager.isPiPActive {
                            pipManager.stopPiP()
                        } else {
                            pipManager.startPiP()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: pipManager.isPiPActive ? "pip.exit" : "pip.enter")
                                .font(.system(size: 20, weight: .bold))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pipManager.isPiPActive ? "Floating Active (Tap to Stop)" : "Float Over Gemini & Other Apps (PiP)")
                                    .font(.system(size: 15, weight: .bold))
                                Text(pipManager.isPiPActive ? "Camera is currently pinned over other apps" : "Pinch to resize • Drag anywhere • Control via Control Center")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(pipManager.isPiPActive ? Color.recordingRed : Color.primaryBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: (pipManager.isPiPActive ? Color.recordingRed : Color.primaryBlue).opacity(0.4), radius: 8, y: 4)
                    }
                    
                    // 2. In-App Floating Overlay Window
                    Button(action: {
                        if !isOverlayActive && !permissionManager.cameraGranted {
                            permissionManager.requestCameraPermission()
                            return
                        }
                        withAnimation(.spring()) {
                            isOverlayActive.toggle()
                        }
                        if isOverlayActive && !cameraManager.isRunning {
                            cameraManager.startSession(settings: settings)
                        }
                        HapticManager.shared.mediumTap()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: isOverlayActive ? "xmark.circle.fill" : "square.on.square")
                                .font(.system(size: 16, weight: .semibold))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isOverlayActive ? "Close In-App Overlay" : "Open In-App Overlay Window")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                Text("Window with on-screen buttons, resize handle & bubble minimize")
                                    .font(.system(size: 10))
                                    .foregroundColor(.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.obsidianSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14).stroke(Color.obsidianBorder, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
                
                // iOS Floating Controls & Gestures Guide
                floatingGuideCard
                    .padding(.horizontal)
                
                // Quick Studio Presets
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Studio Presets")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    // 1. Frame Shape
                    chipCategory(title: "Frame Shape") {
                        HStack(spacing: 8) {
                            ForEach(ShapePreset.allCases) { shape in
                                studioChip(
                                    title: shapeShortTitle(shape),
                                    icon: shapeIcon(shape),
                                    isSelected: settings.shape == shape
                                ) {
                                    settings.shape = shape
                                }
                            }
                        }
                    }
                    
                    // 2. Camera Lens
                    chipCategory(title: "Camera Lens") {
                        HStack(spacing: 8) {
                            ForEach(CameraLens.allCases) { lens in
                                studioChip(
                                    title: lens.rawValue,
                                    icon: (lens == .front) ? "person.crop.circle" : "camera.fill",
                                    isSelected: settings.lens == lens
                                ) {
                                    settings.lens = lens
                                    cameraManager.flipCamera()
                                }
                            }
                        }
                    }
                    
                    // 3. Audio Recording
                    chipCategory(title: "Audio Capture") {
                        HStack(spacing: 8) {
                            studioChip(
                                title: "Mic On",
                                icon: "mic.fill",
                                subLabel: "Clear Sound",
                                isSelected: settings.audioEnabled
                            ) {
                                settings.audioEnabled = true
                            }
                            studioChip(
                                title: "Muted",
                                icon: "mic.slash.fill",
                                subLabel: "Silent Video",
                                isSelected: !settings.audioEnabled
                            ) {
                                settings.audioEnabled = false
                            }
                        }
                    }
                    
                    // 4. Capture Quality
                    chipCategory(title: "Capture Quality") {
                        HStack(spacing: 8) {
                            ForEach(VideoResolution.allCases) { res in
                                studioChip(
                                    title: res.rawValue,
                                    icon: "sparkles.tv",
                                    isSelected: settings.resolution == res
                                ) {
                                    settings.resolution = res
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .background(Color.obsidianBackground)
        .onAppear {
            permissionManager.checkPermissions()
            if permissionManager.cameraGranted && !cameraManager.isRunning {
                cameraManager.startSession(settings: settings)
            }
            RemoteControlManager.shared.setupRemoteCommands()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            permissionManager.checkPermissions()
            if permissionManager.cameraGranted && !cameraManager.isRunning {
                cameraManager.startSession(settings: settings)
            }
        }
    }
    
    // MARK: - Dedicated Studio Camera Control Deck
    private var studioControlDeck: some View {
        VStack(spacing: 12) {
            // Live Recording Timer Indicator (when recording is active)
            if cameraManager.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.recordingRed)
                        .frame(width: 10, height: 10)
                    Text("RECORDING LIVE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.recordingRed)
                    Spacer()
                    Text(formatDuration(cameraManager.recordingDuration))
                        .font(.system(size: 15, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.recordingRed.opacity(0.18))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(Color.recordingRed.opacity(0.4), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .scale))
            }
            
            // Camera Buttons Deck
            HStack(spacing: 24) {
                // 1. Flip Camera Button
                Button(action: {
                    cameraManager.flipCamera()
                    settings.lens = (settings.lens == .front) ? .back : .front
                    HapticManager.shared.lightTap()
                }) {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(Color.obsidianSurfaceVariant)
                            .frame(width: 52, height: 52)
                            .overlay(
                                Image(systemName: "camera.rotate.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                            )
                            .overlay(
                                Circle().stroke(Color.obsidianBorder, lineWidth: 1)
                            )
                        Text(settings.lens == .front ? "Front" : "Rear")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                }
                
                // 2. Video Record Button (Hero Shutter)
                Button(action: {
                    cameraManager.toggleRecording()
                    HapticManager.shared.recordHaptic()
                }) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(Color.recordingRed.opacity(0.4), lineWidth: 4)
                                .frame(width: 72, height: 72)
                            
                            if cameraManager.isRecording {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.recordingRed)
                                    .frame(width: 26, height: 26)
                            } else {
                                Circle()
                                    .fill(Color.recordingRed)
                                    .frame(width: 54, height: 54)
                            }
                        }
                        Text(cameraManager.isRecording ? "Stop" : "Record")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(cameraManager.isRecording ? .recordingRed : .textPrimary)
                    }
                }
                
                // 3. Photo Shutter Button
                Button(action: {
                    cameraManager.takePhoto()
                    HapticManager.shared.lightTap()
                }) {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(Color.obsidianSurfaceVariant)
                            .frame(width: 52, height: 52)
                            .overlay(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 32, height: 32)
                            )
                            .overlay(
                                Circle().stroke(Color.obsidianBorder, lineWidth: 1)
                            )
                        Text("Photo")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                }
                
                // 4. Torch Toggle (Visible when Rear Camera is active)
                if settings.lens == .back {
                    Button(action: {
                        cameraManager.toggleTorch()
                        HapticManager.shared.lightTap()
                    }) {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(cameraManager.isTorchOn ? Color.primaryBlue.opacity(0.2) : Color.obsidianSurfaceVariant)
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Image(systemName: cameraManager.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(cameraManager.isTorchOn ? .primaryBlue : .textPrimary)
                                )
                                .overlay(
                                    Circle().stroke(cameraManager.isTorchOn ? Color.primaryBlue : Color.obsidianBorder, lineWidth: 1)
                                )
                            Text("Torch")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.obsidianSurface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18).stroke(Color.obsidianBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Mockup Card View
    private var studioMockupCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.obsidianSurface)
                .frame(height: 250)
                .overlay(
                    RoundedRectangle(cornerRadius: 24).stroke(Color.obsidianBorder, lineWidth: 1)
                )
            
            // Mockup Shape Display with Live Camera Feed
            VStack {
                ZStack {
                    if cameraManager.isRunning {
                        PiPView(session: cameraManager.session, settings: settings)
                            .clipShape(mockupShape)
                            .overlay(
                                mockupShape.stroke(
                                    Color(hex: settings.borderColorHex),
                                    lineWidth: settings.borderWidth
                                )
                            )
                            .frame(
                                width: mockupWidth,
                                height: mockupHeight
                            )
                            .shadow(color: Color(hex: settings.borderColorHex).opacity(0.3), radius: 8)
                    } else {
                        // Frame placeholder
                        mockupShape
                            .fill(Color.obsidianSurfaceVariant.opacity(settings.opacity))
                            .overlay(
                                mockupShape.stroke(
                                    Color(hex: settings.borderColorHex),
                                    lineWidth: settings.borderWidth
                                )
                            )
                            .frame(
                                width: mockupWidth,
                                height: mockupHeight
                            )
                        
                        // Inner lens icon
                        VStack(spacing: 6) {
                            Circle()
                                .fill(Color.obsidianBackground)
                                .frame(width: 48, height: 48)
                                .overlay(
                                    Circle().stroke(Color(hex: settings.borderColorHex).opacity(0.5), lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: (settings.lens == .front) ? "person.crop.circle" : "camera.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(Color(hex: settings.borderColorHex))
                                )
                            
                            Text(settings.shape.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            
                            Text("\(settings.resolution.rawValue) • \(settings.fps.label)")
                                .font(.system(size: 9))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - iOS Floating Guide Card
    private var floatingGuideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.primaryBlue)
                    .font(.system(size: 16))
                Text("How Floating Camera Works on iOS")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                guideRow(
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: "Pinch to Resize",
                    detail: "Pinch two fingers anywhere on the floating camera to make it larger or smaller."
                )
                guideRow(
                    icon: "hand.draw.fill",
                    title: "Drag Anywhere",
                    detail: "Move the floating camera to any corner of your screen over Gemini AI, Meta AI or any app."
                )
                guideRow(
                    icon: "slider.horizontal.3",
                    title: "Control From Any App (Control Center)",
                    detail: "Swipe down iOS Control Center: tap Play/Pause to Record, Next to Flip lens."
                )
                guideRow(
                    icon: "arrow.up.right.square.fill",
                    title: "One-Tap Return to Studio",
                    detail: "Tap the floating window's ↗ icon to jump back to full studio controls instantly."
                )
            }
        }
        .padding(14)
        .background(Color.obsidianSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16).stroke(Color.primaryBlue.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func guideRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primaryBlue)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textPrimary)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
            }
        }
    }
    
    private var mockupShape: AnyShape {
        switch settings.shape {
        case .circle:
            return AnyShape(Circle())
        case .square1x1:
            return AnyShape(RoundedRectangle(cornerRadius: 24))
        case .portrait9x16, .landscape16x9:
            return AnyShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    private var mockupWidth: CGFloat {
        switch settings.shape {
        case .circle, .square1x1: return 160
        case .portrait9x16: return 110
        case .landscape16x9: return 200
        }
    }
    
    private var mockupHeight: CGFloat {
        switch settings.shape {
        case .circle, .square1x1: return 160
        case .portrait9x16: return 195
        case .landscape16x9: return 120
        }
    }
    
    // MARK: - Helpers
    private func chipCategory<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
            content()
        }
    }
    
    private func studioChip(title: String, icon: String, subLabel: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            HapticManager.shared.lightTap()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                    if let sub = subLabel {
                        Text(sub)
                            .font(.system(size: 9))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .textMuted)
                    }
                }
            }
            .foregroundColor(isSelected ? .white : .textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.primaryBlue.opacity(0.25) : Color.obsidianSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primaryBlue : Color.obsidianBorder, lineWidth: 1)
            )
        }
    }
    
    private func shapeShortTitle(_ shape: ShapePreset) -> String {
        switch shape {
        case .circle: return "Circle"
        case .square1x1: return "1:1 Square"
        case .portrait9x16: return "9:16 Story"
        case .landscape16x9: return "16:9 Stream"
        }
    }
    
    private func shapeIcon(_ shape: ShapePreset) -> String {
        switch shape {
        case .circle: return "circle"
        case .square1x1: return "square"
        case .portrait9x16: return "iphone"
        case .landscape16x9: return "tv"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
