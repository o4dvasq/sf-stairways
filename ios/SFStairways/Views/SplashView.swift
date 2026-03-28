import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.brandAmber
                .ignoresSafeArea()

            Image("splash")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
    }
}
