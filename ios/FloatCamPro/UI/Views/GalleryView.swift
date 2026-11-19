import SwiftUI

public struct GalleryView: View {
    @ObservedObject var mediaManager = MediaManager.shared
    @State private var selectedItem: MediaItem?
    
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Studio Gallery")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.textPrimary)
                    Text("\(mediaManager.mediaItems.count) captures in FloatCam Pro")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                Button(action: {
                    mediaManager.loadMedia()
                    HapticManager.shared.lightTap()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primaryBlue)
                        .frame(width: 40, height: 40)
                        .background(Color.obsidianSurface)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.obsidianBorder, lineWidth: 1))
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 16)
            
            // Content
            if mediaManager.isLoading {
                Spacer()
                ProgressView()
                    .tint(Color.primaryBlue)
                Spacer()
            } else if mediaManager.mediaItems.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.obsidianSurface)
                        .frame(width: 72, height: 72)
                        .overlay(Circle().stroke(Color.obsidianBorder, lineWidth: 1))
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.textMuted)
                        )
                    Text("No captures yet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    Text("Launch floating camera to take photos\nor record videos.")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(mediaManager.mediaItems) { item in
                            thumbnailCell(for: item)
                                .onTapGesture {
                                    selectedItem = item
                                    HapticManager.shared.lightTap()
                                }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(Color.obsidianBackground)
        .sheet(item: $selectedItem) { item in
            MediaDetailView(
                item: item,
                onDismiss: { selectedItem = nil },
                onDelete: { mediaManager.deleteMedia(item: $0) { _ in } }
            )
        }
    }
    
    private func thumbnailCell(for item: MediaItem) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let thumb = item.thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.obsidianSurface)
                    .aspectRatio(1, contentMode: .fill)
            }
            
            if item.isVideo {
                // Subtle gradient
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Play Icon
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 22))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Duration Badge
                if item.duration > 0 {
                    let totalSecs = Int(item.duration)
                    let durStr = String(format: "%02d:%02d", totalSecs / 60, totalSecs % 60)
                    Text(durStr)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(4)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(Color.obsidianBorder, lineWidth: 1)
        )
    }
}
