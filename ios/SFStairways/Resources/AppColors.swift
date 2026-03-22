import SwiftUI

extension Color {
    static let forestGreen = Color(red: 45/255, green: 95/255, blue: 63/255)
    static let accentAmber = Color(red: 232/255, green: 168/255, blue: 56/255)
    static let walkedGreen = Color(red: 76/255, green: 175/255, blue: 80/255)
    static let unwalkedSlate = Color(red: 120/255, green: 144/255, blue: 156/255)
    static let closedRed = Color(red: 176/255, green: 112/255, blue: 111/255)
}

extension ShapeStyle where Self == Color {
    static var forestGreen: Color { .forestGreen }
    static var walkedGreen: Color { .walkedGreen }
    static var unwalkedSlate: Color { .unwalkedSlate }
    static var closedRed: Color { .closedRed }
}
