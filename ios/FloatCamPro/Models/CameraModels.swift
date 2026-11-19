import Foundation
import SwiftUI

public enum ShapePreset: String, CaseIterable, Identifiable, Codable {
    case circle = "Circle (Facecam)"
    case square1x1 = "Square (1:1)"
    case portrait9x16 = "Portrait (9:16)"
    case landscape16x9 = "Landscape (16:9)"

    public var id: String { rawValue }

    public var aspectRatio: CGFloat {
        switch self {
        case .circle, .square1x1:
            return 1.0
        case .portrait9x16:
            return 9.0 / 16.0
        case .landscape16x9:
            return 16.0 / 9.0
        }
    }
}

public enum CameraLens: String, CaseIterable, Identifiable, Codable {
    case front = "Front Camera"
    case back = "Rear Camera"

    public var id: String { rawValue }
}

public enum VideoResolution: String, CaseIterable, Identifiable, Codable {
    case hd720p = "HD 720p"
    case fhd1080p = "FHD 1080p"
    case uhd4k = "4K UHD"

    public var id: String { rawValue }
}

public enum FrameRatePreference: Int, CaseIterable, Identifiable, Codable {
    case fps30 = 30
    case fps60 = 60

    public var id: Int { rawValue }
    public var label: String { "\(rawValue) FPS" }
}

public struct CameraSettings: Codable {
    public var shape: ShapePreset = .circle
    public var lens: CameraLens = .front
    public var resolution: VideoResolution = .fhd1080p
    public var fps: FrameRatePreference = .fps30
    public var audioEnabled: BooleanLiteralType = true
    public var mirrorFrontCamera: Bool = true
    public var opacity: Double = 1.0
    public var borderColorHex: String = "#4F8CFF"
    public var borderWidth: CGFloat = 2.0
    public var keepScreenOn: Bool = true
    public var autoHideHudTimeout: Double = 3.0
    public var enableSystemPiP: Bool = true
    
    public init() {}
}

public struct MediaItem: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let isVideo: Bool
    public let duration: TimeInterval
    public let creationDate: Date
    public let sizeFormatted: String
    public let thumbnail: UIImage?
    public let localURL: URL?
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        isVideo: Bool,
        duration: TimeInterval = 0,
        creationDate: Date = Date(),
        sizeFormatted: String = "",
        thumbnail: UIImage? = nil,
        localURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.isVideo = isVideo
        self.duration = duration
        self.creationDate = creationDate
        self.sizeFormatted = sizeFormatted
        self.thumbnail = thumbnail
        self.localURL = localURL
    }
}
