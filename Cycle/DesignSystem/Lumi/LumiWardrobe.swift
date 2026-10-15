import SwiftUI

/// Where on Lumi something is worn. One item per slot.
/// On Today the calendar card hides her lower half, so clothes and shoes show only where she's drawn whole.
enum LumiWearSlot: Int, CaseIterable, Comparable, Identifiable, Sendable {
    case hair
    case hat
    case glasses
    case makeup
    case clothes
    case shoes
    case fantasy

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .hair: "Hair"
        case .hat: "Hats"
        case .glasses: "Glasses"
        case .makeup: "Makeup"
        case .clothes: "Clothes"
        case .shoes: "Shoes"
        case .fantasy: "Fantasy"
        }
    }

    var items: [LumiWear] {
        LumiWear.allCases.filter { $0.slot == self }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Something Lumi can wear.
enum LumiWear: String, CaseIterable, Identifiable, Sendable {
    case bangs
    case pigtails
    case bun
    case curls
    case spaceBuns
    case bob
    case flowerCrown
    case crown
    case bow
    case headphones
    case beanie
    case partyHat
    case witchHat
    case sunHat
    case roundGlasses
    case heartGlasses
    case starGlasses
    case sunglasses
    case freckles
    case starCheeks
    case heartCheeks
    case lashes
    case glitter
    case sweater
    case overalls
    case pajamas
    case dress
    case hoodie
    case raincoat
    case tutu
    case sneakers
    case boots
    case bunnySlippers
    case rainBoots
    case balletFlats
    case rollerSkates
    case fairyWings
    case unicornHorn
    case halo
    case catEars
    case starWand

    var id: String { rawValue }

    var slot: LumiWearSlot {
        switch self {
        case .bangs, .pigtails, .bun, .curls, .spaceBuns, .bob: .hair
        case .flowerCrown, .crown, .bow, .headphones, .beanie, .partyHat, .witchHat, .sunHat: .hat
        case .roundGlasses, .heartGlasses, .starGlasses, .sunglasses: .glasses
        case .freckles, .starCheeks, .heartCheeks, .lashes, .glitter: .makeup
        case .sweater, .overalls, .pajamas, .dress, .hoodie, .raincoat, .tutu: .clothes
        case .sneakers, .boots, .bunnySlippers, .rainBoots, .balletFlats, .rollerSkates: .shoes
        case .fairyWings, .unicornHorn, .halo, .catEars, .starWand: .fantasy
        }
    }

    var name: String {
        switch self {
        case .bangs: "Bangs"
        case .pigtails: "Pigtails"
        case .bun: "Top bun"
        case .curls: "Curls"
        case .flowerCrown: "Flower crown"
        case .crown: "Little crown"
        case .bow: "Bow"
        case .headphones: "Headphones"
        case .beanie: "Beanie"
        case .partyHat: "Party hat"
        case .roundGlasses: "Round glasses"
        case .heartGlasses: "Heart glasses"
        case .sweater: "Sweater"
        case .overalls: "Overalls"
        case .pajamas: "Star pajamas"
        case .dress: "Polka-dot dress"
        case .sneakers: "Sneakers"
        case .boots: "Boots"
        case .bunnySlippers: "Bunny slippers"
        case .rainBoots: "Rain boots"
        case .spaceBuns: "Space buns"
        case .bob: "Pastel bob"
        case .witchHat: "Witch hat"
        case .sunHat: "Sun hat"
        case .starGlasses: "Star glasses"
        case .sunglasses: "Sunglasses"
        case .freckles: "Freckles"
        case .starCheeks: "Star cheeks"
        case .heartCheeks: "Heart paint"
        case .lashes: "Lashes"
        case .glitter: "Glitter"
        case .hoodie: "Hoodie"
        case .raincoat: "Raincoat"
        case .tutu: "Tutu"
        case .balletFlats: "Ballet flats"
        case .rollerSkates: "Roller skates"
        case .fairyWings: "Fairy wings"
        case .unicornHorn: "Unicorn horn"
        case .halo: "Halo"
        case .catEars: "Cat ears"
        case .starWand: "Star wand"
        }
    }
}

/// What Lumi is wearing: at most one item per slot. Saved on this iPhone as text like "bow,roundGlasses".
struct LumiOutfit: Equatable, Sendable, RawRepresentable {
    static let storageKey = "lumi.outfit"

    /// Worn items in slot order.
    private(set) var items: [LumiWear]

    init(_ items: [LumiWear] = []) {
        // A later item replaces an earlier one in the same slot.
        var bySlot: [LumiWearSlot: LumiWear] = [:]
        for item in items {
            bySlot[item.slot] = item
        }
        self.items = bySlot.keys.sorted().compactMap { bySlot[$0] }
    }

    init(rawValue: String) {
        self.init(rawValue.split(separator: ",").compactMap { LumiWear(rawValue: String($0)) })
    }

    var rawValue: String {
        items.map(\.rawValue).joined(separator: ",")
    }

    func isWearing(_ item: LumiWear) -> Bool {
        items.contains(item)
    }

    func item(in slot: LumiWearSlot) -> LumiWear? {
        items.first { $0.slot == slot }
    }

    /// Takes the item off if she's wearing it, otherwise puts it on (replacing that slot).
    func toggling(_ item: LumiWear) -> LumiOutfit {
        isWearing(item) ? LumiOutfit(items.filter { $0 != item }) : LumiOutfit(items + [item])
    }
}

// MARK: - Drawing

/// Draws worn items in Lumi's 200×200 design space (eyes at y 110, head top at y 44, leaf at x 102,
/// feet at y 165–187). Shoes and wings go under her body; everything else on top of it.
enum LumiWearArt {
    private static let gold = Color(red: 0.99, green: 0.83, blue: 0.42)
    private static let goldDark = Color(red: 0.90, green: 0.62, blue: 0.24)
    private static let ribbon = Color(red: 0.96, green: 0.52, blue: 0.64)
    private static let ribbonDark = Color(red: 0.84, green: 0.36, blue: 0.50)
    private static let ink = Color(red: 0.23, green: 0.16, blue: 0.24)
    private static let headphoneBody = Color(red: 0.42, green: 0.36, blue: 0.62)
    private static let headphoneCushion = Color(red: 0.98, green: 0.80, blue: 0.86)
    private static let hair = Color(red: 0.42, green: 0.27, blue: 0.36)
    private static let hairLight = Color(red: 0.60, green: 0.41, blue: 0.50)
    private static let star = Color(red: 1.0, green: 0.86, blue: 0.40)
    private static let petals: [Color] = [
        Color(red: 0.99, green: 0.74, blue: 0.82),
        .white,
        Color(red: 0.86, green: 0.80, blue: 0.99),
    ]

    static func draw(_ item: LumiWear, in context: GraphicsContext) {
        switch item {
        case .flowerCrown: flowerCrown(context)
        case .crown: crown(context)
        case .bow: bow(context)
        case .headphones: headphones(context)
        case .roundGlasses: roundGlasses(context)
        case .heartGlasses: heartGlasses(context)
        case .bangs: bangs(context)
        case .pigtails: pigtails(context)
        case .bun: bun(context)
        case .curls: curls(context)
        case .beanie: beanie(context)
        case .partyHat: partyHat(context)
        case .sweater: sweater(context)
        case .overalls: overalls(context)
        case .pajamas: pajamas(context)
        case .dress: dress(context)
        case .sneakers, .boots, .bunnySlippers, .rainBoots, .balletFlats, .rollerSkates: shoes(item, context)
        case .spaceBuns: spaceBuns(context)
        case .bob: bob(context)
        case .witchHat: witchHat(context)
        case .sunHat: sunHat(context)
        case .starGlasses: starGlasses(context)
        case .sunglasses: sunglasses(context)
        case .freckles, .starCheeks, .heartCheeks, .lashes, .glitter: makeup(item, context)
        case .hoodie: hoodie(context)
        case .raincoat: raincoat(context)
        case .tutu: tutu(context)
        case .fairyWings: fairyWings(context)
        case .unicornHorn: unicornHorn(context)
        case .halo: halo(context)
        case .catEars: catEars(context)
        case .starWand: starWand(context)
        }
    }

    /// Items drawn behind her body rather than on top.
    static func isBehind(_ item: LumiWear) -> Bool {
        item == .fairyWings
    }

    /// Clothes with sleeves color her arms too: light and dark shades.
    static func sleeveColors(for item: LumiWear?) -> (Color, Color)? {
        switch item {
        case .sweater: (Color(red: 0.99, green: 0.87, blue: 0.87), Color(red: 0.93, green: 0.70, blue: 0.74))
        case .pajamas: (Color(red: 0.76, green: 0.80, blue: 0.99), Color(red: 0.56, green: 0.60, blue: 0.90))
        case .hoodie: (Color(red: 0.72, green: 0.91, blue: 0.85), Color(red: 0.48, green: 0.76, blue: 0.70))
        case .raincoat: (Color(red: 1, green: 0.88, blue: 0.42), Color(red: 0.95, green: 0.72, blue: 0.24))
        default: nil
        }
    }

    // MARK: Hair

    private static var hairShading: GraphicsContext.Shading {
        .linearGradient(Gradient(colors: [hairLight, hair]), startPoint: CGPoint(x: 100, y: 40), endPoint: CGPoint(x: 100, y: 90))
    }

    private static func bangs(_ context: GraphicsContext) {
        var head = context
        head.clip(to: LumiShape.body)
        var fringe = Path()
        fringe.move(to: CGPoint(x: 30, y: 30))
        fringe.addLine(to: CGPoint(x: 170, y: 30))
        fringe.addLine(to: CGPoint(x: 170, y: 76))
        // Scalloped ends, like a soft fringe.
        for index in 0..<5 {
            let x = 170 - CGFloat(index) * 28
            fringe.addQuadCurve(to: CGPoint(x: x - 28, y: 76), control: CGPoint(x: x - 14, y: 94))
        }
        fringe.closeSubpath()
        head.fill(fringe, with: hairShading)
        var shine = Path()
        shine.move(to: CGPoint(x: 70, y: 58))
        shine.addQuadCurve(to: CGPoint(x: 96, y: 52), control: CGPoint(x: 82, y: 50))
        head.stroke(shine, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    private static func pigtails(_ context: GraphicsContext) {
        for side in [CGFloat(-1), 1] {
            let center = CGPoint(x: 100 + side * 64, y: 74)
            context.fill(Path(ellipseIn: CGRect(x: center.x - 15, y: center.y - 15, width: 30, height: 30)), with: hairShading)
            context.fill(Path(ellipseIn: CGRect(x: center.x - 8 + side * 4, y: center.y - 23, width: 18, height: 18)), with: hairShading)
            // A hair tie where the pigtail meets her head.
            let tie = CGPoint(x: 100 + side * 52, y: 78)
            context.fill(Path(ellipseIn: CGRect(x: tie.x - 5, y: tie.y - 6, width: 10, height: 12)), with: .color(ribbon))
        }
    }

    private static func bun(_ context: GraphicsContext) {
        let center = CGPoint(x: 76, y: 46)
        context.fill(Path(ellipseIn: CGRect(x: center.x - 15, y: center.y - 15, width: 30, height: 30)), with: hairShading)
        var swirl = Path()
        swirl.addArc(center: center, radius: 7, startAngle: .degrees(200), endAngle: .degrees(60), clockwise: false)
        context.stroke(swirl, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        context.fill(Path(roundedRect: CGRect(x: center.x - 12, y: center.y + 10, width: 24, height: 6), cornerRadius: 3), with: .color(ribbon))
    }

    private static func curls(_ context: GraphicsContext) {
        for (index, degrees) in stride(from: -172.0, through: -8, by: 13.6).enumerated() {
            let angle = degrees * .pi / 180
            let center = CGPoint(x: 100 + cos(angle) * 55, y: 100 + sin(angle) * 50)
            let rect = CGRect(x: center.x - 10, y: center.y - 10, width: 20, height: 20)
            context.fill(Path(ellipseIn: rect), with: .color(index.isMultiple(of: 2) ? hair : hairLight))
        }
    }

    // MARK: More hats

    private static func beanie(_ context: GraphicsContext) {
        let knit = Color(red: 0.95, green: 0.58, blue: 0.58)
        let knitDark = Color(red: 0.82, green: 0.40, blue: 0.44)
        var cap = Path()
        cap.move(to: CGPoint(x: 42, y: 90))
        cap.addCurve(to: CGPoint(x: 100, y: 30), control1: CGPoint(x: 40, y: 50), control2: CGPoint(x: 66, y: 30))
        cap.addCurve(to: CGPoint(x: 158, y: 90), control1: CGPoint(x: 134, y: 30), control2: CGPoint(x: 160, y: 50))
        cap.addQuadCurve(to: CGPoint(x: 42, y: 90), control: CGPoint(x: 100, y: 72))
        cap.closeSubpath()
        context.fill(cap, with: .linearGradient(Gradient(colors: [knit, knitDark]), startPoint: CGPoint(x: 100, y: 30), endPoint: CGPoint(x: 100, y: 90)))
        var band = Path()
        band.move(to: CGPoint(x: 44, y: 86))
        band.addQuadCurve(to: CGPoint(x: 156, y: 86), control: CGPoint(x: 100, y: 68))
        context.stroke(band, with: .color(knitDark), style: StrokeStyle(lineWidth: 10, lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: 77, y: 15, width: 22, height: 22)), with: .color(Color(red: 1, green: 0.96, blue: 0.92)))
    }

    private static func partyHat(_ context: GraphicsContext) {
        var hat = context
        hat.translateBy(x: 72, y: 56)
        hat.rotate(by: .degrees(-18))
        var cone = Path()
        cone.move(to: CGPoint(x: -16, y: 8))
        cone.addLine(to: CGPoint(x: 0, y: -34))
        cone.addLine(to: CGPoint(x: 16, y: 8))
        cone.closeSubpath()
        hat.fill(cone, with: .color(Color(red: 0.55, green: 0.84, blue: 0.78)))
        for (x, y, color) in [(CGFloat(-5), CGFloat(-4), ribbon), (5, -14, star), (-1, -24, ribbon), (6, 2, star)] {
            hat.fill(Path(ellipseIn: CGRect(x: x - 2.6, y: y - 2.6, width: 5.2, height: 5.2)), with: .color(color))
        }
        hat.fill(Path(ellipseIn: CGRect(x: -6, y: -42, width: 12, height: 12)), with: .color(ribbon))
    }

    // MARK: Clothes

    /// Fills her body from a curved neckline at `top` down, so clothes follow her round shape.
    private static func garment(_ context: GraphicsContext, top: CGFloat, colors: (Color, Color)) -> GraphicsContext {
        var wear = context
        wear.clip(to: LumiShape.body)
        wear.fill(neckline(top: top, to: 200), with: .linearGradient(
            Gradient(colors: [colors.0, colors.1]),
            startPoint: CGPoint(x: 100, y: top),
            endPoint: CGPoint(x: 100, y: 184)
        ))
        wear.clip(to: neckline(top: top, to: 200))
        return wear
    }

    private static func neckline(top: CGFloat, to bottom: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 20, y: top))
        path.addQuadCurve(to: CGPoint(x: 180, y: top), control: CGPoint(x: 100, y: top + 16))
        path.addLine(to: CGPoint(x: 180, y: bottom))
        path.addLine(to: CGPoint(x: 20, y: bottom))
        path.closeSubpath()
        return path
    }

    private static func sweater(_ context: GraphicsContext) {
        guard let colors = sleeveColors(for: .sweater) else { return }
        let stripe = Color(red: 0.90, green: 0.55, blue: 0.62)
        let wear = garment(context, top: 138, colors: colors)
        for y in [CGFloat(158), 171] {
            wear.fill(Path(CGRect(x: 0, y: y, width: 200, height: 5)), with: .color(stripe))
        }
        var collar = Path()
        collar.move(to: CGPoint(x: 20, y: 140))
        collar.addQuadCurve(to: CGPoint(x: 180, y: 140), control: CGPoint(x: 100, y: 156))
        var clipped = context
        clipped.clip(to: LumiShape.body)
        clipped.stroke(collar, with: .color(stripe), style: StrokeStyle(lineWidth: 5))
    }

    private static func overalls(_ context: GraphicsContext) {
        let denim = (Color(red: 0.50, green: 0.63, blue: 0.86), Color(red: 0.32, green: 0.43, blue: 0.68))
        var wear = context
        wear.clip(to: LumiShape.body)
        let shading = GraphicsContext.Shading.linearGradient(Gradient(colors: [denim.0, denim.1]), startPoint: CGPoint(x: 100, y: 138), endPoint: CGPoint(x: 100, y: 184))
        wear.fill(Path(CGRect(x: 0, y: 154, width: 200, height: 50)), with: shading)
        wear.fill(Path(roundedRect: CGRect(x: 78, y: 140, width: 44, height: 20), cornerRadius: 4), with: shading)
        wear.stroke(Path(roundedRect: CGRect(x: 90, y: 146, width: 20, height: 10), cornerRadius: 2), with: .color(.white.opacity(0.45)), lineWidth: 1.2)
        var straps = Path()
        straps.move(to: CGPoint(x: 82, y: 142))
        straps.addLine(to: CGPoint(x: 50, y: 138))
        straps.move(to: CGPoint(x: 118, y: 142))
        straps.addLine(to: CGPoint(x: 150, y: 138))
        wear.stroke(straps, with: .color(denim.0), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        for x in [CGFloat(83), 117] {
            wear.fill(Path(ellipseIn: CGRect(x: x - 3, y: 141, width: 6, height: 6)), with: .color(star))
        }
    }

    private static func pajamas(_ context: GraphicsContext) {
        guard let colors = sleeveColors(for: .pajamas) else { return }
        let wear = garment(context, top: 136, colors: colors)
        for (x, y) in [(CGFloat(66), CGFloat(156)), (100, 166), (134, 154), (84, 176), (118, 178), (50, 172), (150, 170)] {
            wear.fill(starPath(center: CGPoint(x: x, y: y), radius: 5), with: .color(star))
        }
    }

    private static func dress(_ context: GraphicsContext) {
        let pink = (Color(red: 0.99, green: 0.74, blue: 0.82), Color(red: 0.92, green: 0.52, blue: 0.64))
        let wear = garment(context, top: 138, colors: pink)
        for row in 0..<3 {
            for column in 0..<7 {
                let x = 34 + CGFloat(column) * 22 + (row.isMultiple(of: 2) ? 0 : 11)
                let y = 154 + CGFloat(row) * 12
                wear.fill(Path(ellipseIn: CGRect(x: x - 2.6, y: y - 2.6, width: 5.2, height: 5.2)), with: .color(.white.opacity(0.85)))
            }
        }
        var clipped = context
        clipped.clip(to: LumiShape.body)
        for side in [CGFloat(-1), 1] {
            let flap = Path(ellipseIn: CGRect(x: 100 + side * 13 - 12, y: 141, width: 24, height: 11))
            clipped.fill(flap, with: .color(.white))
        }
    }

    private static func starPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        for point in 0..<10 {
            let angle = Double(point) * .pi / 5 - .pi / 2
            let length = point.isMultiple(of: 2) ? radius : radius * 0.45
            let spot = CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length)
            if point == 0 { path.move(to: spot) } else { path.addLine(to: spot) }
        }
        path.closeSubpath()
        return path
    }

    // MARK: Shoes

    private static func shoes(_ item: LumiWear, _ context: GraphicsContext) {
        for (index, bareFoot) in LumiShape.feet.enumerated() {
            let outward: CGFloat = index == 0 ? -1 : 1
            // A bit bigger and lower than her foot, so more of the shoe peeks out under her body.
            let foot = bareFoot.insetBy(dx: -3, dy: -2).offsetBy(dx: 0, dy: 2)
            let shoe = Path(ellipseIn: foot)
            switch item {
            case .sneakers:
                context.fill(shoe, with: .color(Color(red: 0.99, green: 0.99, blue: 1)))
                context.stroke(shoe, with: .color(Color(red: 0.78, green: 0.76, blue: 0.86)), lineWidth: 1.5)
                var stripe = Path()
                stripe.move(to: CGPoint(x: foot.minX + 8, y: foot.maxY - 6))
                stripe.addQuadCurve(to: CGPoint(x: foot.maxX - 8, y: foot.maxY - 8), control: CGPoint(x: foot.midX, y: foot.maxY - 2))
                context.stroke(stripe, with: .color(Color(red: 0.45, green: 0.78, blue: 0.72)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            case .boots:
                context.fill(shoe, with: .linearGradient(
                    Gradient(colors: [Color(red: 0.66, green: 0.46, blue: 0.33), Color(red: 0.47, green: 0.31, blue: 0.22)]),
                    startPoint: CGPoint(x: foot.midX, y: foot.minY),
                    endPoint: CGPoint(x: foot.midX, y: foot.maxY)
                ))
            case .bunnySlippers:
                let fluff = Color(red: 1, green: 0.86, blue: 0.91)
                var ear = context
                ear.translateBy(x: outward < 0 ? foot.minX + 2 : foot.maxX - 2, y: foot.midY + 2)
                ear.rotate(by: .degrees(Double(outward) * 62))
                ear.fill(Path(ellipseIn: CGRect(x: -4.5, y: -18, width: 9, height: 18)), with: .color(fluff))
                ear.fill(Path(ellipseIn: CGRect(x: -2, y: -15, width: 4, height: 11)), with: .color(ribbon.opacity(0.6)))
                context.fill(shoe, with: .color(fluff))
                for dx in [CGFloat(-5), 5] {
                    context.fill(Path(ellipseIn: CGRect(x: foot.midX + dx - 1.5, y: foot.maxY - 6, width: 3, height: 3)), with: .color(ink))
                }
            case .rainBoots:
                context.fill(shoe, with: .linearGradient(
                    Gradient(colors: [Color(red: 1, green: 0.88, blue: 0.40), Color(red: 0.95, green: 0.70, blue: 0.20)]),
                    startPoint: CGPoint(x: foot.midX, y: foot.minY),
                    endPoint: CGPoint(x: foot.midX, y: foot.maxY)
                ))
                context.fill(Path(ellipseIn: CGRect(x: foot.minX + 6, y: foot.maxY - 9, width: 9, height: 4)), with: .color(.white.opacity(0.6)))
            case .balletFlats:
                context.fill(shoe, with: .linearGradient(
                    Gradient(colors: [Color(red: 1, green: 0.82, blue: 0.88), Color(red: 0.95, green: 0.62, blue: 0.72)]),
                    startPoint: CGPoint(x: foot.midX, y: foot.minY),
                    endPoint: CGPoint(x: foot.midX, y: foot.maxY)
                ))
                var ribbonCross = Path()
                ribbonCross.move(to: CGPoint(x: foot.midX - 5, y: foot.maxY - 9))
                ribbonCross.addLine(to: CGPoint(x: foot.midX + 5, y: foot.maxY - 3))
                ribbonCross.move(to: CGPoint(x: foot.midX + 5, y: foot.maxY - 9))
                ribbonCross.addLine(to: CGPoint(x: foot.midX - 5, y: foot.maxY - 3))
                context.stroke(ribbonCross, with: .color(ribbonDark), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            case .rollerSkates:
                context.fill(shoe, with: .color(Color(red: 1, green: 0.95, blue: 0.97)))
                context.stroke(shoe, with: .color(ribbon), lineWidth: 1.5)
                for x in [foot.minX + 9, foot.maxX - 9] {
                    let wheel = CGRect(x: x - 4.5, y: foot.maxY - 2, width: 9, height: 9)
                    context.fill(Path(ellipseIn: wheel), with: .color(Color(red: 0.45, green: 0.80, blue: 0.74)))
                    context.fill(Path(ellipseIn: wheel.insetBy(dx: 3, dy: 3)), with: .color(.white))
                }
            default:
                break
            }
        }
    }

    // MARK: Head

    private static func flowerCrown(_ context: GraphicsContext) {
        // Along the curve of her head, leaving a gap at the top for the leaf.
        let angles: [Double] = [-162, -140, -118, -62, -40, -18]
        for (index, degrees) in angles.enumerated() {
            let angle = degrees * .pi / 180
            let center = CGPoint(x: 100 + cos(angle) * 56, y: 100 + sin(angle) * 48)
            flower(context, at: center, color: petals[index % petals.count])
        }
    }

    private static func flower(_ context: GraphicsContext, at center: CGPoint, color: Color) {
        for petal in 0..<5 {
            let angle = Double(petal) * 2 * .pi / 5
            let spot = CGPoint(x: center.x + cos(angle) * 4.6, y: center.y + sin(angle) * 4.6)
            let rect = CGRect(x: spot.x - 4.4, y: spot.y - 4.4, width: 8.8, height: 8.8)
            context.fill(Path(ellipseIn: rect), with: .color(color))
            context.stroke(Path(ellipseIn: rect), with: .color(ribbonDark.opacity(0.25)), lineWidth: 0.6)
        }
        context.fill(Path(ellipseIn: CGRect(x: center.x - 3, y: center.y - 3, width: 6, height: 6)), with: .color(gold))
    }

    private static func crown(_ context: GraphicsContext) {
        var crown = context
        crown.translateBy(x: 70, y: 60)
        crown.rotate(by: .degrees(-20))
        var shape = Path()
        shape.move(to: CGPoint(x: -17, y: 6))
        shape.addLine(to: CGPoint(x: -19, y: -12))
        shape.addLine(to: CGPoint(x: -9, y: -3))
        shape.addLine(to: CGPoint(x: 0, y: -17))
        shape.addLine(to: CGPoint(x: 9, y: -3))
        shape.addLine(to: CGPoint(x: 19, y: -12))
        shape.addLine(to: CGPoint(x: 17, y: 6))
        shape.closeSubpath()
        crown.fill(shape, with: .linearGradient(Gradient(colors: [gold, goldDark]), startPoint: CGPoint(x: 0, y: -17), endPoint: CGPoint(x: 0, y: 6)))
        crown.stroke(shape, with: .color(goldDark), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
        for x in [CGFloat(-9), 0, 9] {
            crown.fill(Path(ellipseIn: CGRect(x: x - 2.4, y: -1.5, width: 4.8, height: 4.8)), with: .color(ribbon))
        }
    }

    private static func bow(_ context: GraphicsContext) {
        var bow = context
        bow.translateBy(x: 136, y: 60)
        bow.rotate(by: .degrees(24))
        for side in [CGFloat(-1), 1] {
            var loop = Path()
            loop.move(to: .zero)
            loop.addCurve(to: CGPoint(x: 20 * side, y: -11), control1: CGPoint(x: 6 * side, y: -14), control2: CGPoint(x: 14 * side, y: -18))
            loop.addCurve(to: .zero, control1: CGPoint(x: 26 * side, y: 2), control2: CGPoint(x: 10 * side, y: 10))
            loop.closeSubpath()
            bow.fill(loop, with: .linearGradient(Gradient(colors: [ribbon, ribbonDark]), startPoint: CGPoint(x: 0, y: -12), endPoint: CGPoint(x: 0, y: 8)))
            bow.stroke(loop, with: .color(ribbonDark), lineWidth: 1)
        }
        bow.fill(Path(ellipseIn: CGRect(x: -5, y: -5, width: 10, height: 10)), with: .color(ribbonDark))
    }

    private static func headphones(_ context: GraphicsContext) {
        var band = Path()
        band.addArc(center: CGPoint(x: 100, y: 108), radius: 66, startAngle: .degrees(196), endAngle: .degrees(344), clockwise: false)
        context.stroke(band, with: .color(headphoneBody), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        for x in [CGFloat(28), 152] {
            let cup = Path(roundedRect: CGRect(x: x, y: 88, width: 20, height: 34), cornerRadius: 9)
            context.fill(cup, with: .color(headphoneBody))
            let cushion = Path(roundedRect: CGRect(x: x == 28 ? x + 13 : x - 3, y: 92, width: 10, height: 26), cornerRadius: 5)
            context.fill(cushion, with: .color(headphoneCushion))
        }
    }

    // MARK: Face

    private static let leftEye = CGPoint(x: 76, y: 110)
    private static let rightEye = CGPoint(x: 124, y: 110)

    private static func roundGlasses(_ context: GraphicsContext) {
        let line = StrokeStyle(lineWidth: 2.8, lineCap: .round)
        for eye in [leftEye, rightEye] {
            let lens = Path(ellipseIn: CGRect(x: eye.x - 17, y: eye.y - 16, width: 34, height: 32))
            context.fill(lens, with: .color(.white.opacity(0.18)))
            context.stroke(lens, with: .color(ink), style: line)
        }
        var frame = Path()
        frame.move(to: CGPoint(x: 93, y: 108))
        frame.addQuadCurve(to: CGPoint(x: 107, y: 108), control: CGPoint(x: 100, y: 102))
        frame.move(to: CGPoint(x: 59, y: 106))
        frame.addLine(to: CGPoint(x: 42, y: 102))
        frame.move(to: CGPoint(x: 141, y: 106))
        frame.addLine(to: CGPoint(x: 158, y: 102))
        context.stroke(frame, with: .color(ink), style: line)
    }

    private static func heartGlasses(_ context: GraphicsContext) {
        for eye in [leftEye, rightEye] {
            let heart = Path.lumiHeart(in: CGRect(x: eye.x - 19, y: eye.y - 17, width: 38, height: 34))
            context.fill(heart, with: .color(ribbon.opacity(0.45)))
            context.stroke(heart, with: .color(ribbonDark), style: StrokeStyle(lineWidth: 2.6, lineJoin: .round))
        }
        var frame = Path()
        frame.move(to: CGPoint(x: 94, y: 104))
        frame.addLine(to: CGPoint(x: 106, y: 104))
        frame.move(to: CGPoint(x: 57, y: 102))
        frame.addLine(to: CGPoint(x: 42, y: 99))
        frame.move(to: CGPoint(x: 143, y: 102))
        frame.addLine(to: CGPoint(x: 158, y: 99))
        context.stroke(frame, with: .color(ribbonDark), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
    }

    // MARK: More hair

    private static func spaceBuns(_ context: GraphicsContext) {
        for x in [CGFloat(64), 136] {
            let center = CGPoint(x: x, y: 52)
            context.fill(Path(ellipseIn: CGRect(x: center.x - 14, y: center.y - 14, width: 28, height: 28)), with: hairShading)
            var swirl = Path()
            swirl.addArc(center: center, radius: 6, startAngle: .degrees(200), endAngle: .degrees(60), clockwise: false)
            context.stroke(swirl, with: .color(.white.opacity(0.3)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    private static func bob(_ context: GraphicsContext) {
        let pastel = Color(red: 1, green: 0.80, blue: 0.88)
        let pastelDark = Color(red: 0.92, green: 0.60, blue: 0.75)
        // A little fuller than her head, so the hair puffs out.
        let puff = CGAffineTransform(translationX: 100, y: 113).scaledBy(x: 1.07, y: 1.05).translatedBy(x: -100, y: -113)
        var hair = context
        hair.clip(to: LumiShape.body.applying(puff))
        // Her whole head down to the chin, with a soft rounded opening for her face.
        hair.clip(to: Path(CGRect(x: 0, y: 0, width: 200, height: 130)))
        var shape = Path(CGRect(x: 0, y: 0, width: 200, height: 200))
        shape.addRoundedRect(in: CGRect(x: 56, y: 80, width: 88, height: 140), cornerSize: CGSize(width: 30, height: 30))
        hair.fill(
            shape,
            with: .linearGradient(Gradient(colors: [pastel, pastelDark]), startPoint: CGPoint(x: 100, y: 36), endPoint: CGPoint(x: 100, y: 130)),
            style: FillStyle(eoFill: true)
        )
        var shine = Path()
        shine.move(to: CGPoint(x: 66, y: 60))
        shine.addQuadCurve(to: CGPoint(x: 96, y: 52), control: CGPoint(x: 80, y: 50))
        hair.stroke(shine, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    // MARK: Even more hats

    private static func witchHat(_ context: GraphicsContext) {
        let purple = Color(red: 0.46, green: 0.34, blue: 0.66)
        let purpleDark = Color(red: 0.30, green: 0.20, blue: 0.48)
        context.fill(Path(ellipseIn: CGRect(x: 40, y: 54, width: 120, height: 22)), with: .color(purpleDark))
        var cone = Path()
        cone.move(to: CGPoint(x: 70, y: 64))
        cone.addQuadCurve(to: CGPoint(x: 116, y: 4), control: CGPoint(x: 86, y: 18))
        cone.addQuadCurve(to: CGPoint(x: 130, y: 64), control: CGPoint(x: 118, y: 30))
        cone.closeSubpath()
        context.fill(cone, with: .linearGradient(Gradient(colors: [purple, purpleDark]), startPoint: CGPoint(x: 100, y: 4), endPoint: CGPoint(x: 100, y: 64)))
        var band = context
        band.clip(to: cone)
        band.fill(Path(CGRect(x: 60, y: 50, width: 80, height: 9)), with: .color(gold))
        context.fill(starPath(center: CGPoint(x: 104, y: 34), radius: 6), with: .color(star))
    }

    private static func sunHat(_ context: GraphicsContext) {
        let straw = Color(red: 0.99, green: 0.89, blue: 0.64)
        let strawDark = Color(red: 0.90, green: 0.74, blue: 0.44)
        context.fill(Path(ellipseIn: CGRect(x: 26, y: 50, width: 148, height: 30)), with: .linearGradient(
            Gradient(colors: [straw, strawDark]), startPoint: CGPoint(x: 100, y: 50), endPoint: CGPoint(x: 100, y: 80)
        ))
        let crown = Path(ellipseIn: CGRect(x: 70, y: 26, width: 60, height: 42))
        context.fill(crown, with: .linearGradient(Gradient(colors: [straw, strawDark]), startPoint: CGPoint(x: 100, y: 26), endPoint: CGPoint(x: 100, y: 68)))
        var band = context
        band.clip(to: crown)
        band.fill(Path(CGRect(x: 60, y: 52, width: 80, height: 9)), with: .color(ribbon))
        flower(context, at: CGPoint(x: 126, y: 56), color: .white)
    }

    // MARK: More glasses

    private static func starGlasses(_ context: GraphicsContext) {
        for eye in [leftEye, rightEye] {
            let frame = starPath(center: eye, radius: 20)
            context.fill(frame, with: .color(gold.opacity(0.35)))
            context.stroke(frame, with: .color(goldDark), style: StrokeStyle(lineWidth: 2.4, lineJoin: .round))
        }
        var bridge = Path()
        bridge.move(to: CGPoint(x: 93, y: 106))
        bridge.addLine(to: CGPoint(x: 107, y: 106))
        context.stroke(bridge, with: .color(goldDark), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
    }

    private static func sunglasses(_ context: GraphicsContext) {
        for eye in [leftEye, rightEye] {
            let lens = Path(roundedRect: CGRect(x: eye.x - 18, y: eye.y - 13, width: 36, height: 26), cornerRadius: 10)
            context.fill(lens, with: .linearGradient(
                Gradient(colors: [Color(red: 0.30, green: 0.24, blue: 0.40), ink]),
                startPoint: CGPoint(x: eye.x, y: eye.y - 13),
                endPoint: CGPoint(x: eye.x, y: eye.y + 13)
            ))
            var shine = Path()
            shine.move(to: CGPoint(x: eye.x - 10, y: eye.y - 6))
            shine.addLine(to: CGPoint(x: eye.x - 3, y: eye.y - 8))
            context.stroke(shine, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
        var frame = Path()
        frame.move(to: CGPoint(x: 94, y: 105))
        frame.addLine(to: CGPoint(x: 106, y: 105))
        frame.move(to: CGPoint(x: 58, y: 104))
        frame.addLine(to: CGPoint(x: 42, y: 100))
        frame.move(to: CGPoint(x: 142, y: 104))
        frame.addLine(to: CGPoint(x: 158, y: 100))
        context.stroke(frame, with: .color(ink), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
    }

    // MARK: Makeup

    private static let cheeks = [CGPoint(x: 58, y: 127), CGPoint(x: 142, y: 127)]

    private static func makeup(_ item: LumiWear, _ context: GraphicsContext) {
        switch item {
        case .freckles:
            let spots: [(CGFloat, CGFloat)] = [(-7, -3), (0, -5), (7, -2), (-3, 3), (4, 4)]
            for cheek in cheeks {
                for (dx, dy) in spots {
                    context.fill(Path(ellipseIn: CGRect(x: cheek.x + dx - 1.4, y: cheek.y + dy - 1.4, width: 2.8, height: 2.8)),
                                 with: .color(Color(red: 0.62, green: 0.40, blue: 0.42).opacity(0.75)))
                }
            }
        case .starCheeks:
            for cheek in cheeks {
                let shape = starPath(center: cheek, radius: 7)
                context.fill(shape, with: .color(star))
                context.stroke(shape, with: .color(goldDark), lineWidth: 0.8)
            }
        case .heartCheeks:
            for cheek in cheeks {
                context.fill(Path.lumiHeart(in: CGRect(x: cheek.x - 7, y: cheek.y - 6, width: 14, height: 13)), with: .color(ribbon))
            }
        case .lashes:
            var lashes = Path()
            for (eye, outward) in [(leftEye, CGFloat(-1)), (rightEye, CGFloat(1))] {
                for (index, along) in [CGFloat(4), 8, 11].enumerated() {
                    let base = CGPoint(x: eye.x + outward * along, y: eye.y - 13 + CGFloat(index) * 2.5)
                    lashes.move(to: base)
                    lashes.addLine(to: CGPoint(x: base.x + outward * 5, y: base.y - 5))
                }
            }
            context.stroke(lashes, with: .color(ink), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        case .glitter:
            let sparkles: [(CGFloat, CGFloat, CGFloat, Bool)] = [(56, 98, 4.5, true), (52, 110, 3, false), (62, 90, 2.5, false),
                                                                 (144, 98, 4.5, true), (148, 110, 3, false), (138, 90, 2.5, false)]
            for (x, y, radius, isGold) in sparkles {
                context.fill(FantasySparkle.path(center: CGPoint(x: x, y: y), radius: radius), with: .color(isGold ? star : ribbon))
            }
        default:
            break
        }
    }

    // MARK: More clothes

    private static func hoodie(_ context: GraphicsContext) {
        guard let colors = sleeveColors(for: .hoodie) else { return }
        let wear = garment(context, top: 134, colors: colors)
        wear.stroke(Path(roundedRect: CGRect(x: 74, y: 160, width: 52, height: 15), cornerRadius: 6), with: .color(colors.1), lineWidth: 1.8)
        var hood = context
        hood.clip(to: LumiShape.body)
        var edge = Path()
        edge.move(to: CGPoint(x: 20, y: 136))
        edge.addQuadCurve(to: CGPoint(x: 180, y: 136), control: CGPoint(x: 100, y: 152))
        hood.stroke(edge, with: .color(colors.1), style: StrokeStyle(lineWidth: 6))
        for x in [CGFloat(92), 108] {
            var string = Path()
            string.move(to: CGPoint(x: x, y: 143))
            string.addLine(to: CGPoint(x: x + (x < 100 ? -2 : 2), y: 157))
            hood.stroke(string, with: .color(.white), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            hood.fill(Path(ellipseIn: CGRect(x: x + (x < 100 ? -2 : 2) - 2.5, y: 156, width: 5, height: 5)), with: .color(.white))
        }
    }

    private static func raincoat(_ context: GraphicsContext) {
        guard let colors = sleeveColors(for: .raincoat) else { return }
        let wear = garment(context, top: 136, colors: colors)
        var seam = Path()
        seam.move(to: CGPoint(x: 100, y: 146))
        seam.addLine(to: CGPoint(x: 100, y: 190))
        wear.stroke(seam, with: .color(colors.1), lineWidth: 1.5)
        for y in [CGFloat(152), 164, 176] {
            wear.fill(Path(ellipseIn: CGRect(x: 103, y: y - 3, width: 6, height: 6)), with: .color(ink.opacity(0.8)))
        }
    }

    private static func tutu(_ context: GraphicsContext) {
        let leotard = (Color(red: 0.99, green: 0.82, blue: 0.89), Color(red: 0.96, green: 0.66, blue: 0.78))
        _ = garment(context, top: 140, colors: leotard)
        // The tulle flares out past her sides.
        for x in stride(from: CGFloat(42), through: 158, by: 13) {
            let puff = Path(ellipseIn: CGRect(x: x - 14, y: 156, width: 28, height: 20))
            context.fill(puff, with: .color(Color(red: 1, green: 0.88, blue: 0.93).opacity(0.92)))
            context.stroke(puff, with: .color(leotard.1.opacity(0.6)), lineWidth: 1)
        }
    }

    // MARK: Fantasy

    private static func fairyWings(_ context: GraphicsContext) {
        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [.white.opacity(0.85), Color(red: 0.80, green: 0.74, blue: 0.99).opacity(0.75)]),
            startPoint: CGPoint(x: 100, y: 60),
            endPoint: CGPoint(x: 100, y: 160)
        )
        for side in [CGFloat(-1), 1] {
            for (center, size, angle) in [(CGPoint(x: 100 + side * 66, y: 92), CGSize(width: 46, height: 66), side * 28),
                                          (CGPoint(x: 100 + side * 64, y: 140), CGSize(width: 34, height: 42), side * -24)] {
                var wing = context
                wing.translateBy(x: center.x, y: center.y)
                wing.rotate(by: .degrees(Double(angle)))
                let shape = Path(ellipseIn: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
                wing.fill(shape, with: shading)
                wing.stroke(shape, with: .color(Color(red: 0.66, green: 0.58, blue: 0.92)), lineWidth: 1.4)
            }
        }
    }

    private static func unicornHorn(_ context: GraphicsContext) {
        var horn = context
        horn.translateBy(x: 82, y: 50)
        horn.rotate(by: .degrees(-14))
        var cone = Path()
        cone.move(to: CGPoint(x: -8, y: 4))
        cone.addLine(to: CGPoint(x: 0, y: -36))
        cone.addLine(to: CGPoint(x: 8, y: 4))
        cone.closeSubpath()
        horn.fill(cone, with: .linearGradient(Gradient(colors: [gold, goldDark]), startPoint: CGPoint(x: 0, y: -36), endPoint: CGPoint(x: 0, y: 4)))
        var spiral = Path()
        for y in [CGFloat(-6), -16, -26] {
            let half = 8 * (y + 36) / 40
            spiral.move(to: CGPoint(x: -half, y: y + 3))
            spiral.addLine(to: CGPoint(x: half, y: y - 2))
        }
        horn.stroke(spiral, with: .color(.white.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }

    private static func halo(_ context: GraphicsContext) {
        let ring = Path(ellipseIn: CGRect(x: 64, y: 14, width: 72, height: 16))
        var glow = context
        glow.addFilter(.blur(radius: 3))
        glow.stroke(ring, with: .color(gold.opacity(0.8)), lineWidth: 7)
        context.stroke(ring, with: .color(gold), lineWidth: 3.5)
    }

    private static func catEars(_ context: GraphicsContext) {
        let band = headphoneBody
        for side in [CGFloat(-1), 1] {
            var ear = Path()
            ear.move(to: CGPoint(x: 100 + side * 48, y: 74))
            ear.addLine(to: CGPoint(x: 100 + side * 44, y: 34))
            ear.addLine(to: CGPoint(x: 100 + side * 16, y: 54))
            ear.closeSubpath()
            context.fill(ear, with: .color(band))
            var inner = Path()
            inner.move(to: CGPoint(x: 100 + side * 42, y: 64))
            inner.addLine(to: CGPoint(x: 100 + side * 41, y: 44))
            inner.addLine(to: CGPoint(x: 100 + side * 26, y: 55))
            inner.closeSubpath()
            context.fill(inner, with: .color(headphoneCushion))
        }
    }

    private static func starWand(_ context: GraphicsContext) {
        var stick = Path()
        stick.move(to: CGPoint(x: 168, y: 150))
        stick.addLine(to: CGPoint(x: 182, y: 108))
        context.stroke(stick, with: .color(goldDark), style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
        let tip = starPath(center: CGPoint(x: 184, y: 100), radius: 12)
        context.fill(tip, with: .color(star))
        context.stroke(tip, with: .color(goldDark), lineWidth: 1)
        context.fill(FantasySparkle.path(center: CGPoint(x: 168, y: 86), radius: 4), with: .color(ribbon))
        context.fill(FantasySparkle.path(center: CGPoint(x: 196, y: 120), radius: 3), with: .color(star))
    }
}

extension Path {
    /// A plump heart filling `rect`.
    static func lumiHeart(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }
        var path = Path()
        path.move(to: point(0.5, 0.95))
        path.addCurve(to: point(0, 0.35), control1: point(0.15, 0.78), control2: point(0, 0.58))
        path.addCurve(to: point(0.5, 0.22), control1: point(0, 0.05), control2: point(0.42, 0))
        path.addCurve(to: point(1, 0.35), control1: point(0.58, 0), control2: point(1, 0.05))
        path.addCurve(to: point(0.5, 0.95), control1: point(1, 0.58), control2: point(0.85, 0.78))
        path.closeSubpath()
        return path
    }
}
