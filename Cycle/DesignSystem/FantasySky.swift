import SwiftUI

/// Dreamy sky behind the main tabs: lilac-to-rose mist by day, a starry night in dark mode,
/// with slowly twinkling sparkles (still when Reduce Motion is on).
struct FantasySkyBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isNight: Bool { colorScheme == .dark }

    private var skyColors: [Color] {
        isNight
            ? [Color(red: 0.07, green: 0.06, blue: 0.14), Color(red: 0.106, green: 0.090, blue: 0.188), Color(red: 0.165, green: 0.114, blue: 0.239)]
            : [Color(red: 0.918, green: 0.863, blue: 0.976), Color(red: 0.965, green: 0.941, blue: 0.984), Color(red: 0.988, green: 0.914, blue: 0.937)]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: skyColors, startPoint: .top, endPoint: .bottom)

            GeometryReader { proxy in
                Circle()
                    .fill(Color.cycleSage.opacity(isNight ? 0.25 : 0.35))
                    .frame(width: proxy.size.width * 0.9)
                    .blur(radius: 70)
                    .offset(x: proxy.size.width * 0.35, y: -proxy.size.width * 0.25)
                Circle()
                    .fill(Color.cycleCoral.opacity(isNight ? 0.18 : 0.22))
                    .frame(width: proxy.size.width * 0.8)
                    .blur(radius: 80)
                    .offset(x: -proxy.size.width * 0.35, y: proxy.size.height * 0.6)
            }

            if reduceMotion {
                sparkles(time: nil)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 20)) { context in
                    sparkles(time: context.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func sparkles(time: TimeInterval?) -> some View {
        let night = isNight
        return Canvas { context, size in
            for (index, star) in FantasySparkle.field.enumerated() {
                let twinkle = time.map { (sin($0 * star.speed + Double(index)) + 1) / 2 } ?? 0.6
                let color: Color = index.isMultiple(of: 3)
                    ? Color(red: 0.98, green: 0.82, blue: 0.45)
                    : (night ? .white : Color(red: 0.70, green: 0.58, blue: 0.92))
                context.fill(
                    FantasySparkle.path(
                        center: CGPoint(x: star.x * size.width, y: star.y * size.height),
                        radius: star.radius * (0.7 + 0.3 * twinkle)
                    ),
                    with: .color(color.opacity((night ? 0.35 : 0.25) + 0.5 * twinkle))
                )
            }
        }
    }
}

/// Four-point sparkle, Lumi's magic mark.
enum FantasySparkle {
    struct Star {
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let speed: Double
    }

    /// Fixed positions so the sky doesn't reshuffle between renders.
    static let field: [Star] = [
        Star(x: 0.08, y: 0.06, radius: 5, speed: 1.1), Star(x: 0.30, y: 0.12, radius: 3, speed: 1.7),
        Star(x: 0.86, y: 0.09, radius: 6, speed: 0.9), Star(x: 0.64, y: 0.18, radius: 3.5, speed: 1.4),
        Star(x: 0.12, y: 0.30, radius: 4, speed: 1.9), Star(x: 0.92, y: 0.34, radius: 4.5, speed: 1.2),
        Star(x: 0.05, y: 0.52, radius: 3, speed: 1.5), Star(x: 0.95, y: 0.55, radius: 3, speed: 2.0),
        Star(x: 0.18, y: 0.70, radius: 5, speed: 1.0), Star(x: 0.82, y: 0.74, radius: 4, speed: 1.6),
        Star(x: 0.48, y: 0.04, radius: 2.5, speed: 2.2), Star(x: 0.07, y: 0.88, radius: 3.5, speed: 1.3),
        Star(x: 0.93, y: 0.90, radius: 5, speed: 0.8), Star(x: 0.40, y: 0.95, radius: 3, speed: 1.8),
    ]

    static func path(center: CGPoint, radius: CGFloat) -> Path {
        let waist = radius * 0.16
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: CGPoint(x: center.x + waist, y: center.y - waist))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: CGPoint(x: center.x + waist, y: center.y + waist))
        path.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: CGPoint(x: center.x - waist, y: center.y + waist))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: CGPoint(x: center.x - waist, y: center.y - waist))
        path.closeSubpath()
        return path
    }
}

/// A ring of sparkles that flies outward and fades each time `trigger` changes.
struct MagicBurst: View {
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let colors: [Color] = [
        Color(red: 0.98, green: 0.82, blue: 0.45),
        .cycleCoral,
        .cycleSage,
    ]

    var body: some View {
        if reduceMotion {
            Color.clear
        } else {
            Color.clear
                .keyframeAnimator(initialValue: 0.0, trigger: trigger) { _, progress in
                    Canvas { context, size in
                        let visibility = sin(progress * .pi)
                        guard visibility > 0.01 else { return }
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        for index in 0..<10 {
                            let angle = Double(index) / 10 * 2 * .pi + 0.3
                            let distance = size.width * (0.22 + 0.26 * progress) * (index.isMultiple(of: 2) ? 1 : 0.82)
                            let point = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
                            context.fill(
                                FantasySparkle.path(center: point, radius: index.isMultiple(of: 2) ? 9 : 6),
                                with: .color(Self.colors[index % Self.colors.count].opacity(visibility))
                            )
                        }
                    }
                } keyframes: { _ in
                    CubicKeyframe(1.0, duration: 0.9)
                }
        }
    }
}

extension View {
    /// Puts the fantasy sky behind a main screen.
    func fantasySkyBackground() -> some View {
        background(FantasySkyBackground())
    }
}

#Preview {
    FantasySkyBackground()
}
