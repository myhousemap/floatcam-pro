import SwiftUI

public struct OnboardingView: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    let onComplete: () -> Void
    
    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                Spacer().frame(height: 16)
                
                // Hero Studio Badge
                VStack(spacing: 14) {
                    ZStack {
                        // Ambient Radial Glow
                        Circle()
                            .fill(Color.primaryBlue.opacity(0.2))
                            .frame(width: 100, height: 100)
                            .blur(radius: 20)
                        
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.obsidianSurface)
                            .frame(width: 80, height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(
                                        LinearGradient(
                                            colors: [Color.primaryBlue.opacity(0.8), Color.primaryBlueDark.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1.5
                                    )
                            )
                            .shadow(color: Color.primaryBlue.opacity(0.3), radius: 12, y: 4)
                        
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.textPrimary, Color.primaryBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text("FloatCam Pro")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.textPrimary)
                            
                            Text("STUDIO")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.primaryBlue)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.primaryBlue.opacity(0.18))
                                .clipShape(Capsule())
                        }
                        
                        Text("Professional floating camera overlay & Picture-in-Picture studio for creators.")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                
                // Feature Highlight Bar
                HStack(spacing: 12) {
                    featurePill(icon: "pip.fill", title: "System PiP")
                    featurePill(icon: "circle.circle", title: "Facecam Shapes")
                    featurePill(icon: "sparkles.tv", title: "4K Capture")
                }
                .padding(.horizontal)
                
                // Permissions Section
                VStack(spacing: 12) {
                    // 1. Camera Access (Required)
                    interactivePermissionCard(
                        title: "Camera Access",
                        description: "Powers live floating feed and in-app camera previews.",
                        icon: "camera.fill",
                        isGranted: permissionManager.cameraGranted,
                        isDenied: permissionManager.cameraDenied,
                        isRequired: true
                    ) {
                        HapticManager.shared.lightTap()
                        permissionManager.requestCameraPermission { _ in }
                    }
                    
                    // 2. Photo Library Access (Required)
                    interactivePermissionCard(
                        title: "Photo Library Access",
                        description: "Saves high-res captures directly into your camera roll.",
                        icon: "photo.on.rectangle",
                        isGranted: permissionManager.photoLibraryGranted,
                        isDenied: permissionManager.photoLibraryDenied,
                        isRequired: true
                    ) {
                        HapticManager.shared.lightTap()
                        permissionManager.requestPhotoLibraryPermission { _ in }
                    }
                    
                    // 3. Microphone Access (Optional)
                    interactivePermissionCard(
                        title: "Microphone Audio",
                        description: "Records clear studio audio during video captures.",
                        icon: "mic.fill",
                        isGranted: permissionManager.microphoneGranted,
                        isDenied: permissionManager.microphoneDenied,
                        isRequired: false
                    ) {
                        HapticManager.shared.lightTap()
                        permissionManager.requestMicrophonePermission { _ in }
                    }
                }
                .padding(.horizontal)
                
                // Bottom Actions
                VStack(spacing: 12) {
                    let canProceed = permissionManager.allRequiredGranted
                    
                    if !canProceed {
                        // Quick Action: Grant All
                        Button(action: {
                            HapticManager.shared.mediumTap()
                            permissionManager.requestAllPermissions()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Grant All Permissions")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.primaryBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.primaryBlue.opacity(0.35), radius: 8, y: 3)
                        }
                    }
                    
                    // Primary Continue Button
                    Button(action: {
                        HapticManager.shared.successNotification()
                        onComplete()
                    }) {
                        HStack(spacing: 8) {
                            Text(canProceed ? "Get Started with FloatCam Pro" : "Continue to Studio")
                                .font(.system(size: 15, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundColor(canProceed ? .white : .textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(canProceed ? Color.primaryBlue : Color.obsidianSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(canProceed ? Color.clear : Color.obsidianBorder, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .background(Color.obsidianBackground.ignoresSafeArea())
        .onAppear {
            permissionManager.checkPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            permissionManager.checkPermissions()
        }
    }
    
    // MARK: - Components
    private func featurePill(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primaryBlue)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.obsidianSurface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.obsidianBorder, lineWidth: 1))
    }
    
    private func interactivePermissionCard(
        title: String,
        description: String,
        icon: String,
        isGranted: Bool,
        isDenied: Bool,
        isRequired: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.obsidianSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                isGranted ? Color.successGreen.opacity(0.4) : (isDenied ? Color.recordingRed.opacity(0.4) : Color.obsidianBorder),
                                lineWidth: 1
                            )
                    )
                
                HStack(spacing: 14) {
                    Circle()
                        .fill(isGranted ? Color.successGreen.opacity(0.15) : (isDenied ? Color.recordingRed.opacity(0.15) : Color.primaryBlue.opacity(0.12)))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(isGranted ? Color.successGreen : (isDenied ? Color.recordingRed : Color.primaryBlue))
                        )
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.textPrimary)
                            if isRequired {
                                Text("Required")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.recordingRed)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.recordingRed.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(description)
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    if isGranted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                            Text("Allowed")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.successGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.successGreen.opacity(0.12))
                        .clipShape(Capsule())
                    } else if isDenied {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Settings")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.recordingRed)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.recordingRed.opacity(0.15))
                        .clipShape(Capsule())
                    } else {
                        Text("Allow")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.primaryBlue)
                            .clipShape(Capsule())
                    }
                }
                .padding(14)
            }
        }
        .buttonStyle(.plain)
    }
}
