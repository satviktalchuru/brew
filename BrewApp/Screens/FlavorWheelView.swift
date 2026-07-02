import SwiftUI

struct FlavorWheelView: View {
    var tags: [FlavorTag]
    var size: CGFloat = 240

    @State private var selectedFamily: FamilyInfo? = nil

    struct FamilyInfo: Equatable {
        var name: String
        var color: Color
        var description: String
        var activeSubs: [String]
        var pct: Int
    }

    private let families: [(name: String, color: Color, subcategories: [String], description: String)] = [
        ("Fruity",    Color(hexString: "#E8734A"), ["Berry", "Dried Fruit", "Other Fruit", "Citrus"],
         "Bright fruit notes — berries, stone fruit, citrus, tropical"),
        ("Sour/Ferm", Color(hexString: "#D4B44A"), ["Sour", "Fermented"],
         "Tangy or fermented character — wine-like, vinegar, sour"),
        ("Green/Veg", Color(hexString: "#7BAE5A"), ["Olive Oil", "Raw", "Vegetative", "Beany"],
         "Fresh or grassy notes — herb, raw, beany, olive-like"),
        ("Other",     Color(hexString: "#8E7BB5"), ["Papery", "Chemical"],
         "Off-notes — papery, rubbery, chemical, musty"),
        ("Roasted",   Color(hexString: "#5C3D2E"), ["Pipe Tobacco", "Tobacco", "Burnt", "Cereal"],
         "Dark, smoky warmth — tobacco, burnt sugar, ashy, cereal"),
        ("Spices",    Color(hexString: "#C47B3A"), ["Pungent", "Pepper", "Brown Spice"],
         "Warming spice — pepper, clove, cinnamon, cardamom"),
        ("Nutty/Coc", Color(hexString: "#B8955A"), ["Nutty", "Cocoa"],
         "Nutty or chocolaty richness — almond, hazelnut, cocoa"),
        ("Sweet",     Color(hexString: "#E8A87C"), ["Brown Sugar", "Vanilla", "Vanillin", "Overall Sweet", "Sweet Aromatics"],
         "Sweet, dessert-like character — caramel, vanilla, brown sugar"),
        ("Floral",    Color(hexString: "#E88FAD"), ["Black Tea", "Floral"],
         "Delicate floral or tea-like notes — jasmine, rose, black tea"),
    ]

    private var activeSubcategories: Set<String> {
        Set(tags.map { $0.subcategory })
    }

    private var totalActiveSubs: Int {
        families.reduce(0) { $0 + $1.subcategories.filter { activeSubcategories.contains($0) }.count }
    }

    private func makeFamilyInfo(for family: (name: String, color: Color, subcategories: [String], description: String)) -> FamilyInfo {
        let active = family.subcategories.filter { activeSubcategories.contains($0) }
        let pct = totalActiveSubs > 0 ? Int(Double(active.count) / Double(totalActiveSubs) * 100) : 0
        return FamilyInfo(name: family.name, color: family.color, description: family.description, activeSubs: active, pct: pct)
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Canvas { ctx, canvasSize in
                    let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                    let outerR = min(canvasSize.width, canvasSize.height) / 2 - 4
                    let innerR = outerR * 0.35
                    let midR = (innerR + outerR) / 2
                    let sliceCount = families.reduce(0) { $0 + $1.subcategories.count }
                    var startAngle = Angle.degrees(-90.0)

                    for family in families {
                        let familyAngle = Angle.degrees(360.0 * Double(family.subcategories.count) / Double(sliceCount))
                        let isSelected = selectedFamily?.name == family.name
                        let dimmed = selectedFamily != nil && !isSelected

                        let familyPath = sectorPath(
                            center: center, innerR: innerR, outerR: midR,
                            start: startAngle, end: startAngle + familyAngle
                        )
                        ctx.fill(familyPath, with: .color(family.color.opacity(dimmed ? 0.4 : 1)))

                        var subStart = startAngle
                        let subAngle = Angle.degrees(familyAngle.degrees / Double(family.subcategories.count))

                        for sub in family.subcategories {
                            let isActive = activeSubcategories.contains(sub)
                            let subOuterR = isSelected ? outerR + 6 : outerR
                            let subPath = sectorPath(
                                center: center,
                                innerR: midR,
                                outerR: subOuterR,
                                start: subStart,
                                end: subStart + subAngle
                            )
                            let opacity: Double = isActive ? (dimmed ? 0.35 : 1) : (dimmed ? 0.08 : 0.18)
                            ctx.fill(subPath, with: .color(family.color.opacity(opacity)))
                            if isActive && !dimmed {
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
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            let tappedName = familyName(at: value.location, canvasSize: size)
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                if let name = tappedName, let f = families.first(where: { $0.name == name }) {
                                    let info = makeFamilyInfo(for: f)
                                    selectedFamily = selectedFamily?.name == name ? nil : info
                                } else {
                                    selectedFamily = nil
                                }
                            }
                        }
                )

                if selectedFamily == nil && activeSubcategories.isEmpty {
                    Text("Tap a\nsegment")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .frame(width: size * 0.28)
                        .allowsHitTesting(false)
                }
            }

            if let sel = selectedFamily {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(sel.color)
                        .frame(width: 4, height: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(sel.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.primary)
                            Spacer()
                            if sel.pct > 0 {
                                Text("\(sel.pct)%")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(sel.color)
                            }
                        }
                        Text(sel.description)
                            .font(.system(size: 11))
                            .foregroundStyle(Color.secondary)
                            .lineLimit(2)
                        if !sel.activeSubs.isEmpty {
                            Text(sel.activeSubs.joined(separator: " · "))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(sel.color)
                        }
                    }
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    private func familyName(at point: CGPoint, canvasSize: CGFloat) -> String? {
        let center = CGPoint(x: canvasSize / 2, y: canvasSize / 2)
        let outerR = canvasSize / 2 - 4
        let innerR = outerR * 0.35
        let dx = point.x - center.x
        let dy = point.y - center.y
        let radius = sqrt(dx * dx + dy * dy)
        guard radius >= innerR && radius <= outerR + 8 else { return nil }
        var angle = atan2(dy, dx) * 180 / .pi + 90
        if angle < 0 { angle += 360 }
        let sliceCount = Double(families.reduce(0) { $0 + $1.subcategories.count })
        var cursor = 0.0
        for family in families {
            let span = 360.0 * Double(family.subcategories.count) / sliceCount
            if angle >= cursor && angle < cursor + span { return family.name }
            cursor += span
        }
        return nil
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
