import Foundation
import Supabase
import UIKit

@Observable
final class PhotoLikeService {
    var photos: [SupabasePhoto] = []
    var likedPhotoIds: Set<UUID> = []
    var isLoading = false
    var uploadError: String? = nil

    private let supabase = SupabaseManager.shared.client

    // MARK: - Sorted Photos

    /// Most recent first, except the most-liked photo is promoted to position 2 if not already most recent.
    var sortedPhotos: [SupabasePhoto] {
        var sorted = photos.sorted {
            ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast)
        }
        guard sorted.count >= 2,
              let maxLiked = sorted.max(by: { $0.likeCount < $1.likeCount }),
              maxLiked.id != sorted[0].id
        else { return sorted }

        sorted.removeAll { $0.id == maxLiked.id }
        sorted.insert(maxLiked, at: min(1, sorted.count))
        return sorted
    }

    // MARK: - Fetch

    func fetchPhotos(stairwayId: String, userId: UUID?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched: [SupabasePhoto] = try await supabase
                .from("walk_photos")
                .select()
                .eq("stairway_id", value: stairwayId)
                .eq("is_public", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            photos = fetched
        } catch {
            photos = []
        }
        if let userId {
            await fetchLikedIds(userId: userId)
        }
    }

    private func fetchLikedIds(userId: UUID) async {
        do {
            struct LikeRecord: Decodable {
                let photoId: UUID
                enum CodingKeys: String, CodingKey {
                    case photoId = "photo_id"
                }
            }
            let likes: [LikeRecord] = try await supabase
                .from("photo_likes")
                .select("photo_id")
                .eq("user_id", value: userId.uuidString)
                .execute()
                .value
            likedPhotoIds = Set(likes.map(\.photoId))
        } catch {
            likedPhotoIds = []
        }
    }

    // MARK: - Like Toggle

    func toggleLike(photo: SupabasePhoto, userId: UUID) async {
        let isLiked = likedPhotoIds.contains(photo.id)

        // Optimistic update
        if isLiked {
            likedPhotoIds.remove(photo.id)
            updateLikeCount(photoId: photo.id, delta: -1)
        } else {
            likedPhotoIds.insert(photo.id)
            updateLikeCount(photoId: photo.id, delta: 1)
        }

        do {
            if isLiked {
                try await supabase
                    .from("photo_likes")
                    .delete()
                    .eq("user_id", value: userId.uuidString)
                    .eq("photo_id", value: photo.id.uuidString)
                    .execute()
            } else {
                struct LikeInsert: Encodable {
                    let user_id: String
                    let photo_id: String
                }
                try await supabase
                    .from("photo_likes")
                    .insert(LikeInsert(user_id: userId.uuidString, photo_id: photo.id.uuidString))
                    .execute()
            }
        } catch {
            // Revert optimistic update
            if isLiked {
                likedPhotoIds.insert(photo.id)
                updateLikeCount(photoId: photo.id, delta: 1)
            } else {
                likedPhotoIds.remove(photo.id)
                updateLikeCount(photoId: photo.id, delta: -1)
            }
        }
    }

    private func updateLikeCount(photoId: UUID, delta: Int) {
        if let idx = photos.firstIndex(where: { $0.id == photoId }) {
            photos[idx].likeCount = max(0, photos[idx].likeCount + delta)
        }
    }

    // MARK: - Upload

    func uploadPhoto(stairwayId: String, userId: UUID, imageData: Data) async throws {
        guard let image = UIImage(data: imageData) else { return }

        let compressedData = compressToMaxSize(image, maxBytes: 2 * 1024 * 1024) ?? imageData
        let thumbnailData = generateThumbnail(image)

        // Upsert walk_record in Supabase (insert if not exists)
        struct WalkRecordUpsert: Encodable {
            let user_id: String
            let stairway_id: String
        }
        try await supabase
            .from("walk_records")
            .upsert(
                WalkRecordUpsert(user_id: userId.uuidString, stairway_id: stairwayId),
                onConflict: "user_id,stairway_id",
                ignoreDuplicates: true
            )
            .execute()

        // Fetch the walk_record ID
        let records: [SupabaseWalkRecord] = try await supabase
            .from("walk_records")
            .select("id")
            .eq("user_id", value: userId.uuidString)
            .eq("stairway_id", value: stairwayId)
            .limit(1)
            .execute()
            .value
        guard let walkRecordId = records.first?.id else { return }

        // Upload to Supabase Storage
        let photoId = UUID()
        let basePath = "\(userId.uuidString)/\(walkRecordId.uuidString)/\(photoId.uuidString)"
        let fullPath = "\(basePath).jpg"
        let thumbPath = "\(basePath)_thumb.jpg"

        try await supabase.storage
            .from("photos")
            .upload(fullPath, data: compressedData, options: FileOptions(contentType: "image/jpeg"))

        if let thumbData = thumbnailData {
            try? await supabase.storage
                .from("photos")
                .upload(thumbPath, data: thumbData, options: FileOptions(contentType: "image/jpeg"))
        }

        // Insert walk_photos row
        struct PhotoInsert: Encodable {
            let user_id: String
            let walk_record_id: String
            let stairway_id: String
            let storage_path: String
            let thumbnail_path: String?
            let is_public: Bool
        }
        let inserted: [SupabasePhoto] = try await supabase
            .from("walk_photos")
            .insert(PhotoInsert(
                user_id: userId.uuidString,
                walk_record_id: walkRecordId.uuidString,
                stairway_id: stairwayId,
                storage_path: fullPath,
                thumbnail_path: thumbnailData != nil ? thumbPath : nil,
                is_public: true
            ))
            .select()
            .execute()
            .value
        if let newPhoto = inserted.first {
            photos.insert(newPhoto, at: 0)
        }
    }

    // MARK: - Image Helpers

    private func compressToMaxSize(_ image: UIImage, maxBytes: Int) -> Data? {
        var quality: CGFloat = 0.85
        while quality > 0.1 {
            if let data = image.jpegData(compressionQuality: quality), data.count <= maxBytes {
                return data
            }
            quality -= 0.15
        }
        return image.jpegData(compressionQuality: 0.1)
    }

    private func generateThumbnail(_ image: UIImage) -> Data? {
        let size = CGSize(width: 400, height: 400)
        let scale = min(size.width / image.size.width, size.height / image.size.height)
        let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (size.width - scaledSize.width) / 2, y: (size.height - scaledSize.height) / 2)
        let renderer = UIGraphicsImageRenderer(size: size)
        let thumb = renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
        return thumb.jpegData(compressionQuality: 0.7)
    }
}
