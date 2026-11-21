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
                            .fill(isOverlayActive ? Color.successGreen : Color.textMuted)
                            .frame(width: 8, height: 8)
                            .scaleEffect(isOverlayActive && isPulsing ? 1.25 : 1.0)
                            .animation(
                                isOverlayActive ?
                                Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                                value: isPulsing
                            )
                        Text(isOverlayActive ? (cameraManager.isRecording ? "RECORDING" : "OVERLAY ON") : "STANDBY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isOverlayActive ? Color.successGreen : Color.textMuted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isOverlayActive ? Color.successGreen.opacity(0.15) : Color.obsidianSurfaceVariant)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(isOverlayActive ? Color.successGreen.opacity(0.5) : Color.obsidianBorder, lineWidth: 1)
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
                        HStack(spacing: 10) {
                            Image(systemName: pipManager.isPiPActive ? "pip.exit" : "pip.enter")
                                .font(.system(size: 18, weight: .bold))
                            Text(pipManager.isPiPActive ? "Floating Active (Tap to Stop)" : "Float Over Gemini & Other Apps (PiP)")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
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
                        HStack(spacing: 8) {
                            Image(systemName: isOverlayActive ? "xmark" : "square.on.square")
                                .font(.system(size: 14, weight: .semibold))
                            Text(isOverlayActive ? "Close In-App Overlay" : "Open In-App Overlay Window")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.obsidianSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14).stroke(Color.obsidianBorder, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
                
                // Explanatory Tip Box
                HStack(spacing: 12) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.primaryBlue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Float Over Gemini AI, Meta AI & Other Apps:")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.textPrimary)
                        Text("Tap 'Float Over Gemini & Other Apps' above, or just swipe up to Home while camera is active. Your camera will float continuously above all other apps.")
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding(14)
                .background(Color.obsidianSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16).stroke(Color.primaryBlue.opacity(0.3), lineWidth: 1)
                )
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
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .background(Color.obsidianBackground)
        .onAppear {
            isPulsing = true
            permissionManager.checkPermissions()
            if permissionManager.cameraGranted && !cameraManager.isRunning {
                cameraManager.startSession(settings: settings)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            permissionManager.checkPermissions()
            if permissionManager.cameraGranted && !cameraManager.isRunning {
                cameraManager.startSession(settings: settings)
            }
        }
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
                        // Frame
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
}
