import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.brandOrange.ignoresSafeArea()

            GeometryReader { geo in
                Image("splash")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
        }
    }
}
