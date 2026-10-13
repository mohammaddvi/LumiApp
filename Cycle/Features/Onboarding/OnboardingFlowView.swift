import SwiftUI

struct OnboardingFlowView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var step = 0
    @State private var lastPeriodStart = Date().addingDays(-5)
    @State private var typicalLength = 28
    @State private var useTypicalLength = false
    @State private var experiencesPMS: Bool? = nil
    @State private var periodSymptoms: Set<SymptomType> = []
    @State private var pmsSymptoms: Set<SymptomType> = []
    @State private var remindPeriodClose = true
    @State private var remindPMSClose = true
    @State private var remindSymptoms = true
    @State private var iMessageEnabled = false
    @State private var iMessageContacts: [MessageContact] = []

    private let totalSteps = 6

    var body: some View {
        ZStack {
            Color.cycleBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                progress
                    .padding(.top, 16)
                    .padding(.horizontal, 24)

                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    privacyStep.tag(1)
                    lastPeriodStep.tag(2)
                    pmsStep.tag(3)
                    symptomsStep.tag(4)
                    remindersStep.tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: step)

                bottomBar
                    .padding(24)
            }
        }
    }

    private var progress: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Color.cycleSage : Color.cycleBorder)
                    .frame(height: 4)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel("Onboarding step \(step + 1) of \(totalSteps)")
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text("Lumi")
                .font(.system(.largeTitle, design: .rounded).weight(.medium))
                .foregroundStyle(Color.cycleText)
            Text("a few qs to personalize your lumi — everything stays on this phone.")
                .font(.title3)
                .foregroundStyle(Color.cycleSecondary)
            Text("no account. no ads. no data sold.")
                .font(.body)
                .foregroundStyle(Color.cycleSecondary)
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var privacyStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            SectionHeader(
                title: "Private by design",
                subtitle: "Before any health data is saved, here’s how Lumi works."
            )
            privacyRow(icon: "iphone", title: "On-device storage", body: "Periods, symptoms, and notes never leave this phone in the MVP.")
            privacyRow(icon: "lock.shield", title: "Optional app lock", body: "Protect the app with Face ID, Touch ID, or your passcode.")
            privacyRow(icon: "bell", title: "Gentle reminders only", body: "You choose what to hear about — never fear-based alerts.")
            Spacer()
        }
        .padding(28)
    }

    private var lastPeriodStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(
                    title: "When did your last period start?",
                    subtitle: "This is the one required detail to begin tracking."
                )
                DatePicker(
                    "Last period start",
                    selection: $lastPeriodStart,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Color.cycleAccentText)
                .accessibilityLabel("Last period start date")

                Toggle(isOn: $useTypicalLength) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("I know my typical cycle length")
                            .foregroundStyle(Color.cycleText)
                        Text("Optional — used until Lumi learns from your history.")
                            .font(.footnote)
                            .foregroundStyle(Color.cycleSecondary)
                    }
                }
                .tint(Color.cycleAccentText)

                if useTypicalLength {
                    Stepper(value: $typicalLength, in: 21...45) {
                        Text("Typical length: \(typicalLength) days")
                            .foregroundStyle(Color.cycleText)
                    }
                }
            }
            .padding(24)
        }
    }

    private var pmsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            SectionHeader(
                title: "Do you usually have PMS?",
                subtitle: "Premenstrual symptoms in the days before your period. There’s no wrong answer."
            )

            VStack(spacing: 12) {
                pmsChoice(title: "Yes", subtitle: "I often notice changes before my period", value: true)
                pmsChoice(title: "No", subtitle: "I usually don’t notice a clear PMS phase", value: false)
            }

            Text("This only personalizes reminders and symptom shortcuts — not a diagnosis.")
                .font(.footnote)
                .foregroundStyle(Color.cycleSecondary)
            Spacer()
        }
        .padding(28)
    }

    private var symptomsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(
                    title: "What symptoms do you usually notice?",
                    subtitle: "Choose anything familiar. Categories are separated so Body and Mind stay easy to tell apart."
                )

                SymptomBaselineCard(
                    title: "During your period",
                    subtitle: "Symptoms you notice while bleeding",
                    selection: $periodSymptoms
                )

                if experiencesPMS == true {
                    SymptomBaselineCard(
                        title: "During PMS",
                        subtitle: "Symptoms in the days before your period",
                        selection: $pmsSymptoms
                    )
                }

                Text("Not a diagnosis — just a baseline for your own patterns.")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.cycleSecondary)
                    .accessibilityLabel("Disclaimer: not a diagnosis. This is only a baseline for your own patterns.")
            }
            .padding(24)
        }
    }

    private var remindersStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader(
                    title: "What reminders would you like?",
                    subtitle: "Calm, factual heads-ups only. You can turn these off anytime."
                )

                reminderToggle(
                    title: "Period is close",
                    subtitle: "A gentle note when your next period window is approaching.",
                    isOn: $remindPeriodClose
                )

                if experiencesPMS == true {
                    reminderToggle(
                        title: "PMS is close",
                        subtitle: "A heads-up a few days before your likely period start.",
                        isOn: $remindPMSClose
                    )
                }

                reminderToggle(
                    title: "Symptoms you might notice",
                    subtitle: symptomReminderSubtitle,
                    isOn: $remindSymptoms
                )

                IMessageContactsEditor(
                    contacts: $iMessageContacts,
                    enabled: $iMessageEnabled
                )

                Text("We’ll ask for notification permission only if you enable at least one on-device reminder.")
                    .font(.footnote)
                    .foregroundStyle(Color.cycleSecondary)
            }
            .padding(28)
        }
    }

    private var symptomReminderSubtitle: String {
        let names = Array(periodSymptoms.union(pmsSymptoms)).prefix(3).map(\.displayName)
        if names.isEmpty {
            return "Remind you to check in with symptoms you’ve shared."
        }
        return "Based on what you selected: \(names.joined(separator: ", "))."
    }

    // MARK: - Controls

    private var canContinue: Bool {
        switch step {
        case 3: return experiencesPMS != nil
        default: return true
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(PrimaryButtonStyle(filled: false))
            }
            Button(step == totalSteps - 1 ? "Start tracking" : "Continue") {
                advance()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.5)
        }
    }

    private func advance() {
        if step < totalSteps - 1 {
            // Skip PMS symptom emphasis when user said no — still show period symptoms
            if step == 3, experiencesPMS == false {
                remindPMSClose = false
            }
            step += 1
            return
        }

        Task {
            await env.completeOnboarding(
                OnboardingProfile(
                    lastPeriodStart: lastPeriodStart,
                    typicalCycleLength: useTypicalLength ? typicalLength : nil,
                    experiencesPMS: experiencesPMS ?? false,
                    periodSymptoms: Array(periodSymptoms).sorted { $0.rawValue < $1.rawValue },
                    pmsSymptoms: Array(pmsSymptoms).sorted { $0.rawValue < $1.rawValue },
                    remindPeriodClose: remindPeriodClose,
                    remindPMSClose: (experiencesPMS ?? false) && remindPMSClose,
                    remindSymptoms: remindSymptoms,
                    iMessageContacts: iMessageContacts,
                    iMessageRemindersEnabled: iMessageEnabled && !iMessageContacts.isEmpty
                )
            )
        }
    }

    private func pmsChoice(title: String, subtitle: String, value: Bool) -> some View {
        let selected = experiencesPMS == value
        return Button {
            experiencesPMS = value
            if !value {
                pmsSymptoms = []
                remindPMSClose = false
            } else if remindPMSClose == false {
                remindPMSClose = true
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? Color.cycleSage : Color.cycleSecondary)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(Color.cycleText)
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.cycleSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(Color.cycleSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Color.cycleSage : Color.cycleBorder, lineWidth: selected ? 2.5 : 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityHint(subtitle)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func reminderToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(Color.cycleText)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Color.cycleSecondary)
            }
        }
        .tint(Color.cycleAccentText)
        .padding(16)
        .background(Color.cycleSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.cycleBorder, lineWidth: 1)
        )
    }

    private func privacyRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.cycleAccentText)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(Color.cycleText)
                Text(body).font(.subheadline).foregroundStyle(Color.cycleSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
