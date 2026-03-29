import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MapTab()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Map")
                }
                .tag(0)

            ListTab()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("List")
                }
                .tag(1)

            ProgressTab()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Stats")
                }
                .tag(2)
        }
        .tint(Color.forestGreen)
    }
}
