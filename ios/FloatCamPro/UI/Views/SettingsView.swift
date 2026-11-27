import SwiftUI

public struct SettingsView: View {
    @Binding var settings: CameraSettings
    
    private let colorPalette: [(hex: String, name: String)] = [
        ("#4F8CFF", "Electric Blue"),
        ("#00F5D4", "Cyber Neon"),
        ("#FFB703", "Amber Gold"),
        ("#FF4D5A", "Studio Coral"),
        ("#A855F7", "Neon Violet"),
        ("#E2E8F0", "Stealth Silver")
    ]
    
    public init(settings: Binding<CameraSettings>) {
        self._settings = settings
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 2) {
                    Text("Studio Settings")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("Customize overlay behavior, video encoding & styling")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 12)
                
                // 1. Camera & Capture
                sectionHeader("CAMERA & CAPTURE")
                settingsCard {
                    // Resolution
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default Video Quality")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text("Configures AVCaptureSession preset")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                        
                        HStack(spacing: 8) {
                            ForEach(VideoResolution.allCases) { res in
                                filterChip(title: res.rawValue, isSelected: settings.resolution == res) {
                                    settings.resolution = res
                                }
                            }
                        }
                    }
                    .padding()
                    
                    Divider().background(Color.obsidianBorder)
                    
                    // Frame Rate
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Target Frame Rate")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        
                        HStack(spacing: 8) {
                            ForEach(FrameRatePreference.allCases) { fps in
                                filterChip(title: fps.label, isSelected: settings.fps == fps) {
                                    settings.fps = fps
                                }
                            }
                        }
                    }
                    .padding()
                    
                    Divider().background(Color.obsidianBorder)
                    
                    // Audio Capture
                    Toggle(isOn: $settings.audioEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Capture Microphone Audio")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            Text("Records voice during video capture")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .tint(Color.primaryBlue)
                    .padding()
                    
                    Divider().background(Color.obsidianBorder)
                    
                    // Mirror Front Camera
                    Toggle(isOn: $settings.mirrorFrontCamera) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mirror Front Camera")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            Text("Horizontally flip preview for natural facecam view")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                        }
                    }
                    .tint(Color.primaryBlue)
                    .padding()
                }
                
                // 2. Overlay & Styling
                sectionHeader("OVERLAY & STYLING")
                settingsCard {
                    // Border Color
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Glowing Border Color")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        Text("Highlights overlay boundary against backgrounds")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                        
                        HStack {
                            ForEach(colorPalette, id: \.hex) { item in
                                let isSelected = (settings.borderColorHex == item.hex)
                                Circle()
                                    .fill(Color(hex: item.hex))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle().stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                                    )
                                    .overlay(
                                        isSelected ?
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.black) : nil
                                    )
                                    .onTapGesture {
                                        settings.borderColorHex = item.hex
                                        HapticManager.shared.lightTap()
                                    }
                            }
                        }
                    }
                    .padding()
                    
                    Divider().background(Color.obsidianBorder)
                    
                    // Border Thickness
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Border Width")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            Spacer()
                            Text("\(Int(settings.borderWidth)) pt")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primaryBlue)
                        }
                        Slider(value: $settings.borderWidth, in: 1...5, step: 1)
                            .tint(Color.primaryBlue)
                    }
                    .padding()
                    
                    Divider().background(Color.obsidianBorder)
                    
                    // Opacity
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Default Overlay Opacity")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            Spacer()
                            Text("\(Int(settings.opacity * 100))%")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.primaryBlue)
                        }
                        Slider(value: $settings.opacity, in: 0.3...1.0)
                            .tint(Color.primaryBlue)
                    }
                    .padding()
                    
                    Divider().background(Color.obsidianBorder)
                    
                    // Auto Hide Controls
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auto-Hide Controls Timeout")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        
                        HStack(spacing: 8) {
                            ForEach([2.0, 3.0, 5.0, 8.0], id: \.self) { sec in
                                filterChip(title: "\(Int(sec))s", isSelected: settings.autoHideHudTimeout == sec) {
                                    settings.autoHideHudTimeout = sec
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                // 3. System Picture-in-Picture Guide (iOS Multi-App Floating)
                sectionHeader("SYSTEM PICTURE-IN-PICTURE (iOS)")
                settingsCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "pip.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primaryBlue)
                            Text("Floating Camera Over Other Apps")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.textPrimary)
                        }
                        
                        Text("FloatCam Pro uses Apple's native AVPictureInPictureVideoCallViewController so your camera window stays floating over Gemini AI, Meta AI, Safari, WhatsApp, YouTube, and the Home Screen.")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                            .lineSpacing(2)
                        
                        Divider().background(Color.obsidianBorder)
                        
                        Text("Required iOS Setting:")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("1.")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primaryBlue)
                            Text("Open iPhone Settings > General > Picture in Picture.")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("2.")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primaryBlue)
                            Text("Turn ON 'Start PiP Automatically' so floating camera activates seamlessly when switching to any app.")
                                .font(.system(size: 12))
                                .foregroundColor(.textSecondary)
                        }
                        
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 12))
                                Text("Open iPhone Settings")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(Color.primaryBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                }
                
                // 4. App Details
                settingsCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("FloatCam Pro for iOS")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.textPrimary)
                        Text("Version 1.0.12 • Build 22 (Production)")
                            .font(.system(size: 12))
                            .foregroundColor(.textSecondary)
                        Text("Built with SwiftUI, AVFoundation, AVSampleBufferDisplayLayer, and Photos Scoped Media.")
                            .font(.system(size: 11))
                            .foregroundColor(.textMuted)
                            .padding(.top, 2)
                    }
                    .padding()
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal)
        }
        .background(Color.obsidianBackground)
    }
    
    // MARK: - Helpers
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.textSecondary)
            .padding(.leading, 4)
    }
    
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(Color.obsidianSurface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18).stroke(Color.obsidianBorder, lineWidth: 1)
        )
    }
    
    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            HapticManager.shared.lightTap()
        }) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : .textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.primaryBlue.opacity(0.25) : Color.obsidianSurfaceVariant)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? Color.primaryBlue : Color.obsidianBorder, lineWidth: 1)
                )
        }
    }
}
