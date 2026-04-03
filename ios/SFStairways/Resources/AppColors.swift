import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension Color {
    // MARK: - Brand (warm terracotta, light/dark adaptive)

    #if canImport(UIKit)
    static let brandOrange = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xE0/255, green: 0x7A/255, blue: 0x52/255, alpha: 1) // #E07A52
            : UIColor(red: 0xD4/255, green: 0x72/255, blue: 0x4E/255, alpha: 1) // #D4724E
    })
    static let brandOrangeDark = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xC4/255, green: 0x68/255, blue: 0x42/255, alpha: 1) // #C46842
            : UIColor(red: 0xB8/255, green: 0x5A/255, blue: 0x38/255, alpha: 1) // #B85A38
    })
    #else
    static let brandOrange = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0xE0/255, green: 0x7A/255, blue: 0x52/255, alpha: 1) // #E07A52
            : NSColor(red: 0xD4/255, green: 0x72/255, blue: 0x4E/255, alpha: 1) // #D4724E
    })
    static let brandOrangeDark = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0xC4/255, green: 0x68/255, blue: 0x42/255, alpha: 1) // #C46842
            : NSColor(red: 0xB8/255, green: 0x5A/255, blue: 0x38/255, alpha: 1) // #B85A38
    })
    #endif

    // accentAmber: secondary warm accent, unchanged across light/dark
    static let accentAmber = Color(red: 0xE8/255, green: 0xA8/255, blue: 0x38/255) // #E8A838

    // MARK: - Pin / State Colors (unchanged)

    static let forestGreen = Color(red: 80/255, green: 200/255, blue: 120/255)

    static let brandAmber = Color(red: 212/255, green: 136/255, blue: 43/255)         // #D4882B
    static let brandAmberDark = Color(red: 181/255, green: 114/255, blue: 31/255)     // #B5721F
    static let pinSaved = Color(red: 129/255, green: 199/255, blue: 132/255)          // #81C784
    static let pinSavedDark = Color(red: 102/255, green: 187/255, blue: 106/255)      // #66BB6A
    static let walkedGreen = Color(red: 76/255, green: 175/255, blue: 80/255)         // #4CAF50
    static let walkedGreenDark = Color(red: 56/255, green: 142/255, blue: 60/255)     // #388E3C
    static let walkedGreenDim = Color(red: 120/255, green: 180/255, blue: 125/255)
    static let actionGreen = Color(red: 76/255, green: 175/255, blue: 80/255)
    static let unwalkedSlate = Color(red: 120/255, green: 144/255, blue: 156/255)     // #789094
    static let closedRed = Color(red: 176/255, green: 112/255, blue: 111/255)         // #B0706F

    // MARK: - Surface Tokens (light/dark adaptive, warm-tinted)

    #if canImport(UIKit)
    static let surfaceBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.systemBackground
            : UIColor(red: 0xFA/255, green: 0xFA/255, blue: 0xF7/255, alpha: 1) // #FAFAF7
    })
    static let surfaceCard = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x2C/255, green: 0x2C/255, blue: 0x2E/255, alpha: 1) // #2C2C2E
            : UIColor.white
    })
    static let surfaceCardElevated = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x3A/255, green: 0x3A/255, blue: 0x3C/255, alpha: 1) // #3A3A3C
            : UIColor(red: 0xF5/255, green: 0xF2/255, blue: 0xED/255, alpha: 1) // #F5F2ED
    })
    static let surfaceWalked = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 28/255, green: 46/255, blue: 30/255, alpha: 1)        // dark forest tint
            : UIColor(red: 240/255, green: 250/255, blue: 241/255, alpha: 1)     // #F0FAF1
    })
    #else
    static let surfaceBackground = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.windowBackgroundColor
            : NSColor(red: 0xFA/255, green: 0xFA/255, blue: 0xF7/255, alpha: 1) // #FAFAF7
    })
    static let surfaceCard = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0x2C/255, green: 0x2C/255, blue: 0x2E/255, alpha: 1) // #2C2C2E
            : NSColor.white
    })
    static let surfaceCardElevated = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0x3A/255, green: 0x3A/255, blue: 0x3C/255, alpha: 1) // #3A3A3C
            : NSColor(red: 0xF5/255, green: 0xF2/255, blue: 0xED/255, alpha: 1) // #F5F2ED
    })
    static let surfaceWalked = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 28/255, green: 46/255, blue: 30/255, alpha: 1)        // dark forest tint
            : NSColor(red: 240/255, green: 250/255, blue: 241/255, alpha: 1)     // #F0FAF1
    })
    #endif

    // MARK: - Text Tokens (adaptive)

    #if canImport(UIKit)
    static let textPrimary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xF5/255, green: 0xF5/255, blue: 0xF5/255, alpha: 1) // #F5F5F5
            : UIColor(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255, alpha: 1) // #1A1A1A
    })
    static let textSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0xA0/255, green: 0xA0/255, blue: 0xA0/255, alpha: 1) // #A0A0A0
            : UIColor(red: 0x6B/255, green: 0x6B/255, blue: 0x6B/255, alpha: 1) // #6B6B6B
    })
    #else
    static let textPrimary = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0xF5/255, green: 0xF5/255, blue: 0xF5/255, alpha: 1) // #F5F5F5
            : NSColor(red: 0x1A/255, green: 0x1A/255, blue: 0x1A/255, alpha: 1) // #1A1A1A
    })
    static let textSecondary = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0xA0/255, green: 0xA0/255, blue: 0xA0/255, alpha: 1) // #A0A0A0
            : NSColor(red: 0x6B/255, green: 0x6B/255, blue: 0x6B/255, alpha: 1) // #6B6B6B
    })
    #endif

    // MARK: - Structural Tokens (adaptive)

    #if canImport(UIKit)
    static let divider = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x3A/255, green: 0x3A/255, blue: 0x3C/255, alpha: 1) // #3A3A3C
            : UIColor(red: 0xE8/255, green: 0xE4/255, blue: 0xDF/255, alpha: 1) // #E8E4DF
    })
    #else
    static let divider = Color(NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0x3A/255, green: 0x3A/255, blue: 0x3C/255, alpha: 1) // #3A3A3C
            : NSColor(red: 0xE8/255, green: 0xE4/255, blue: 0xDF/255, alpha: 1) // #E8E4DF
    })
    #endif

    // MARK: - Tag Palette (12-color palette for tag pills)

    static let tagPalette: [Color] = [
        Color(red: 0.92, green: 0.55, blue: 0.55),  // rose
        Color(red: 0.52, green: 0.75, blue: 0.92),  // sky blue
        Color(red: 0.55, green: 0.90, blue: 0.55),  // mint green
        Color(red: 0.78, green: 0.72, blue: 0.32),  // warm yellow (darkened 15% for white text contrast)
        Color(red: 0.72, green: 0.52, blue: 0.92),  // lavender
        Color(red: 0.92, green: 0.62, blue: 0.42),  // peach
        Color(red: 0.38, green: 0.88, blue: 0.80),  // aqua
        Color(red: 0.85, green: 0.48, blue: 0.76),  // pink-purple
        Color(red: 0.48, green: 0.85, blue: 0.48),  // sage
        Color(red: 0.92, green: 0.58, blue: 0.32),  // apricot
        Color(red: 0.45, green: 0.65, blue: 0.92),  // cornflower
        Color(red: 0.75, green: 0.75, blue: 0.30),  // lemon (darkened 15% for white text contrast)
    ]

    // MARK: - UI Tokens

    static let pillActive = Color(red: 212/255, green: 136/255, blue: 43/255)         // #D4882B
    static let pillInactive = Color(red: 51/255, green: 51/255, blue: 51/255)         // #333333
    static let topBarBackground = Color.brandAmber
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
    static var surfaceBackground: Color { .surfaceBackground }
    static var surfaceCard: Color { .surfaceCard }
    static var surfaceCardElevated: Color { .surfaceCardElevated }
    static var surfaceWalked: Color { .surfaceWalked }
    static var textPrimary: Color { .textPrimary }
    static var textSecondary: Color { .textSecondary }
    static var divider: Color { .divider }
}
