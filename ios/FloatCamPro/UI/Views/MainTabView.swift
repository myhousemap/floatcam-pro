import SwiftUI

public enum AppTab: String, CaseIterable, Identifiable {
    case studio = "Studio"
    case gallery = "Gallery"
    case settings = "Settings"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .studio: return "video.fill"
        case .gallery: return "photo.on.rectangle.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

public struct MainTabView: View {
    @State private var selectedTab: AppTab = .studio
    @State private var settings = CameraSettings()
    @State private var isOverlayActive: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            Color.obsidianBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Tab Content
                Group {
                    switch selectedTab {
                    case .studio:
                        StudioView(settings: $settings, isOverlayActive: $isOverlayActive)
                    case .gallery:
                        GalleryView()
                    case .settings:
                        SettingsView(settings: $settings)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom Obsidian Navigation Bar
                HStack {
                    ForEach(AppTab.allCases) { tab in
                        let isSelected = (selectedTab == tab)
                        Spacer()
                        Button(action: {
                            selectedTab = tab
                            HapticManager.shared.lightTap()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 20, weight: isSelected ? .bold : .regular))
                                    .foregroundColor(isSelected ? .primaryBlue : .textSecondary)
                                Text(tab.rawValue)
                                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? .primaryBlue : .textSecondary)
                            }
                            .frame(height: 48)
                        }
                        Spacer()
                    }
                }
                .padding(.vertical, 8)
                .background(Color.obsidianSurface)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .overlay(
                    RoundedRectangle(cornerRadius: 22).stroke(Color.obsidianBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
            
            // In-App Floating Camera Overlay Window
            if isOverlayActive {
                FloatingOverlayView(settings: $settings) {
                    withAnimation(.spring()) {
                        isOverlayActive = false
                    }
                    CameraManager.shared.stopSession()
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}
