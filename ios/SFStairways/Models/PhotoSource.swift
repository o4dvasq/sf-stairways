import Foundation

/// Unified photo source for display in PhotoCarousel.
/// A photo is either fetched from Supabase (.remote) or saved locally via SwiftData (.local).
enum PhotoSource: Identifiable {
    case remote(SupabasePhoto)
    case local(WalkPhoto)

    var id: String {
        switch self {
        case .remote(let p): return "r-\(p.id.uuidString)"
        case .local(let p): return "l-\(ObjectIdentifier(p))"
        }
    }

    var createdAt: Date {
        switch self {
        case .remote(let p): return p.createdDate ?? .distantPast
        case .local(let p): return p.createdAt
        }
    }
}
