import SwiftUI

/// Lightweight auto-dismissing toast displayed as a floating pill.
struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.75))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
    }
}

/// Modifier that shows a toast overlay and auto-dismisses after a delay.
extension View {
    func toast(message: Binding<String?>, duration: Double = 3.0) -> some View {
        self.modifier(ToastModifier(message: message, duration: duration))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: String?
    let duration: Double

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let msg = message {
                    ToastView(message: msg)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 100)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                                withAnimation(.easeOut) {
                                    message = nil
                                }
                            }
                        }
                }
            }
            .animation(.spring(response: 0.4), value: message)
    }
}
