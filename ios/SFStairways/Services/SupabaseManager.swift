import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()
    let client: SupabaseClient
    private let supabaseURL: URL

    private init() {
        guard
            let path = Bundle.main.path(forResource: "Supabase", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path),
            let urlString = dict["SUPABASE_URL"] as? String,
            let key = dict["SUPABASE_ANON_KEY"] as? String,
            let url = URL(string: urlString)
        else {
            fatalError("[SFStairways] Missing or malformed Supabase.plist — see supabase/SETUP_GUIDE.md")
        }
        supabaseURL = url
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }

    /// Public URL for a photo in the "photos" storage bucket.
    func photoURL(storagePath: String) -> URL? {
        URL(string: "\(supabaseURL.absoluteString)/storage/v1/object/public/photos/\(storagePath)")
    }
}
