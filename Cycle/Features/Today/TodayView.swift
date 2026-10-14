import SwiftUI

/// Home: Lumi holds this month's calendar and shows today's feeling, logged or guessed.
/// Tapping Lumi opens the feeling check-in.
struct TodayView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.isSplashFinished) private var isSplashFinished
    @State private var showFeelingSheet = false
    /// Bumped after each successful log to fire Lumi's sparkle burst and the success haptic.
    @State private var logCount = 0
    @State private var speech = LumiSpeech()
    @State private var showNameSheet = false
    /// Last day Lumi greeted you (yyyy-MM-dd): she greets at most once a day, and the gap since
    /// tells her whether you've been away.
    @AppStorage("lumi.lastQuestionDay") private var lastQuestionDay = ""
    /// Lumi asks your name only once (onboarding counts as asking).
    @AppStorage("lumi.askedName") private var askedName = false

    /// Keeps the header text clear of Lumi, who peeks over the calendar's top-right corner.
    private static let lumiRoom: CGFloat = 164

    var body: some View {
        CalendarView(
            title: LuneVoice.greeting(hour: Calendar.current.component(.hour, from: .now), name: env.preferences.userName),
            lumiCelebration: logCount,
            lumiSpeech: speech,
            onLumiTap: {
                let isAskingName = speech.text == LuneVoice.lumiAsksName
                speech.dismiss()
                if isAskingName {
                    showNameSheet = true
                } else {
                    showFeelingSheet = true
                }
            }
        ) {
            header
                .opacity(speech.text == nil ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: speech.text == nil)
        }
        .sensoryFeedback(.success, trigger: logCount)
        .task(id: isSplashFinished) {
            await greetIfNeeded()
        }
        .sheet(isPresented: $showNameSheet) {
            NavigationStack {
                LumiNameSheet { name in
                    sayLater(LuneVoice.lumiNiceToMeet(name))
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showFeelingSheet) {
            NavigationStack {
                FeelingCheckInSheet(guess: env.feelingForecast?.feeling) {
                    logCount += 1
                    replyToLoggedFeeling()
                }
            }
        }
    }

    /// Once a day, after the splash: Lumi asks your name if she doesn't know it yet, otherwise says
    /// something about today, then asks how you feel if nothing is logged.
    private func greetIfNeeded() async {
        let today = Date.now.formatted(.iso8601.year().month().day())
        var forcedMoment: LumiMoment?
        var forceAsk = false
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        forceAsk = arguments.contains("-LumiAsks")
        if let index = arguments.firstIndex(of: "-LumiSays"), index + 1 < arguments.count {
            forcedMoment = LumiMoment(rawValue: arguments[index + 1])
        }
        #endif
        let forced = forceAsk || forcedMoment != nil
        // Asking your name is one-time, so it doesn't wait for tomorrow's greeting.
        let asksName = !forced && env.preferences.userName == nil && !askedName
        guard isSplashFinished, forced || asksName || lastQuestionDay != today else { return }
        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled else { return }

        let daysAway = Self.days(from: lastQuestionDay, to: today)
        lastQuestionDay = today

        if asksName {
            askedName = true
            say(LuneVoice.lumiAsksName)
            return
        }

        let moment = forcedMoment ?? (forceAsk ? nil : LumiMomentEngine.moment(
            for: env.lumiMomentInput(daysSinceLastVisit: daysAway)
        ))
        if let moment {
            say(LuneVoice.lumiSays(moment, name: env.preferences.userName, experiencesPMS: env.preferences.experiencesPMS))
            // Let that line finish and fade before asking how you feel.
            for _ in 0..<60 where speech.text != nil {
                try? await Task.sleep(for: .milliseconds(300))
            }
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, !showFeelingSheet, !showNameSheet else { return }
        }
        if forceAsk || env.todayFeeling == nil {
            say(LuneVoice.lumiAsksFeeling.randomElement() ?? LuneVoice.feelingPrompt)
        }
    }

    /// Whole days between two yyyy-MM-dd days; `nil` when there was no earlier visit.
    private static func days(from earlier: String, to later: String) -> Int? {
        let parse = Date.ISO8601FormatStyle().year().month().day()
        guard let from = try? Date(earlier, strategy: parse),
              let to = try? Date(later, strategy: parse)
        else { return nil }
        return Calendar(identifier: .gregorian).dateComponents([.day], from: from, to: to).day
    }

    private func say(_ line: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            speech.say(line)
        }
    }

    /// Says `line` once a sheet has closed, so it's seen.
    private func sayLater(_ line: String) {
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            say(line)
        }
    }

    /// After a log, Lumi answers with a short line for that feeling.
    private func replyToLoggedFeeling() {
        guard let feeling = env.todayFeeling else { return }
        sayLater(LuneVoice.lumiMessage(for: feeling, name: env.preferences.userName))
    }

    private var header: some View {
        let logged = env.todayFeeling
        let forecast = env.feelingForecast

        return VStack(alignment: .leading, spacing: 6) {
            if let logged {
                feelingName(logged)
            } else if let forecast {
                feelingName(forecast.feeling)
            } else {
                Text(LuneVoice.lumiIntroTitle)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.cycleText)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, Self.lumiRoom)
        .animation(.smooth(duration: 0.25), value: logged)
        .accessibilityElement(children: .combine)
    }

    private func feelingName(_ feeling: Feeling) -> some View {
        Text(feeling.displayName)
            .font(.system(.title2, design: .rounded).weight(.bold))
            .foregroundStyle(Color.cycleText)
    }
}

#Preview {
    NavigationStack { TodayView() }
        .environment(AppEnvironment.preview())
}
