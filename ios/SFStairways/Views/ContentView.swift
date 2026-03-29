import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var coordinator = NavigationCoordinator()

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

            SearchTab(
                onSelectStairway: { stairway in
                    selectedTab = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        coordinator.pendingStairway = stairway
                    }
                },
                onSelectNeighborhood: { neighborhood in
                    selectedTab = 0
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        coordinator.pendingNeighborhood = neighborhood
                    }
                }
            )
            .tabItem {
                Image(systemName: "magnifyingglass")
                Text("Search")
            }
            .tag(3)
        }
        .tint(Color.forestGreen)
        .environment(coordinator)
    }
}

private struct SearchTab: View {
    @Query private var walkRecords: [WalkRecord]
    @State private var store = StairwayStore()
    @State private var locationManager = LocationManager()
    let onSelectStairway: (Stairway) -> Void
    let onSelectNeighborhood: (String) -> Void

    var body: some View {
        SearchPanel(
            store: store,
            walkRecords: walkRecords,
            userLocation: locationManager.currentLocation,
            onSelectStairway: onSelectStairway,
            onSelectNeighborhood: onSelectNeighborhood,
            isTabMode: true
        )
        .onAppear { locationManager.requestPermission() }
    }
}
