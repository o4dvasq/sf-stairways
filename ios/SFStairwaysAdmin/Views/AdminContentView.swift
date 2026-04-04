import SwiftUI

struct AdminContentView: View {
    var body: some View {
        TabView {
            AdminMapTab()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
            AdminBrowser()
                .tabItem {
                    Label("List", systemImage: "list.bullet")
                }
        }
    }
}
