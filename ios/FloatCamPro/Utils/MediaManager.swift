import Foundation
import Photos
import UIKit

public final class MediaManager: ObservableObject {
    public static let shared = MediaManager()
    
    @Published public var mediaItems: [MediaItem] = []
    @Published public var isLoading: Bool = false
    
    private let albumName = "FloatCam Pro"
    
    private init() {
        loadMedia()
    }
    
    public func loadMedia() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var items: [MediaItem] = []
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let fetchResult = PHAsset.fetchAssets(with: fetchOptions)
            let imageManager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = true
            requestOptions.deliveryMode = .fastFormat
            
            fetchResult.enumerateObjects { asset, _, _ in
                let isVideo = (asset.mediaType == .video)
                let name = asset.value(forKey: "filename") as? String ?? "Capture_\(asset.localIdentifier).\(isVideo ? "mp4" : "jpg")"
                
                var thumbnail: UIImage?
                let targetSize = CGSize(width: 250, height: 250)
                imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: requestOptions) { image, _ in
                    thumbnail = image
                }
                
                let item = MediaItem(
                    id: asset.localIdentifier,
                    name: name,
                    isVideo: isVideo,
                    duration: asset.duration,
                    creationDate: asset.creationDate ?? Date(),
                    sizeFormatted: "\(asset.pixelWidth)x\(asset.pixelHeight)",
                    thumbnail: thumbnail,
                    localURL: nil
                )
                items.append(item)
            }
            
            DispatchQueue.main.async {
                self.mediaItems = items
                self.isLoading = false
            }
        }
    }
    
    public func savePhoto(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            if let placeholder = creationRequest.placeholderForCreatedAsset {
                self.addAssetToCustomAlbum(placeholder: placeholder)
            }
        }) { success, _ in
            DispatchQueue.main.async {
                if success {
                    HapticManager.shared.successNotification()
                    self.loadMedia()
                }
                completion(success)
            }
        }
    }
    
    public func saveVideo(at fileURL: URL, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            if let placeholder = creationRequest?.placeholderForCreatedAsset {
                self.addAssetToCustomAlbum(placeholder: placeholder)
            }
        }) { success, _ in
            DispatchQueue.main.async {
                if success {
                    HapticManager.shared.successNotification()
                    self.loadMedia()
                }
                completion(success)
            }
        }
    }
    
    public func deleteMedia(item: MediaItem, completion: @escaping (Bool) -> Void) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [item.id], options: nil)
        guard assets.count > 0 else {
            completion(false)
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets)
        }) { success, _ in
            DispatchQueue.main.async {
                if success {
                    self.mediaItems.removeAll { $0.id == item.id }
                }
                completion(success)
            }
        }
    }
    
    private func addAssetToCustomAlbum(placeholder: PHObjectPlaceholder) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let album = collection.firstObject {
            let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
            albumChangeRequest?.addAssets([placeholder] as NSArray)
        } else {
            let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            createAlbumRequest.addAssets([placeholder] as NSArray)
        }
    }
}
