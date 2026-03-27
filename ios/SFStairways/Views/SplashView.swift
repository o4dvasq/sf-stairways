import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(red: 232/255, green: 168/255, blue: 56/255)
                .ignoresSafeArea()

            Image("splash_image")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        }
    }
}
