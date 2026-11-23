import SwiftUI

public struct FloatingOverlayView: View {
    @ObservedObject var cameraManager = CameraManager.shared
    @Binding var settings: CameraSettings
    let onClose: () -> Void
    
    @State private var offset: CGSize = CGSize(width: 40, height: 100)
    @State private var dragOffset: CGSize = .zero
    @State private var currentWidth: CGFloat = 220
    @State private var isLocked: Bool = false
    @State private var isMinimized: Bool = false
    @State private var isHudVisible: Bool = true
    @State private var hudTimer: Timer?
    @State private var isPaused: Bool = false
    
    public init(settings: Binding<CameraSettings>, onClose: @escaping () -> Void) {
        self._settings = settings
        self.onClose = onClose
    }
    
    private var currentHeight: CGFloat {
        switch settings.shape {
        case .circle, .square1x1:
            return currentWidth
        case .portrait9x16:
            return (currentWidth * 16.0) / 9.0
        case .landscape16x9:
            return (currentWidth * 9.0) / 16.0
        }
    }
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if isMinimized {
                    // Minimized Edge Bubble (Identical to Android bg_minimized_pill)
                    Circle()
                        .fill(Color.obsidianSurface)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle().stroke(Color.primaryBlue, lineWidth: 2)
                        )
                        .overlay(
                            Image(systemName: "camera.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 22))
                        )
                        .overlay(
                            cameraManager.isRecording ?
                            Circle()
                                .fill(Color.recordingRed)
                                .frame(width: 12, height: 12)
                                .offset(x: 16, y: -16) : nil
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 6)
                        .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation
                                }
                                .onEnded { value in
                                    let rawX = offset.width + value.translation.width
                                    let snapX: CGFloat = (rawX < geometry.size.width / 2) ? 16 : (geometry.size.width - 72)
                                    let rawY = max(60, min(geometry.size.height - 120, offset.height + value.translation.height))
                                    withAnimation(.spring()) {
                                        offset = CGSize(width: snapX, height: rawY)
                                        dragOffset = .zero
                                    }
                                    HapticManager.shared.snapHaptic()
                                }
                        )
                        .onTapGesture {
                            withAnimation(.spring()) {
                                isMinimized = false
                            }
                            HapticManager.shared.lightTap()
                        }
                } else {
                    // Full Floating Camera Window (Identical to Android windowContainer)
                    VStack(spacing: 0) {
                        ZStack {
                            // Camera Preview Feed
                            CameraPreviewView(
                                session: cameraManager.session,
                                isMirrored: (settings.lens == .front && settings.mirrorFrontCamera)
                            )
                            .clipShape(shapeView)
                            .overlay(
                                shapeView.stroke(
                                    Color(hex: settings.borderColorHex),
                                    lineWidth: settings.borderWidth
                                )
                            )
                            .opacity(settings.opacity)
                            
                            // Touch overlay to toggle HUD
                            Color.clear
                                .contentShape(shapeView)
                                .onTapGesture {
                                    toggleHud()
                                }
                            
                            // Glassmorphic HUD Controls (Auto-fades after 3s)
                            if isHudVisible {
                                hudOverlay
                                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                            }
                            
                            // Corner Resize Handle (Bottom-Right, Identical to ic_resize_handle)
                            if !isLocked {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white.opacity(0.85))
                                            .frame(width: 26, height: 26)
                                            .background(Color.obsidianSurface.opacity(0.85))
                                            .clipShape(Circle())
                                            .gesture(
                                                DragGesture()
                                                    .onChanged { value in
                                                        let newWidth = max(140, min(geometry.size.width - 32, currentWidth + value.translation.width))
                                                        currentWidth = newWidth
                                                        resetAutoHideHud()
                                                    }
                                                    .onEnded { _ in
                                                        HapticManager.shared.snapHaptic()
                                                    }
                                            )
                                    }
                                }
                                .padding(6)
                            }
                        }
                        .frame(width: currentWidth, height: currentHeight)
                    }
                    .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
                    .gesture(
                        isLocked ? nil :
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                                resetAutoHideHud()
                            }
                            .onEnded { value in
                                offset.width = max(0, min(geometry.size.width - currentWidth, offset.width + value.translation.width))
                                offset.height = max(50, min(geometry.size.height - currentHeight - 60, offset.height + value.translation.height))
                                dragOffset = .zero
                                HapticManager.shared.snapHaptic()
                            }
                    )
                }
            }
        }
        .onAppear {
            scheduleAutoHideHud()
        }
    }
    
    // MARK: - Shape Clipping
    private var shapeView: AnyShape {
        switch settings.shape {
        case .circle:
            return AnyShape(Circle())
        case .square1x1:
            return AnyShape(RoundedRectangle(cornerRadius: 24))
        case .portrait9x16, .landscape16x9:
            return AnyShape(RoundedRectangle(cornerRadius: 20))
        }
    }
    
    // MARK: - HUD Controls Overlay (Matches overlay_camera_view.xml)
    private var hudOverlay: some View {
        VStack {
            // TOP HUD BAR
            HStack(spacing: 6) {
                // Live Recording Timer Badge (bg_recording_badge)
                if cameraManager.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.recordingRed)
                            .frame(width: 8, height: 8)
                        Text(formatDuration(cameraManager.recordingDuration))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.recordingRedDark)
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                // Quick Torch Toggle (btnTorch)
                if settings.lens == .back {
                    hudButton(icon: cameraManager.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill") {
                        cameraManager.toggleTorch()
                    }
                }
                
                // Mirror Toggle (btnMirror)
                hudButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                    settings.mirrorFrontCamera.toggle()
                }
                
                // Shape Preset Toggle (btnShape)
                hudButton(icon: "aspectratio") {
                    cycleShape()
                }
                
                // Lock Window Movement (btnLock)
                hudButton(icon: isLocked ? "lock.fill" : "lock.open.fill") {
                    isLocked.toggle()
                    HapticManager.shared.lightTap()
                }
                
                // Minimize Window (btnMinimize)
                hudButton(icon: "minus") {
                    withAnimation(.spring()) {
                        isMinimized = true
                    }
                    HapticManager.shared.snapHaptic()
                }
                
                // Close Window & Stop (btnClose)
                hudButton(icon: "xmark") {
                    onClose()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.obsidianSurface.opacity(0.85))
            .clipShape(Capsule())
            .padding(6)
            
            Spacer()
            
            // BOTTOM HUD BAR
            VStack(spacing: 4) {
                // Opacity Slider Row (opacityContainer)
                HStack(spacing: 8) {
                    Text("\(Int(settings.opacity * 100))%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.textSecondary)
                        .frame(width: 32, alignment: .leading)
                    
                    Slider(
                        value: $settings.opacity,
                        in: 0.3...1.0,
                        step: 0.05
                    )
                    .tint(Color.primaryBlue)
                }
                .padding(.horizontal, 8)
                
                // Main Actions: Flip, Shutter, Record, Pause
                HStack(spacing: 16) {
                    // Flip Camera (btnFlipCamera)
                    hudButton(icon: "camera.rotate.fill") {
                        cameraManager.flipCamera()
                        settings.lens = (settings.lens == .front) ? .back : .front
                    }
                    
                    // Photo Shutter (btnShutter)
                    Button(action: {
                        cameraManager.takePhoto()
                        resetAutoHideHud()
                    }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle().stroke(Color.primaryBlue, lineWidth: 2.5)
                            )
                    }
                    
                    // Video Record / Stop (btnRecord)
                    Button(action: {
                        cameraManager.toggleRecording()
                        resetAutoHideHud()
                    }) {
                        Circle()
                            .fill(cameraManager.isRecording ? Color.recordingRedDark : Color.recordingRed)
                            .frame(width: 36, height: 36)
                            .overlay(
                                Group {
                                    if cameraManager.isRecording {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.white)
                                            .frame(width: 13, height: 13)
                                    } else {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 13, height: 13)
                                    }
                                }
                            )
                    }
                    
                    // Pause / Resume during recording (btnPauseResume)
                    if cameraManager.isRecording {
                        hudButton(icon: isPaused ? "play.fill" : "pause.fill") {
                            isPaused.toggle()
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.obsidianSurface.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(6)
        }
    }
    
    private func cycleShape() {
        switch settings.shape {
        case .circle:
            settings.shape = .square1x1
        case .square1x1:
            settings.shape = .portrait9x16
        case .portrait9x16:
            settings.shape = .landscape16x9
        case .landscape16x9:
            settings.shape = .circle
        }
        HapticManager.shared.lightTap()
        resetAutoHideHud()
    }
    
    private func hudButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            resetAutoHideHud()
        }) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.obsidianSurfaceVariant.opacity(0.7))
                .clipShape(Circle())
        }
    }
    
    private func toggleHud() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isHudVisible.toggle()
        }
        if isHudVisible {
            scheduleAutoHideHud()
        }
    }
    
    private func scheduleAutoHideHud() {
        hudTimer?.invalidate()
        hudTimer = Timer.scheduledTimer(withTimeInterval: settings.autoHideHudTimeout, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHudVisible = false
            }
        }
    }
    
    private func resetAutoHideHud() {
        if !isHudVisible {
            withAnimation(.easeInOut(duration: 0.2)) {
                isHudVisible = true
            }
        }
        scheduleAutoHideHud()
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
