import Foundation

/// Where someone is in their cycle, in everyday words, for suggestions and AI context.
enum CycleMoment: String, CaseIterable, Sendable {
    case period
    case follicular
    case ovulation
    case luteal
    /// The few days before the next period (Lumi's "soft days").
    case prePeriod

    init(snapshot: TodaysLuneSnapshot) {
        switch snapshot.phase {
        case .reset: self = .period
        case _ where snapshot.isSoftDays: self = .prePeriod
        case .bloom: self = .follicular
        case .glow: self = .ovulation
        case .slow: self = .luteal
        }
    }

    func displayName(experiencesPMS: Bool) -> String {
        switch self {
        case .period: "your period"
        case .follicular: "your energy-building phase"
        case .ovulation: "your ovulation window"
        case .luteal: "your slower phase"
        case .prePeriod: experiencesPMS ? "your PMS days" : "the days before your period"
        }
    }
}

enum WellnessTopic: String, CaseIterable, Sendable, Identifiable {
    case food
    case drinks
    case mind
    case movement
    case rest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: "Food"
        case .drinks: "Drinks"
        case .mind: "Mind"
        case .movement: "Move"
        case .rest: "Rest"
        }
    }

    var emoji: String {
        switch self {
        case .food: "🍓"
        case .drinks: "🍵"
        case .mind: "💜"
        case .movement: "🌿"
        case .rest: "🌙"
        }
    }

    var systemImage: String {
        switch self {
        case .food: "fork.knife"
        case .drinks: "cup.and.saucer.fill"
        case .mind: "heart.circle.fill"
        case .movement: "figure.walk"
        case .rest: "moon.zzz.fill"
        }
    }

    /// What the topic means when asking the AI.
    var askPhrase: String {
        switch self {
        case .food: "food and snack ideas"
        case .drinks: "drink ideas"
        case .mind: "ideas to care for my mood and mental health"
        case .movement: "gentle movement and exercise ideas"
        case .rest: "rest and sleep ideas"
        }
    }
}

/// A short, general-wellness tip shown instantly, plus the question that asks the AI for more.
struct CycleTip: Equatable, Sendable, Identifiable {
    let topic: WellnessTopic
    let text: String
    let prompt: String

    var id: WellnessTopic { topic }
}

/// Curated, non-medical wellness tips for each cycle moment. The AI personalizes from there.
enum CycleTipsEngine {
    static func tips(for moment: CycleMoment, experiencesPMS: Bool) -> [CycleTip] {
        let name = moment.displayName(experiencesPMS: experiencesPMS)
        return WellnessTopic.allCases.map { topic in
            CycleTip(
                topic: topic,
                text: text(for: topic, in: moment),
                prompt: "I'm in \(name). Suggest a few \(topic.askPhrase) for today, based on my cycle and how I've been feeling."
            )
        }
    }

    private static func text(for topic: WellnessTopic, in moment: CycleMoment) -> String {
        switch (moment, topic) {
        case (.period, .food): "Iron-rich foods like lentils, spinach or eggs help replace what your body loses."
        case (.period, .drinks): "Warm ginger or chamomile tea can feel soothing when cramps show up."
        case (.period, .mind): "Lower energy is normal now. Let today be a slower, kinder day."
        case (.period, .movement): "Gentle stretching, yoga or a short walk can ease cramps."
        case (.period, .rest): "A heat pad and an earlier night can help your body recharge."

        case (.follicular, .food): "Fresh, light meals with protein support your rising energy."
        case (.follicular, .drinks): "Water and fruity smoothies keep you going as energy builds."
        case (.follicular, .mind): "A nice time to start something new or plan your week."
        case (.follicular, .movement): "Try something new: a dance class, a run or strength training."
        case (.follicular, .rest): "A steady bedtime helps you ride this energy well."

        case (.ovulation, .food): "Colorful veggies, fruit and healthy fats keep energy steady."
        case (.ovulation, .drinks): "Keep a water bottle close, especially if you're active."
        case (.ovulation, .mind): "Many people feel more social now. A good day for plans with friends."
        case (.ovulation, .movement): "Energy often peaks here: a good time for a harder workout if you feel like it."
        case (.ovulation, .rest): "Wind down in the evening, even on high-energy days."

        case (.luteal, .food): "Complex carbs and magnesium-rich foods like nuts, seeds and dark chocolate can help."
        case (.luteal, .drinks): "Herbal teas and plenty of water; go easy on alcohol."
        case (.luteal, .mind): "Turning inward feels good now: journaling or quiet time."
        case (.luteal, .movement): "Yoga, pilates or long walks match this slower phase."
        case (.luteal, .rest): "Your body may want a bit more sleep. That's okay."

        case (.prePeriod, .food): "Steady meals with whole grains and protein can calm cravings and mood swings."
        case (.prePeriod, .drinks): "Less caffeine and salt may ease bloating and tension. Water helps too."
        case (.prePeriod, .mind): "Feelings can run bigger now. Be gentle with yourself and plan something calming."
        case (.prePeriod, .movement): "A walk or light cardio can lift your mood."
        case (.prePeriod, .rest): "Keep regular sleep times; sleep can feel lighter before your period."
        }
    }
}
