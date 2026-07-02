import SwiftUI

// SCA-inspired flavor wheel showing which sections are active for a given set of flavor tags.
struct FlavorWheelView: View {
    var tags: [FlavorTag]
    var size: CGFloat = 240

    private let families: [(name: String, color: Color, subcategories: [String])] = [
        ("Fruity",    Color(hexString: "#E8734A"), ["Berry", "Dried Fruit", "Other Fruit", "Citrus"]),
        ("Sour/Ferm", Color(hexString: "#D4B44A"), ["Sour", "Fermented"]),
        ("Green/Veg", Color(hexString: "#7BAE5A"), ["Olive Oil", "Raw", "Vegetative", "Beany"]),
        ("Other",     Color(hexString: "#8E7BB5"), ["Papery", "Chemical"]),
        ("Roasted",   Color(hexString: "#5C3D2E"), ["Pipe Tobacco", "Tobacco", "Burnt", "Cereal"]),
        ("Spices",    Color(hexString: "#C47B3A"), ["Pungent", "Pepper", "Brown Spice"]),
        ("Nutty/Coc", Color(hexString: "#B8955A"), ["Nutty", "Cocoa"]),
        ("Sweet",     Color(hexString: "#E8A87C"), ["Brown Sugar", "Vanilla", "Vanillin", "Overall Sweet", "Sweet Aromatics"]),
        ("Floral",    Color(hexString: "#E88FAD"), ["Black Tea", "Floral"]),
    ]

    private var activeSubcategories: Set<String> {
        Set(tags.map { $0.subcategory })
    }

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outerR = min(size.width, size.height) / 2 - 4
            let innerR = outerR * 0.35
            let sliceCount = families.reduce(0) { $0 + $1.subcategories.count }
            var startAngle = Angle.degrees(-90.0)

            for family in families {
                let familyAngle = Angle.degrees(360.0 * Double(family.subcategories.count) / Double(sliceCount))
                let familyPath = sectorPath(
                    center: center, innerR: innerR, outerR: (innerR + outerR) / 2,
                    start: startAngle, end: startAngle + familyAngle
                )
                ctx.fill(familyPath, with: .color(family.color))

                var subStart = startAngle
                let subAngle = Angle.degrees(familyAngle.degrees / Double(family.subcategories.count))

                for sub in family.subcategories {
                    let isActive = activeSubcategories.contains(sub)
                    let subPath = sectorPath(
                        center: center,
                        innerR: (innerR + outerR) / 2,
                        outerR: outerR,
                        start: subStart,
                        end: subStart + subAngle
                    )
                    ctx.fill(subPath, with: .color(isActive ? family.color : family.color.opacity(0.18)))
                    if isActive {
                        ctx.stroke(subPath, with: .color(.white.opacity(0.6)), lineWidth: 1.5)
                    }
                    subStart = subStart + subAngle
                }
                startAngle = startAngle + familyAngle
            }

            let centerCircle = Path(ellipseIn: CGRect(
                x: center.x - innerR, y: center.y - innerR,
                width: innerR * 2, height: innerR * 2
            ))
            ctx.fill(centerCircle, with: .color(Color(UIColor.systemBackground)))
        }
        .frame(width: size, height: size)
    }

    private func sectorPath(center: CGPoint, innerR: CGFloat, outerR: CGFloat, start: Angle, end: Angle) -> Path {
        var path = Path()
        path.addArc(center: center, radius: outerR, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: innerR, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}

struct FlavorWheelLegend: View {
    var tags: [FlavorTag]

    private var uniqueFamilies: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in tags {
            if seen.insert(tag.category).inserted {
                result.append(tag.category)
            }
        }
        return result
    }

    var body: some View {
        if !uniqueFamilies.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: BrewTheme.Spacing.xs) {
                    ForEach(uniqueFamilies, id: \.self) { family in
                        BrewChip(title: family, style: .neutral)
                    }
                }
                .padding(.horizontal, BrewTheme.Spacing.sm)
            }
        }
    }
}

private extension Color {
    init(hexString: String) {
        let h = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let n = UInt64(h, radix: 16) ?? 0
        let r = Double((n >> 16) & 0xFF) / 255
        let g = Double((n >> 8) & 0xFF) / 255
        let b = Double(n & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
