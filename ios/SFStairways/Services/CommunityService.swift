import Foundation
import Supabase

@Observable
final class CommunityService {
    var climbCounts: [String: Int] = [:]

    private let supabase = SupabaseManager.shared.client

    func climberCount(for stairwayID: String) -> Int {
        climbCounts[stairwayID] ?? 0
    }

    func fetchClimbCounts() async {
        struct ClimbCountRow: Decodable {
            let stairway_id: String
            let climber_count: Int
        }
        do {
            let rows: [ClimbCountRow] = try await supabase
                .from("stairway_climb_counts")
                .select()
                .execute()
                .value
            var counts: [String: Int] = [:]
            for row in rows { counts[row.stairway_id] = row.climber_count }
            await MainActor.run { self.climbCounts = counts }
        } catch {
            print("[CommunityService] Failed to fetch climb counts: \(error)")
        }
    }

    func reportWalk(stairwayID: String, userID: UUID) async {
        struct WalkEvent: Encodable {
            let stairway_id: String
            let user_id: String
            let walked_at: String
            let removed_at: String? = nil
        }
        do {
            try await supabase
                .from("stairway_walk_events")
                .upsert(
                    WalkEvent(
                        stairway_id: stairwayID,
                        user_id: userID.uuidString,
                        walked_at: ISO8601DateFormatter().string(from: Date())
                    ),
                    onConflict: "stairway_id,user_id"
                )
                .execute()
            await fetchClimbCounts()
        } catch {
            print("[CommunityService] Failed to report walk: \(error)")
        }
    }

    func reportUnwalk(stairwayID: String, userID: UUID) async {
        struct UnwalkUpdate: Encodable {
            let removed_at: String
        }
        do {
            try await supabase
                .from("stairway_walk_events")
                .update(UnwalkUpdate(removed_at: ISO8601DateFormatter().string(from: Date())))
                .eq("stairway_id", value: stairwayID)
                .eq("user_id", value: userID.uuidString)
                .execute()
            await fetchClimbCounts()
        } catch {
            print("[CommunityService] Failed to report unwalk: \(error)")
        }
    }
}
