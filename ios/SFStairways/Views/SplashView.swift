import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.brandOrange
                .ignoresSafeArea()

            Image("splash")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
    }
}
