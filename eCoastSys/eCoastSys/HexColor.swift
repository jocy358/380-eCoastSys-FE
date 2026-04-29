//
//  HexColor.swift
//  eCoastSys
//
//

import Foundation
import SwiftUI

extension Color {
    static let ecBackground = Color(hex: "#A4DDD7")
    static let ecPrimary = Color(hex: "#3A716C")
    static let ecSecondary = Color(hex: "#53989D")
    static let ecLavender = Color(hex: "#D1CDDC")
    static let ecTan = Color(hex: "#D4B296")

    static let ecText = Color(hex: "#1F1F1F")
    static let ecSecondaryText = Color(hex: "#6B7280")
    static let ecMuted = Color(hex: "#8BA5A1")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (
                255,
                (int >> 8) * 17,
                (int >> 4 & 0xF) * 17,
                (int & 0xF) * 17
            )
        case 6:
            (a, r, g, b) = (
                255,
                int >> 16,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        case 8:
            (a, r, g, b) = (
                int >> 24,
                int >> 16 & 0xFF,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
