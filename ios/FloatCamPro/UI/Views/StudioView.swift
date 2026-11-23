import SwiftUI

public struct StudioView: View {
    @Binding var settings: CameraSettings
    @Binding var isOverlayActive: Bool
    @ObservedObject var cameraManager = CameraManager.shared
    @ObservedObject var pipManager = PiPManager.shared
    @ObservedObject var permissionManager = PermissionManager.shared
    
    @State private var isPulsing: Bool = false
    
    public init(settings: Binding<CameraSettings>, isOverlayActive: Binding<Bool>) {
        self._settings = settings
        self._isOverlayActive = isOverlayActive
    }
    
    private var isRunning: Bool {
        pipManager.isPiPActive
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Top App Bar / Title (Matches Android StudioScreen)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("FloatCam Pro")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.textPrimary)
                        Text("Studio Control Center")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Status Pill (Matches Android Status Pill)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusDotColor)
                            .frame(width: 8, height: 8)
                            .scaleEffect(isRunning ? (isPulsing ? 1.2 : 0.85) : 1.0)
                            .animation(isRunning ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default, value: isPulsing)
                        
                        Text(statusText)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(statusDotColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(statusPillBg)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(statusPillBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // Camera Permission Alert Banner (if missing)
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
                    .padding(.horizontal, 20)
                }
                
                // Live Visual Mockup Preview Card (Matches Android StudioMockupCard)
                studioMockupCard
                    .padding(.horizontal, 20)
                
                // Primary Launch / Stop Button (Matches Android Button)
                Button(action: {
                    toggleFloatingCamera()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: isRunning ? "xmark" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(isRunning ? "Stop Floating Camera" : "Launch Floating Camera")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(isRunning ? Color.recordingRed : Color.primaryBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: (isRunning ? Color.recordingRed : Color.primaryBlue).opacity(0.4), radius: 6, y: 3)
                }
                .padding(.horizontal, 20)
                
                // Quick Studio Presets (Matches Android ChipCategorySection)
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
                                isSelected: settings.audioEnabled
                            ) {
                                settings.audioEnabled = true
                            }
                            studioChip(
                                title: "Muted",
                                icon: "mic.slash.fill",
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
                .padding(.horizontal, 20)
                
                // iOS System PiP Guidance Banner (For Gemini AI, Meta AI & background float)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "pip.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primaryBlue)
                        Text("Float Over Any iOS App")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.textPrimary)
                        Spacer()
                        
                        // Status indicator
                        HStack(spacing: 4) {
                            Circle()
                                .fill(pipManager.isPiPSupported ? Color.successGreen : Color.recordingRed)
                                .frame(width: 7, height: 7)
                            Text(pipManager.isPiPSupported ? "PiP Active" : "Unsupported")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(pipManager.isPiPSupported ? .successGreen : .recordingRed)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.obsidianSurfaceVariant)
                        .clipShape(Capsule())
                    }
                    
                    Text("FloatCam Pro stays floating over Gemini AI, Meta AI, Safari, WhatsApp, and the Home Screen. Tap 'Launch Floating Camera' above to start floating.")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                        .lineSpacing(3)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Apple iOS Requirement:")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.textPrimary)
                            Text("Settings > General > Picture in Picture > Start PiP Automatically: ON")
                                .font(.system(size: 10))
                                .foregroundColor(.textMuted)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 10))
                                Text("iOS Settings")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primaryBlue.opacity(0.8))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(14)
                .background(Color.obsidianSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16).stroke(Color.obsidianBorder, lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .background(Color.obsidianBackground)
        .onAppear {
            isPulsing = true
            permissionManager.checkPermissions()
            RemoteControlManager.shared.setupRemoteCommands()
            if permissionManager.cameraGranted && !cameraManager.isRunning {
                cameraManager.startSession(settings: settings)
            }
        }
    }
    
    // MARK: - Actions
    private func toggleFloatingCamera() {
        if isRunning {
            pipManager.stopPiP()
            HapticManager.shared.lightTap()
        } else {
            if !permissionManager.cameraGranted {
                permissionManager.requestCameraPermission { granted in
                    if granted {
                        self.cameraManager.startSession(settings: self.settings)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.pipManager.startPiP()
                        }
                    }
                }
                return
            }
            if !cameraManager.isRunning {
                cameraManager.startSession(settings: settings)
            }
            pipManager.startPiP()
            HapticManager.shared.mediumTap()
        }
    }
    
    // MARK: - Status Pill Helpers
    private var statusDotColor: Color {
        if cameraManager.isRecording { return Color.recordingRed }
        if isRunning { return Color.successGreen }
        return Color.textMuted
    }
    
    private var statusText: String {
        if cameraManager.isRecording { return "RECORDING" }
        if isRunning { return "OVERLAY ACTIVE" }
        return "STANDBY"
    }
    
    private var statusPillBg: Color {
        if isRunning { return Color.successGreen.opacity(0.15) }
        return Color.obsidianSurfaceVariant
    }
    
    private var statusPillBorder: Color {
        if isRunning { return Color.successGreen.opacity(0.5) }
        return Color.obsidianBorder
    }
    
    // MARK: - StudioMockupCard (1:1 with Android StudioMockupCard + Live PiP Anchor)
    private var studioMockupCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.obsidianSurface)
                .frame(height: 260)
                .overlay(
                    RoundedRectangle(cornerRadius: 24).stroke(Color.obsidianBorder, lineWidth: 1)
                )
            
            // Live Shape Mockup Box
            VStack {
                ZStack(alignment: .topTrailing) {
                    // Live PiP Camera Preview Anchor (Real Dimensions in Window Hierarchy)
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
                    
                    // Fallback placeholder when camera session is not running or permission missing
                    if !permissionManager.cameraGranted || !cameraManager.isRunning {
                        mockupShape
                            .fill(Color.obsidianSurfaceVariant.opacity(0.95))
                            .overlay(
                                mockupShape.stroke(
                                    Color(hex: settings.borderColorHex),
                                    lineWidth: settings.borderWidth
                                )
                            )
                            .frame(width: mockupWidth, height: mockupHeight)
                        
                        VStack(spacing: 6) {
                            Circle()
                                .fill(Color.obsidianBackground)
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Circle().stroke(Color(hex: settings.borderColorHex).opacity(0.5), lineWidth: 1)
                                )
                                .overlay(
                                    Image(systemName: (settings.lens == .front) ? "person.crop.circle" : "camera.fill")
                                        .font(.system(size: 26))
                                        .foregroundColor(Color(hex: settings.borderColorHex))
                                )
                            
                            Text(settings.shape.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            
                            Text("\(settings.resolution.rawValue) • \(settings.fps.label)")
                                .font(.system(size: 9))
                                .foregroundColor(.textSecondary)
                        }
                        .frame(width: mockupWidth, height: mockupHeight)
                    }
                    
                    // Top corner badge if recording (Matches Android REC badge)
                    if cameraManager.isRecording {
                        Text("REC")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.recordingRed)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(8)
                    }
                }
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
        case .circle, .square1x1: return 170
        case .portrait9x16: return 120
        case .landscape16x9: return 220
        }
    }
    
    private var mockupHeight: CGFloat {
        switch settings.shape {
        case .circle, .square1x1: return 170
        case .portrait9x16: return 210
        case .landscape16x9: return 130
        }
    }
    
    // MARK: - Helpers
    private func chipCategory<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSecondary)
            content()
        }
    }
    
    private func studioChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            HapticManager.shared.lightTap()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : .textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.primaryBlue.opacity(0.2) : Color.obsidianSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
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
}
