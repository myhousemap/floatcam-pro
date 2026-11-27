import Foundation
import Photos
import UIKit

@MainActor
public final class MediaManager: ObservableObject {
    public static let shared = MediaManager()
    
    @Published public var mediaItems: [MediaItem] = []
    @Published public var isLoading: Bool = false
    
    private let albumName = "FloatCam Pro"
    
    private init() {
        // Do not fetch at init to prevent crashes before user grants permissions
    }
    
    public func loadMedia() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            DispatchQueue.main.async {
                self.mediaItems = []
                self.isLoading = false
            }
            return
        }
        
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Only query our dedicated "FloatCam Pro" album to prevent memory crashes
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", self.albumName)
            let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
            
            guard let album = collections.firstObject else {
                DispatchQueue.main.async {
                    self.mediaItems = []
                    self.isLoading = false
                }
                return
            }
            
            let assetOptions = PHFetchOptions()
            assetOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let assets = PHAsset.fetchAssets(in: album, options: assetOptions)
            
            var items: [MediaItem] = []
            let imageManager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = true
            requestOptions.deliveryMode = .fastFormat
            requestOptions.isNetworkAccessAllowed = false
            
            assets.enumerateObjects { asset, _, _ in
                let isVideo = (asset.mediaType == .video)
                
                // Safe filename retrieval using PHAssetResource (prevents NSUnknownKeyException crash)
                let resources = PHAssetResource.assetResources(for: asset)
                let name = resources.first?.originalFilename ?? "Capture_\(asset.localIdentifier.prefix(8)).\(isVideo ? "mp4" : "jpg")"
                
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
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        if authStatus == .authorized || authStatus == .limited {
            // Primary: Save directly to Photo Library and add to "FloatCam Pro" dedicated album (exactly 1 video)
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
                if let placeholder = request?.placeholderForCreatedAsset {
                    self.addAssetToCustomAlbum(placeholder: placeholder)
                }
            }) { success, error in
                if !success {
                    print("PHPhotoLibrary save error: \(String(describing: error)), falling back to UIKit")
                    if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileURL.path) {
                        UISaveVideoAtPathToSavedPhotosAlbum(fileURL.path, nil, nil, nil)
                    }
                }
                DispatchQueue.main.async {
                    HapticManager.shared.successNotification()
                    self.loadMedia()
                    completion(true)
                }
            }
        } else {
            // Fallback: If readWrite permission is not granted (e.g. Add-only mode), save via UIKit (exactly 1 video)
            if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileURL.path) {
                UISaveVideoAtPathToSavedPhotosAlbum(fileURL.path, nil, nil, nil)
            }
            DispatchQueue.main.async {
                HapticManager.shared.successNotification()
                completion(true)
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
