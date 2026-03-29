import Foundation
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

@Model
final class WalkPhoto {
    @Attribute(.externalStorage) var imageData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var caption: String?
    var takenAt: Date = Date()
    var createdAt: Date = Date()

    var walkRecord: WalkRecord?

    init(
        imageData: Data,
        thumbnailData: Data? = nil,
        caption: String? = nil,
        takenAt: Date = Date()
    ) {
        self.imageData = imageData
        self.thumbnailData = thumbnailData ?? Self.generateThumbnail(from: imageData)
        self.caption = caption
        self.takenAt = takenAt
        self.createdAt = Date()
    }

#if canImport(UIKit)
    var thumbnailImage: UIImage? {
        guard let data = thumbnailData else { return nil }
        return UIImage(data: data)
    }

    var fullImage: UIImage? {
        guard let data = imageData else { return nil }
        return UIImage(data: data)
    }
#endif

    static func generateThumbnail(from imageData: Data, maxWidth: CGFloat = 300) -> Data? {
#if canImport(UIKit)
        guard let image = UIImage(data: imageData) else { return nil }
        let scale = maxWidth / image.size.width
        guard scale < 1 else { return imageData }
        let newSize = CGSize(width: maxWidth, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let thumbnailImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return thumbnailImage.jpegData(compressionQuality: 0.7)
#else
        // On macOS, return the original data — NSImage can decode it directly.
        return imageData
#endif
    }
}
