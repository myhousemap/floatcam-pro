import SwiftUI

public struct MediaDetailView: View {
    public let item: MediaItem
    public let onDismiss: () -> Void
    public let onDelete: (MediaItem) -> Void
    
    @State private var isShowingShareSheet: Bool = false
    
    public init(item: MediaItem, onDismiss: @escaping () -> Void, onDelete: @escaping (MediaItem) -> Void) {
        self.item = item
        self.onDismiss = onDismiss
        self.onDelete = onDelete
    }
    
    public var body: some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()
            
            VStack {
                // Top Bar
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.obsidianSurface)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 12) {
                        // Share
                        Button(action: {
                            isShowingShareSheet = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primaryBlue)
                                .frame(width: 36, height: 36)
                                .background(Color.obsidianSurface)
                                .clipShape(Circle())
                        }
                        
                        // Delete
                        Button(action: {
                            onDelete(item)
                            onDismiss()
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.recordingRed)
                                .frame(width: 36, height: 36)
                                .background(Color.obsidianSurface)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                // Media Thumbnail Preview
                if let thumb = item.thumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .cornerRadius(18)
                        .padding(.horizontal)
                        .shadow(radius: 12)
                }
                
                Spacer()
                
                // Metadata Card
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    HStack {
                        Text(formatDate(item.creationDate))
                        Text("•")
                        Text(item.sizeFormatted)
                        if item.isVideo && item.duration > 0 {
                            Text("•")
                            Text(formatDuration(item.duration))
                                .foregroundColor(.primaryBlue)
                        }
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.obsidianSurface)
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18).stroke(Color.obsidianBorder, lineWidth: 1)
                )
                .padding()
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let image = item.thumbnail {
                ShareSheet(activityItems: [image])
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

public struct ShareSheet: UIViewControllerRepresentable {
    public let activityItems: [Any]
    
    public func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
