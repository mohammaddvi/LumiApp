import SwiftUI

/// Lumi, the app's companion. Shows today's feeling (or the cycle phase when none is logged),
/// and breathes, blinks and sways unless Reduce Motion is on.
struct LumiView: View {
    var feeling: Feeling?
    var phase: LunePhase?
    var size: CGFloat = 200
    /// Off for small, static uses such as the feeling buttons.
    var animated = true
    /// Hides the side arms; `lumiHolding` draws hands on the held card's edge instead.
    var holding = false
    /// Mouth flaps open and closed while a speech bubble is typing.
    var talking = false
    /// A playful face from being tapped or petted; shows over the feeling's face.
    var play: LumiPlay?
    /// Bump to make Lumi hop.
    var hops = 0
    /// Bump to make Lumi wiggle side to side.
    var wiggles = 0
    /// What she wears; nil uses the outfit picked in her room.
    var outfit: LumiOutfit?

    @AppStorage(LumiOutfit.storageKey) private var savedOutfit = LumiOutfit()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isMoving: Bool { animated && !reduceMotion }

    private var palette: LumiPalette {
        .resolve(feeling: feeling, phase: phase)
    }

    var body: some View {
        Group {
            if isMoving {
                TimelineView(.animation) { context in
                    canvas(pose: LumiPose(time: context.date.timeIntervalSinceReferenceDate, talking: talking))
                }
            } else {
                canvas(pose: LumiPose(time: nil))
            }
        }
        .frame(width: size, height: size)
        .modifier(LumiReaction(trigger: feeling, enabled: isMoving))
        .modifier(LumiHop(trigger: hops, height: size * 0.08, enabled: isMoving))
        .modifier(LumiWiggle(trigger: wiggles, enabled: isMoving))
        .accessibilityElement()
        .accessibilityLabel(feeling.map { "Lumi, feeling \($0.displayName.lowercased())" } ?? "Lumi")
    }

    private func canvas(pose: LumiPose) -> some View {
        let renderer = LumiRenderer(feeling: feeling, play: play, outfit: outfit ?? savedOutfit, palette: palette, pose: pose, holding: holding)
        return Canvas { context, canvasSize in
            renderer.draw(in: context, size: canvasSize)
        }
    }
}

// MARK: - Motion

/// Idle motion at a moment in time. `nil` time gives a still, neutral pose.
struct LumiPose {
    var breath: CGFloat = 0.5
    var blink: CGFloat = 0
    var leafSway: Double = 0
    var float: CGFloat = 0
    /// 0 = mouth closed … 1 = wide open; only while talking.
    var talk: CGFloat = 0

    init(time: TimeInterval?, talking: Bool = false) {
        guard let time else { return }
        if talking {
            talk = (sin(time * 2 * .pi * 6) + 1) / 2
        }
        breath = (sin(time * 2 * .pi / 3.4) + 1) / 2
        let blinkPhase = time.truncatingRemainder(dividingBy: 4.3)
        if blinkPhase < 0.16 {
            blink = 1 - abs(blinkPhase - 0.08) / 0.08
        }
        leafSway = sin(time * 2 * .pi / 2.8) * 6
        float = sin(time * 2 * .pi / 2.2)
    }
}

/// A small squash-and-stretch when the feeling changes.
private struct LumiReaction: ViewModifier {
    let trigger: Feeling?
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.keyframeAnimator(initialValue: CGFloat(1), trigger: trigger) { view, stretch in
                view.scaleEffect(x: 2 - stretch, y: stretch, anchor: .bottom)
            } keyframes: { _ in
                SpringKeyframe(0.9, duration: 0.1, spring: .snappy)
                SpringKeyframe(1.07, duration: 0.18, spring: .bouncy)
                SpringKeyframe(1.0, duration: 0.35, spring: .smooth)
            }
        } else {
            content
        }
    }
}

/// A little hop: crouch, spring up, land with a squish.
private struct LumiHop: ViewModifier {
    let trigger: Int
    let height: CGFloat
    let enabled: Bool

    private struct Values {
        var lift: CGFloat = 0
        var stretch: CGFloat = 1
    }

    func body(content: Content) -> some View {
        if enabled {
            content.keyframeAnimator(initialValue: Values(), trigger: trigger) { view, values in
                view
                    .scaleEffect(x: 2 - values.stretch, y: values.stretch, anchor: .bottom)
                    .offset(y: -values.lift * height)
            } keyframes: { _ in
                KeyframeTrack(\.lift) {
                    CubicKeyframe(0, duration: 0.07)
                    CubicKeyframe(1, duration: 0.16)
                    CubicKeyframe(0, duration: 0.16)
                }
                KeyframeTrack(\.stretch) {
                    SpringKeyframe(0.88, duration: 0.07, spring: .snappy)
                    SpringKeyframe(1.08, duration: 0.16, spring: .snappy)
                    SpringKeyframe(0.92, duration: 0.16, spring: .snappy)
                    SpringKeyframe(1.0, duration: 0.3, spring: .bouncy)
                }
            }
        } else {
            content
        }
    }
}

/// A happy side-to-side lean, like leaning into a hand.
private struct LumiWiggle: ViewModifier {
    let trigger: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, angle in
                view.rotationEffect(.degrees(angle), anchor: .bottom)
            } keyframes: { _ in
                SpringKeyframe(-6, duration: 0.1, spring: .snappy)
                SpringKeyframe(5, duration: 0.14, spring: .snappy)
                SpringKeyframe(-2.5, duration: 0.14, spring: .snappy)
                SpringKeyframe(0, duration: 0.25, spring: .smooth)
            }
        } else {
            content
        }
    }
}

// MARK: - Drawing

/// Lumi's outline in her 200×200 design space, shared with the clothes that follow it.
enum LumiShape {
    static let body: Path = {
        var body = Path()
        body.move(to: CGPoint(x: 100, y: 44))
        body.addCurve(to: CGPoint(x: 162, y: 120), control1: CGPoint(x: 140, y: 44), control2: CGPoint(x: 162, y: 82))
        body.addCurve(to: CGPoint(x: 100, y: 182), control1: CGPoint(x: 164, y: 160), control2: CGPoint(x: 140, y: 182))
        body.addCurve(to: CGPoint(x: 38, y: 120), control1: CGPoint(x: 60, y: 182), control2: CGPoint(x: 36, y: 160))
        body.addCurve(to: CGPoint(x: 100, y: 44), control1: CGPoint(x: 38, y: 82), control2: CGPoint(x: 60, y: 44))
        body.closeSubpath()
        return body
    }()

    static let feet = [
        CGRect(x: 56, y: 165, width: 38, height: 22),
        CGRect(x: 106, y: 165, width: 38, height: 22),
    ]
}

/// Draws Lumi in a 200×200 design space, scaled to the canvas.
private struct LumiRenderer {
    let feeling: Feeling?
    let play: LumiPlay?
    let outfit: LumiOutfit
    let palette: LumiPalette
    let pose: LumiPose
    let holding: Bool

    private let leftEye = CGPoint(x: 76, y: 110)
    private let rightEye = CGPoint(x: 124, y: 110)
    private let mouth = CGPoint(x: 100, y: 131)

    /// The feeling whose eyes and mouth to draw: a playful face wins for a moment.
    private var face: Feeling? { play?.face ?? feeling }

    func draw(in canvas: GraphicsContext, size: CGSize) {
        var context = canvas
        context.scaleBy(x: size.width / 200, y: size.height / 200)

        drawShadow(context)
        drawFeet(context)
        wear(.shoes, in: context)

        // Everything above the feet breathes, anchored at the bottom of the body.
        var upper = context
        let stretch = pose.breath - 0.5
        upper.translateBy(x: 100, y: 180)
        upper.scaleBy(x: 1 - 0.018 * stretch, y: 1 + 0.035 * stretch)
        upper.translateBy(x: -100, y: -180)

        if let fantasy = outfit.item(in: .fantasy), LumiWearArt.isBehind(fantasy) {
            LumiWearArt.draw(fantasy, in: upper)
        }
        if !holding {
            drawArms(upper)
        }
        drawLeaf(upper)
        drawBody(upper)
        wear(.clothes, in: upper)
        drawCheeks(upper)
        drawEyes(upper)
        drawMouth(upper)
        wear(.makeup, in: upper)
        wear(.hair, in: upper)
        wear(.glasses, in: upper)
        wear(.hat, in: upper)
        if let fantasy = outfit.item(in: .fantasy), !LumiWearArt.isBehind(fantasy) {
            LumiWearArt.draw(fantasy, in: upper)
        }
        drawAccents(context)
    }

    private func wear(_ slot: LumiWearSlot, in context: GraphicsContext) {
        if let item = outfit.item(in: slot) {
            LumiWearArt.draw(item, in: context)
        }
    }

    // MARK: Body

    private func drawShadow(_ context: GraphicsContext) {
        var shadow = context
        shadow.addFilter(.blur(radius: 4))
        shadow.fill(Path(ellipseIn: CGRect(x: 48, y: 177, width: 104, height: 14)), with: .color(.black.opacity(0.10)))
    }

    private func drawFeet(_ context: GraphicsContext) {
        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [palette.body, palette.bodyDark]),
            startPoint: CGPoint(x: 100, y: 164),
            endPoint: CGPoint(x: 100, y: 188)
        )
        for foot in LumiShape.feet {
            context.fill(Path(ellipseIn: foot), with: shading)
        }
    }

    private func drawArms(_ context: GraphicsContext) {
        // Sleeves, when her clothes have them.
        let (light, dark) = LumiWearArt.sleeveColors(for: outfit.item(in: .clothes)) ?? (palette.body, palette.bodyDark)
        for (x, angle) in [(CGFloat(42), 18.0), (CGFloat(158), -18.0)] {
            var arm = context
            arm.translateBy(x: x, y: 128)
            arm.rotate(by: .degrees(angle))
            arm.fill(
                Path(ellipseIn: CGRect(x: -12, y: -20, width: 24, height: 40)),
                with: .linearGradient(
                    Gradient(colors: [light, dark]),
                    startPoint: CGPoint(x: 0, y: -20),
                    endPoint: CGPoint(x: 0, y: 20)
                )
            )
        }
    }

    private func drawLeaf(_ context: GraphicsContext) {
        var leaf = context
        leaf.translateBy(x: 102, y: 52)
        leaf.rotate(by: .degrees(22 + pose.leafSway))

        var stem = Path()
        stem.move(to: CGPoint(x: 0, y: 6))
        stem.addQuadCurve(to: CGPoint(x: 0, y: -10), control: CGPoint(x: -3, y: -2))
        leaf.stroke(stem, with: .color(palette.leafDark), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        var blade = Path()
        blade.move(to: CGPoint(x: 0, y: -6))
        blade.addQuadCurve(to: CGPoint(x: 0, y: -50), control: CGPoint(x: 26, y: -26))
        blade.addQuadCurve(to: CGPoint(x: 0, y: -6), control: CGPoint(x: -24, y: -30))
        leaf.fill(
            blade,
            with: .linearGradient(
                Gradient(colors: [palette.leaf, palette.leafDark]),
                startPoint: CGPoint(x: 0, y: -50),
                endPoint: CGPoint(x: 0, y: -6)
            )
        )

        var vein = Path()
        vein.move(to: CGPoint(x: 0, y: -10))
        vein.addQuadCurve(to: CGPoint(x: 0, y: -44), control: CGPoint(x: 3, y: -27))
        leaf.stroke(vein, with: .color(.white.opacity(0.45)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    private func drawBody(_ context: GraphicsContext) {
        context.fill(
            LumiShape.body,
            with: .radialGradient(
                Gradient(colors: [palette.bodyLight, palette.body, palette.bodyDark]),
                center: CGPoint(x: 78, y: 78),
                startRadius: 4,
                endRadius: 150
            )
        )

        var highlight = context
        highlight.addFilter(.blur(radius: 5))
        highlight.fill(Path(ellipseIn: CGRect(x: 60, y: 62, width: 38, height: 22)), with: .color(.white.opacity(0.4)))
    }

    private func drawCheeks(_ context: GraphicsContext) {
        var cheeks = context
        cheeks.addFilter(.blur(radius: 2.5))
        let opacity = play != nil ? 0.85 : feeling == .irritable ? 0.75 : 0.55
        for x in [CGFloat(46), 130] {
            cheeks.fill(Path(ellipseIn: CGRect(x: x, y: 121, width: 24, height: 13)), with: .color(LumiPalette.blush.opacity(opacity)))
        }
    }

    // MARK: Face

    private func drawEyes(_ context: GraphicsContext) {
        switch face {
        case nil:
            openEye(context, at: leftEye)
            openEye(context, at: rightEye)
        case .happy:
            arcEye(context, at: leftEye, curve: -12)
            arcEye(context, at: rightEye, curve: -12)
        case .calm:
            arcEye(context, at: leftEye, curve: 9)
            arcEye(context, at: rightEye, curve: 9)
        case .tired:
            arcEye(context, at: leftEye.offsetBy(y: 3), curve: 6)
            arcEye(context, at: rightEye.offsetBy(y: 3), curve: 6)
        case .anxious:
            openEye(context, at: leftEye, scale: 0.85)
            openEye(context, at: rightEye, scale: 0.85)
            worriedBrows(context)
        case .irritable:
            squeezedEye(context, at: leftEye, pointingRight: true)
            squeezedEye(context, at: rightEye, pointingRight: false)
        case .sad:
            openEye(context, at: leftEye, scale: 1.05)
            openEye(context, at: rightEye, scale: 1.05)
            worriedBrows(context)
            context.fill(
                Self.teardrop(center: leftEye.offsetBy(x: -6, y: 22 + pose.float * 1.5), radius: 4),
                with: .color(LumiPalette.tear)
            )
        }
    }

    private func openEye(_ context: GraphicsContext, at center: CGPoint, scale: CGFloat = 1) {
        let width = 22 * scale
        let height = 27 * scale * (1 - 0.9 * pose.blink)
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)),
            with: .color(LumiPalette.eye)
        )
        guard pose.blink < 0.5 else { return }
        context.fill(Path(ellipseIn: CGRect(x: center.x + 0.5, y: center.y - 10 * scale, width: 8.4 * scale, height: 8.4 * scale)), with: .color(.white))
        context.fill(Path(ellipseIn: CGRect(x: center.x - 6 * scale, y: center.y + 3 * scale, width: 4 * scale, height: 4 * scale)), with: .color(.white.opacity(0.85)))
    }

    /// Closed eye; negative `curve` bends up (^), positive bends down (u).
    private func arcEye(_ context: GraphicsContext, at center: CGPoint, curve: CGFloat) {
        var path = Path()
        path.move(to: center.offsetBy(x: -10, y: curve < 0 ? 3 : -1))
        path.addQuadCurve(to: center.offsetBy(x: 10, y: curve < 0 ? 3 : -1), control: center.offsetBy(y: curve))
        context.stroke(path, with: .color(LumiPalette.eye), style: StrokeStyle(lineWidth: 3.6, lineCap: .round))
    }

    private func squeezedEye(_ context: GraphicsContext, at center: CGPoint, pointingRight: Bool) {
        let direction: CGFloat = pointingRight ? 1 : -1
        var path = Path()
        path.move(to: center.offsetBy(x: -8 * direction, y: -7))
        path.addLine(to: center.offsetBy(x: 6 * direction))
        path.addLine(to: center.offsetBy(x: -8 * direction, y: 7))
        context.stroke(path, with: .color(LumiPalette.eye), style: StrokeStyle(lineWidth: 3.6, lineCap: .round, lineJoin: .round))
    }

    private func worriedBrows(_ context: GraphicsContext) {
        var path = Path()
        path.move(to: leftEye.offsetBy(x: -10, y: -18))
        path.addLine(to: leftEye.offsetBy(x: 7, y: -23))
        path.move(to: rightEye.offsetBy(x: 10, y: -18))
        path.addLine(to: rightEye.offsetBy(x: -7, y: -23))
        context.stroke(path, with: .color(LumiPalette.eye.opacity(0.8)), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
    }

    private func drawMouth(_ context: GraphicsContext) {
        let ink = GraphicsContext.Shading.color(LumiPalette.eye)
        let line = StrokeStyle(lineWidth: 3, lineCap: .round)
        var path = Path()

        if pose.talk > 0, play == nil {
            let height = 3 + 9 * pose.talk
            context.fill(Path(ellipseIn: CGRect(x: mouth.x - 6, y: mouth.y - 2, width: 12, height: height)), with: ink)
            if height > 7 {
                context.fill(Path(ellipseIn: CGRect(x: mouth.x - 3.5, y: mouth.y + height - 6, width: 7, height: 3.5)), with: .color(LumiPalette.blush))
            }
            return
        }

        switch face {
        case nil:
            path.move(to: mouth.offsetBy(x: -8, y: -1))
            path.addQuadCurve(to: mouth.offsetBy(x: 8, y: -1), control: mouth.offsetBy(y: 7))
            context.stroke(path, with: ink, style: line)
        case .happy:
            path.move(to: mouth.offsetBy(x: -10, y: -3))
            path.addQuadCurve(to: mouth.offsetBy(x: 10, y: -3), control: mouth.offsetBy(y: 15))
            path.closeSubpath()
            context.fill(path, with: ink)
            context.fill(Path(ellipseIn: CGRect(x: mouth.x - 5, y: mouth.y + 2, width: 10, height: 4.5)), with: .color(LumiPalette.blush))
        case .calm:
            path.move(to: mouth.offsetBy(x: -6))
            path.addQuadCurve(to: mouth.offsetBy(x: 6), control: mouth.offsetBy(y: 5))
            context.stroke(path, with: ink, style: line)
        case .tired:
            context.fill(Path(ellipseIn: CGRect(x: mouth.x - 3.5, y: mouth.y - 1, width: 7, height: 8)), with: ink)
        case .anxious:
            path.move(to: mouth.offsetBy(x: -9, y: 2))
            path.addQuadCurve(to: mouth.offsetBy(y: 1), control: mouth.offsetBy(x: -4.5, y: -4))
            path.addQuadCurve(to: mouth.offsetBy(x: 9, y: 1), control: mouth.offsetBy(x: 4.5, y: 6))
            context.stroke(path, with: ink, style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        case .irritable:
            path.move(to: mouth.offsetBy(x: -8, y: 4))
            path.addQuadCurve(to: mouth.offsetBy(x: 8, y: 4), control: mouth.offsetBy(y: -4))
            context.stroke(path, with: ink, style: line)
        case .sad:
            path.move(to: mouth.offsetBy(x: -7, y: 4))
            path.addQuadCurve(to: mouth.offsetBy(x: 7, y: 4), control: mouth.offsetBy(y: -3))
            context.stroke(path, with: ink, style: line)
        }
    }

    // MARK: Accents

    private func drawAccents(_ context: GraphicsContext) {
        let bob = pose.float * 3
        switch play {
        case .giggle:
            let giggle = Text("hehe").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(palette.bodyDark)
            context.draw(giggle, at: CGPoint(x: 160, y: 46 + bob))
            return
        case .petted:
            context.fill(Path.lumiHeart(in: CGRect(x: 150, y: 40 - bob, width: 18, height: 16)), with: .color(LumiPalette.heart))
            context.fill(Path.lumiHeart(in: CGRect(x: 34, y: 56 + bob, width: 12, height: 11)), with: .color(LumiPalette.heart.opacity(0.8)))
            return
        case nil:
            break
        }
        switch feeling {
        case .happy:
            context.fill(Path.lumiHeart(in: CGRect(x: 30, y: 46 + bob, width: 18, height: 16)), with: .color(LumiPalette.heart))
            context.fill(Path.lumiHeart(in: CGRect(x: 156, y: 58 - bob, width: 13, height: 12)), with: .color(LumiPalette.heart.opacity(0.8)))
        case .tired:
            let color = palette.bodyDark
            context.draw(Text("z").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(color), at: CGPoint(x: 148, y: 50 + bob))
            context.draw(Text("Z").font(.system(size: 21, weight: .heavy, design: .rounded)).foregroundStyle(color), at: CGPoint(x: 164, y: 32 + bob))
        case .anxious:
            context.fill(Self.teardrop(center: CGPoint(x: 156, y: 92 + bob * 0.5), radius: 5), with: .color(LumiPalette.tear))
            var scribble = Path()
            scribble.move(to: CGPoint(x: 34, y: 58 + bob))
            for step in 1...10 {
                let angle = Double(step) * .pi / 2.5
                let radius = 4 + Double(step) * 0.6
                scribble.addLine(to: CGPoint(x: 42 + cos(angle) * radius, y: 56 + bob + sin(angle) * radius))
            }
            context.stroke(scribble, with: .color(LumiPalette.eye.opacity(0.55)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
        case .irritable:
            for (x, flip) in [(CGFloat(36), CGFloat(1)), (CGFloat(164), -1)] {
                var bolt = Path()
                bolt.move(to: CGPoint(x: x - 4 * flip, y: 50 + bob))
                bolt.addLine(to: CGPoint(x: x + 3 * flip, y: 58 + bob))
                bolt.addLine(to: CGPoint(x: x - 3 * flip, y: 61 + bob))
                bolt.addLine(to: CGPoint(x: x + 4 * flip, y: 70 + bob))
                context.stroke(bolt, with: .color(LumiPalette.anger), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        case .calm, .sad, nil:
            break
        }
    }

    // MARK: Shapes

    static func teardrop(center: CGPoint, radius: CGFloat) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: center.x + x * radius, y: center.y + y * radius)
        }
        var path = Path()
        path.move(to: point(0, -1.7))
        path.addCurve(to: point(1, 0.1), control1: point(0.25, -1.1), control2: point(1, -0.6))
        path.addCurve(to: point(-1, 0.1), control1: point(1, 1.4), control2: point(-1, 1.4))
        path.addCurve(to: point(0, -1.7), control1: point(-1, -0.6), control2: point(-0.25, -1.1))
        path.closeSubpath()
        return path
    }
}

private extension CGPoint {
    func offsetBy(x dx: CGFloat = 0, y dy: CGFloat = 0) -> CGPoint {
        CGPoint(x: x + dx, y: y + dy)
    }
}

#Preview("Feelings") {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
        LumiView(feeling: nil, size: 110)
        ForEach(Feeling.allCases) { feeling in
            VStack {
                LumiView(feeling: feeling, size: 110)
                Text(feeling.displayName).font(.caption)
            }
        }
    }
    .padding()
    .background(Color.cycleBackground)
}

#Preview("Phases") {
    HStack {
        ForEach(LunePhase.allCases, id: \.self) { phase in
            LumiView(phase: phase, size: 80, animated: false)
        }
    }
    .padding()
    .background(Color.cycleBackground)
}
