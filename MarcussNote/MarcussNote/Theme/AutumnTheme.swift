import SwiftUI

enum AutumnTheme {

    // Palette autunnale: crema, avorio, ambra, ruggine, oliva
    static let cream = Color(hex: 0xFDF7EC)
    static let ivory = Color(hex: 0xFFFDF8)
    static let beige = Color(hex: 0xF2E4CE)
    static let sand = Color(hex: 0xE7D3B4)
    static let clay = Color(hex: 0xD9BE9A)

    static let amber = Color(hex: 0xE8A044)
    static let rust = Color(hex: 0xC1613B)
    static let terracotta = Color(hex: 0xB04A2A)
    static let pumpkin = Color(hex: 0xD2732C)
    static let walnut = Color(hex: 0x7A4A2B)
    static let olive = Color(hex: 0x7E7A45)
    static let oliveDark = Color(hex: 0x4E4A2A)
    static let slate = Color(hex: 0x4A5A6B)
    static let blue = Color(hex: 0x3E6480)

    static let ink = Color(hex: 0x33261A)
    static let inkSoft = Color(hex: 0x6B5744)
    static let inkFaint = Color(hex: 0x9C8874)

    // Sfondo scuro (notte autunnale)
    static let nightBg = Color(hex: 0x1E1913)
    static let nightSurface = Color(hex: 0x272118)
    static let nightSurfaceHi = Color(hex: 0x332B20)
    static let nightBorder = Color(hex: 0x453A2B)

    static func noteColor(_ index: Int) -> Color {
        let all: [Color] = [amber, rust, terracotta, pumpkin, olive, walnut, clay, sand]
        return all[abs(index) % all.count]
    }

    static func noteColorName(_ index: Int) -> String {
        let names = ["ambra", "ruggine", "terracotta", "zucca", "oliva", "noce", "argilla", "sabbia"]
        return names[abs(index) % names.count]
    }

    static let sidebarGradient = LinearGradient(
        colors: [cream, beige],
        startPoint: .top,
        endPoint: .bottom
    )

    static let nightSidebarGradient = LinearGradient(
        colors: [nightBg, Color(hex: 0x2A2116)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let accentGradient = LinearGradient(
        colors: [amber, rust],
        startPoint: .leading,
        endPoint: .trailing
    )

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? nightSurface : ivory
    }

    static func elevated(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? nightSurfaceHi : Color.white
    }

    static func border(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? nightBorder : Color(hex: 0xE6D7BE)
    }

    static func canvasBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x241E16) : Color(hex: 0xFFFDF7)
    }

    static func paper(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x201B14) : ivory
    }

    // MARK: - Testi adattivi

    static func text(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? ivory : ink
    }

    static func textSoft(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0xD8C6AC) : inkSoft
    }

    static func textFaint(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: 0x9C8874) : inkFaint
    }

    static func chipBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? nightSurfaceHi : Color.white
    }

    static func subtleFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? nightSurfaceHi : beige.opacity(0.55)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}