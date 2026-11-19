import SwiftUI

public struct FloatingOverlayView: View {
    @ObservedObject var cameraManager = CameraManager.shared
    @Binding var settings: CameraSettings
    let onClose: () -> Void
    
    @State private var offset: CGSize = CGSize(width: 40, height: 100)
    @State private var currentWidth: CGFloat = 220
    @State private var isLocked: Bool = false
    @State private var isMinimized: Bool = false
    @State private var isHudVisible: Bool = true
    @State private var hudTimer: Timer?
    
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
                    // Minimized Edge Bubble
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
                        .offset(offset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: offset.width + value.translation.width,
                                        height: offset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    // Snap bubble to nearest screen edge
                                    let snapX: CGFloat = (offset.width < geometry.size.width / 2) ? 16 : (geometry.size.width - 72)
                                    withAnimation(.spring()) {
                                        offset.width = snapX
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
                    // Full Floating Camera Window
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
                            
                            // Glassmorphic HUD Controls
                            if isHudVisible {
                                hudOverlay
                                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                            }
                            
                            // Corner Resize Handle (Bottom-Right)
                            if !isLocked {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white.opacity(0.8))
                                            .frame(width: 28, height: 28)
                                            .background(Color.obsidianSurface.opacity(0.8))
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
                                .padding(8)
                            }
                        }
                        .frame(width: currentWidth, height: currentHeight)
                    }
                    .offset(offset)
                    .gesture(
                        isLocked ? nil :
                        DragGesture()
                            .onChanged { value in
                                offset = CGSize(
                                    width: max(0, min(geometry.size.width - currentWidth, offset.width + value.translation.width)),
                                    height: max(50, min(geometry.size.height - currentHeight - 60, offset.height + value.translation.height))
                                )
                                resetAutoHideHud()
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
    
    // MARK: - HUD Controls Overlay
    private var hudOverlay: some View {
        VStack {
            // TOP BAR
            HStack(spacing: 8) {
                // Recording Timer Badge
                if cameraManager.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.recordingRed)
                            .frame(width: 8, height: 8)
                        Text(formatDuration(cameraManager.recordingDuration))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.recordingRedDark)
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                // Torch Switch (Rear only)
                if settings.lens == .back {
                    hudButton(icon: cameraManager.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill") {
                        cameraManager.toggleTorch()
                    }
                }
                
                // Mirror Toggle
                hudButton(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                    settings.mirrorFrontCamera.toggle()
                }
                
                // Lock Toggle
                hudButton(icon: isLocked ? "lock.fill" : "lock.open.fill") {
                    isLocked.toggle()
                    HapticManager.shared.lightTap()
                }
                
                // Minimize Button
                hudButton(icon: "minus") {
                    withAnimation(.spring()) {
                        isMinimized = true
                    }
                    HapticManager.shared.snapHaptic()
                }
                
                // Close Button
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
            
            // BOTTOM BAR
            VStack(spacing: 4) {
                // Main Controls: Flip, Shutter, Record
                HStack(spacing: 16) {
                    // Flip Camera
                    hudButton(icon: "camera.rotate.fill") {
                        cameraManager.flipCamera()
                        settings.lens = (settings.lens == .front) ? .back : .front
                    }
                    
                    // Photo Shutter Button
                    Button(action: {
                        cameraManager.takePhoto()
                        resetAutoHideHud()
                    }) {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle().stroke(Color.primaryBlue, lineWidth: 3)
                            )
                    }
                    
                    // Video Record Button
                    Button(action: {
                        cameraManager.toggleRecording()
                        resetAutoHideHud()
                    }) {
                        Circle()
                            .fill(cameraManager.isRecording ? Color.recordingRedDark : Color.recordingRed)
                            .frame(width: 38, height: 38)
                            .overlay(
                                Group {
                                    if cameraManager.isRecording {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.white)
                                            .frame(width: 14, height: 14)
                                    } else {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 14, height: 14)
                                    }
                                }
                            )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.obsidianSurface.opacity(0.85))
            .clipShape(Capsule())
            .padding(6)
        }
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
                .background(Color.white.opacity(0.15))
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

// Helper Shape Wrapper for Dynamic Shape Clipping
public struct AnyShape: Shape {
    private let pathBlock: (CGRect) -> Path

    public init<S: Shape>(_ shape: S) {
        self.pathBlock = { rect in
            shape.path(in: rect)
        }
    }

    public func path(in rect: CGRect) -> Path {
        return pathBlock(rect)
    }
}
