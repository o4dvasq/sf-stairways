import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()
    let client: SupabaseClient

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
        client = SupabaseClient(supabaseURL: url, supabaseKey: key)
    }
}
