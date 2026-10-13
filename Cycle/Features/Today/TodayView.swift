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
    /// Day Lumi last asked how you feel (yyyy-MM-dd), so she asks at most once a day.
    @AppStorage("lumi.lastQuestionDay") private var lastQuestionDay = ""

    /// Keeps the header text clear of Lumi, who peeks over the calendar's top-right corner.
    private static let lumiRoom: CGFloat = 164

    var body: some View {
        CalendarView(
            title: LuneVoice.greeting(hour: Calendar.current.component(.hour, from: .now)),
            lumiCelebration: logCount,
            lumiSpeech: speech,
            onLumiTap: {
                speech.dismiss()
                showFeelingSheet = true
            }
        ) {
            header
                .opacity(speech.text == nil ? 1 : 0)
                .animation(.easeOut(duration: 0.2), value: speech.text == nil)
        }
        .sensoryFeedback(.success, trigger: logCount)
        .task(id: isSplashFinished) {
            await askAboutFeelingIfNeeded()
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

    /// Once a day, after the splash, Lumi asks how you feel if nothing is logged yet.
    private func askAboutFeelingIfNeeded() async {
        let today = Date.now.formatted(.iso8601.year().month().day())
        var force = false
        #if DEBUG
        force = ProcessInfo.processInfo.arguments.contains("-LumiAsks")
        #endif
        guard isSplashFinished, force || (env.todayFeeling == nil && lastQuestionDay != today) else { return }
        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled, force || env.todayFeeling == nil else { return }
        lastQuestionDay = today
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            speech.say(LuneVoice.lumiAsksFeeling.randomElement() ?? LuneVoice.feelingPrompt, mood: env.feelingForecast?.feeling)
        }
    }

    /// After a log, Lumi answers with a short line for that feeling.
    private func replyToLoggedFeeling() {
        Task {
            // Let the sheet close first so the reply is seen.
            try? await Task.sleep(for: .milliseconds(650))
            guard let feeling = env.todayFeeling else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                speech.say(LuneVoice.lumiMessage(for: feeling), mood: feeling)
            }
        }
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
