import Foundation
import Supabase

@Observable
final class CuratorService {
    var commentary: CuratorCommentary? = nil
    var isLoading = false

    private let supabase = SupabaseManager.shared.client

    // Fetch published commentary (all users)
    func fetchPublished(stairwayId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let results: [CuratorCommentary] = try await supabase
                .from("curator_commentary")
                .select()
                .eq("stairway_id", value: stairwayId)
                .eq("is_published", value: true)
                .limit(1)
                .execute()
                .value
            commentary = results.first
        } catch {
            commentary = nil
        }
    }

    // Fetch any commentary for editor (curator only — includes drafts)
    func fetchForEditor(stairwayId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let results: [CuratorCommentary] = try await supabase
                .from("curator_commentary")
                .select()
                .eq("stairway_id", value: stairwayId)
                .limit(1)
                .execute()
                .value
            commentary = results.first
        } catch {
            commentary = nil
        }
    }

    // Upsert commentary (curator only)
    func upsert(stairwayId: String, curatorId: UUID, text: String, isPublished: Bool) async throws {
        struct UpsertPayload: Encodable {
            let stairway_id: String
            let curator_id: String
            let commentary: String
            let is_published: Bool
        }
        let payload = UpsertPayload(
            stairway_id: stairwayId,
            curator_id: curatorId.uuidString,
            commentary: text,
            is_published: isPublished
        )
        let results: [CuratorCommentary] = try await supabase
            .from("curator_commentary")
            .upsert(payload, onConflict: "stairway_id")
            .select()
            .execute()
            .value
        commentary = results.first
    }
}
