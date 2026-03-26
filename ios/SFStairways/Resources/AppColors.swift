import SwiftUI

extension Color {
    static let forestGreen = Color(red: 45/255, green: 95/255, blue: 63/255)
    static let accentAmber = Color(red: 232/255, green: 168/255, blue: 56/255)
    static let walkedGreen = Color(red: 76/255, green: 175/255, blue: 80/255)
    static let walkedGreenDim = Color(red: 120/255, green: 180/255, blue: 125/255)  // informational
    static let actionGreen = Color(red: 76/255, green: 175/255, blue: 80/255)       // CTA buttons
    static let unwalkedSlate = Color(red: 120/255, green: 144/255, blue: 156/255)
    static let closedRed = Color(red: 176/255, green: 112/255, blue: 111/255)
    static let brandOrange = Color(red: 232/255, green: 96/255, blue: 44/255)       // #E8602C — Saved pins
    static let brandOrangeDark = Color(red: 192/255, green: 74/255, blue: 26/255)   // #C04A1A — Selected saved pin
}

extension ShapeStyle where Self == Color {
    static var forestGreen: Color { .forestGreen }
    static var walkedGreen: Color { .walkedGreen }
    static var walkedGreenDim: Color { .walkedGreenDim }
    static var actionGreen: Color { .actionGreen }
    static var unwalkedSlate: Color { .unwalkedSlate }
    static var closedRed: Color { .closedRed }
    static var brandOrange: Color { .brandOrange }
    static var brandOrangeDark: Color { .brandOrangeDark }
}
