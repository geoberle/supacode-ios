import SwiftUI

extension Color {
    private static let namedColors: [String: Color] = [
        "red": .red,
        "orange": .orange,
        "yellow": .yellow,
        "green": .green,
        "teal": .teal,
        "blue": .blue,
        "purple": .purple
    ]

    init?(supacodeTint: String?) {
        guard let tint = supacodeTint else { return nil }
        if let named = Self.namedColors[tint.lowercased()] {
            self = named
        } else if tint.hasPrefix("#"), let hex = Self.fromHex(tint) {
            self = hex
        } else {
            return nil
        }
    }

    private static func fromHex(_ hex: String) -> Color? {
        var raw = hex
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6 || raw.count == 8 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: raw).scanHexInt64(&value) else { return nil }
        if raw.count == 8 {
            return Color(
                .sRGB,
                red: Double((value & 0xFF00_0000) >> 24) / 255,
                green: Double((value & 0x00FF_0000) >> 16) / 255,
                blue: Double((value & 0x0000_FF00) >> 8) / 255,
                opacity: Double(value & 0x0000_00FF) / 255
            )
        }
        return Color(
            .sRGB,
            red: Double((value & 0xFF0000) >> 16) / 255,
            green: Double((value & 0x00FF00) >> 8) / 255,
            blue: Double(value & 0x0000FF) / 255
        )
    }
}
