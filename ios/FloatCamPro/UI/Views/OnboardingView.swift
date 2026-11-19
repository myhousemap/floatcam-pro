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
                Spacer().frame(height: 20)
                
                // Icon Badge
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.obsidianSurface)
                        .frame(width: 72, height: 72)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22).stroke(Color.obsidianBorder, lineWidth: 1)
                        )
                    Image(systemName: "camera.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.primaryBlue)
                }
                
                VStack(spacing: 8) {
                    Text("Welcome to FloatCam Pro")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("To enable floating camera overlays and Picture-in-Picture recording, please grant the following permissions.")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                
                VStack(spacing: 12) {
                    // 1. Camera Access
                    permissionCard(
                        title: "Camera Access",
                        description: "Required to preview and capture photos/videos.",
                        icon: "camera.fill",
                        isGranted: permissionManager.cameraGranted,
                        isRequired: true
                    ) {
                        permissionManager.requestCameraPermission { _ in }
                    }
                    
                    // 2. Photo Library
                    permissionCard(
                        title: "Photo Library Access",
                        description: "Saves high-res photos and video recordings into your camera roll.",
                        icon: "photo.on.rectangle",
                        isGranted: permissionManager.photoLibraryGranted,
                        isRequired: true
                    ) {
                        permissionManager.requestPhotoLibraryPermission { _ in }
                    }
                    
                    // 3. Microphone Access
                    permissionCard(
                        title: "Microphone Audio",
                        description: "Records clear audio during video captures.",
                        icon: "mic.fill",
                        isGranted: permissionManager.microphoneGranted,
                        isRequired: false
                    ) {
                        permissionManager.requestMicrophonePermission { _ in }
                    }
                    
                    // 4. Picture-in-Picture Explanation
                    ZStack {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color.obsidianSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18).stroke(Color.obsidianBorder, lineWidth: 1)
                            )
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color.primaryBlue.opacity(0.15))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Image(systemName: "pip.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.primaryBlue)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("System Floating (PiP)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.textPrimary)
                                Text("Floats your camera feed over Home Screen and other apps using iOS Picture-in-Picture.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                    }
                }
                .padding(.horizontal)
                
                // Continue Button
                let canProceed = permissionManager.allRequiredGranted
                Button(action: {
                    if canProceed {
                        HapticManager.shared.successNotification()
                        onComplete()
                    }
                }) {
                    Text(canProceed ? "Get Started with FloatCam Pro" : "Grant Required Permissions Above")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(canProceed ? .white : .textMuted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(canProceed ? Color.primaryBlue : Color.obsidianSurfaceVariant)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!canProceed)
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
        }
        .background(Color.obsidianBackground)
        .onAppear {
            permissionManager.checkPermissions()
        }
    }
    
    private func permissionCard(
        title: String,
        description: String,
        icon: String,
        isGranted: Bool,
        isRequired: Bool,
        action: @escaping () -> Void
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.obsidianSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 18).stroke(Color.obsidianBorder, lineWidth: 1)
                )
            
            HStack(spacing: 14) {
                Circle()
                    .fill(isGranted ? Color.successGreen.opacity(0.15) : Color.obsidianSurfaceVariant)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(isGranted ? Color.successGreen : Color.textSecondary)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.textPrimary)
                        if isRequired {
                            Text("Required")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.recordingRed)
                        }
                    }
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                if isGranted {
                    Circle()
                        .fill(Color.successGreen)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        )
                } else {
                    Button(action: action) {
                        Text("Allow")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primaryBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.primaryBlue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(16)
        }
    }
}
