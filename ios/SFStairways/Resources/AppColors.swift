import SwiftUI

extension Color {
    static let forestGreen = Color(red: 45/255, green: 95/255, blue: 63/255)
    static let accentAmber = Color(red: 232/255, green: 168/255, blue: 56/255)        // splash screen only

    // Brand colors
    static let brandOrange = Color(red: 0.91, green: 0.376, blue: 0.173)             // #E8602C — app brand
    static let brandOrangeDark = Color(red: 0.75, green: 0.29, blue: 0.12)          // #BF4A1F — selected pin

    // Pin colors
    static let brandAmber = Color(red: 212/255, green: 136/255, blue: 43/255)         // #D4882B — unsaved pins
    static let brandAmberDark = Color(red: 181/255, green: 114/255, blue: 31/255)     // #B5721F — selected unsaved
    static let pinSaved = Color(red: 129/255, green: 199/255, blue: 132/255)          // #81C784 — saved pins
    static let pinSavedDark = Color(red: 102/255, green: 187/255, blue: 106/255)      // #66BB6A — selected saved
    static let walkedGreen = Color(red: 76/255, green: 175/255, blue: 80/255)         // #4CAF50 — walked pins
    static let walkedGreenDark = Color(red: 56/255, green: 142/255, blue: 60/255)     // #388E3C — selected walked
    static let walkedGreenDim = Color(red: 120/255, green: 180/255, blue: 125/255)    // informational
    static let actionGreen = Color(red: 76/255, green: 175/255, blue: 80/255)         // CTA buttons
    static let unwalkedSlate = Color(red: 120/255, green: 144/255, blue: 156/255)     // closed stairways
    static let closedRed = Color(red: 176/255, green: 112/255, blue: 111/255)

    // Surface colors
    static let pillActive = Color(red: 212/255, green: 136/255, blue: 43/255)         // #D4882B — active filter pill
    static let pillInactive = Color(red: 51/255, green: 51/255, blue: 51/255)         // #333333 — inactive filter pill
    static let topBarBackground = Color.brandOrange                                    // #E8602C
    static let topBarText = Color.white
}

extension ShapeStyle where Self == Color {
    static var forestGreen: Color { .forestGreen }
    static var brandOrangeDark: Color { .brandOrangeDark }
    static var brandAmber: Color { .brandAmber }
    static var brandAmberDark: Color { .brandAmberDark }
    static var pinSaved: Color { .pinSaved }
    static var pinSavedDark: Color { .pinSavedDark }
    static var walkedGreen: Color { .walkedGreen }
    static var walkedGreenDark: Color { .walkedGreenDark }
    static var walkedGreenDim: Color { .walkedGreenDim }
    static var actionGreen: Color { .actionGreen }
    static var unwalkedSlate: Color { .unwalkedSlate }
    static var closedRed: Color { .closedRed }
    static var pillActive: Color { .pillActive }
    static var pillInactive: Color { .pillInactive }
}
