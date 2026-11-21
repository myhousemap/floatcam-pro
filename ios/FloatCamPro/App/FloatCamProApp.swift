import SwiftUI

@main
struct FloatCamProApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @StateObject private var permissionManager = PermissionManager.shared
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.obsidianBackground.ignoresSafeArea()
                
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            hasCompletedOnboarding = true
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }
}
