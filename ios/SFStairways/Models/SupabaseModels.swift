import Foundation

// MARK: - User Profile

struct UserProfile: Codable {
    let id: UUID
    let displayName: String?
    let isPublic: Bool
    var hardModeEnabled: Bool
    let isCurator: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case isPublic = "is_public"
        case hardModeEnabled = "hard_mode_enabled"
        case isCurator = "is_curator"
    }
}

// MARK: - Curator Commentary

struct CuratorCommentary: Codable {
    let id: UUID
    let stairwayId: String
    let curatorId: UUID
    var commentary: String
    var isPublished: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case stairwayId = "stairway_id"
        case curatorId = "curator_id"
        case commentary
        case isPublished = "is_published"
    }
}

// MARK: - Supabase Photo

struct SupabasePhoto: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let walkRecordId: UUID
    let stairwayId: String
    let storagePath: String
    let thumbnailPath: String?
    let caption: String?
    let isPublic: Bool
    var likeCount: Int
    let createdAt: String

    var createdDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: createdAt) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: createdAt)
    }

    func thumbnailURL() -> URL? {
        let path = thumbnailPath ?? storagePath
        return SupabaseManager.shared.photoURL(storagePath: path)
    }

    func fullImageURL() -> URL? {
        SupabaseManager.shared.photoURL(storagePath: storagePath)
    }

    enum CodingKeys: String, CodingKey {
        case id, caption
        case userId = "user_id"
        case walkRecordId = "walk_record_id"
        case stairwayId = "stairway_id"
        case storagePath = "storage_path"
        case thumbnailPath = "thumbnail_path"
        case isPublic = "is_public"
        case likeCount = "like_count"
        case createdAt = "created_at"
    }
}

// MARK: - Supabase Walk Record (minimal, for photo upload flow)

struct SupabaseWalkRecord: Codable {
    let id: UUID
}
