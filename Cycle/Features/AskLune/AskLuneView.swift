import SwiftUI

struct AskLuneView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable private var ai: LocalAIController
    @FocusState private var promptFocused: Bool
    @ScaledMetric(relativeTo: .body) private var sendIconSize: CGFloat = 32

    init(ai: LocalAIController) {
        self.ai = ai
    }

    var body: some View {
        chatScroll
            .safeAreaInset(edge: .top, spacing: 0) {
                if !promptFocused {
                    statusBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composer
            }
            .background(Color.cycleBackground.ignoresSafeArea(edges: .bottom))
            .navigationTitle("Ask Lumi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !ai.sessionMessages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            ai.startNewChat()
                        } label: {
                            Label("New chat", systemImage: "square.and.pencil")
                        }
                        .disabled(ai.isGenerating)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        promptFocused = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.cycleAccentText)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: promptFocused)
            .task {
                ai.refreshModelAvailability()
                if GemmaModelLocator.resolveModelURL() != nil {
                    await ai.prepare()
                }
            }
    }

    /// The AI can't answer yet because the model isn't on this iPhone.
    private var isModelMissing: Bool {
        if case .modelMissing = ai.status { return true }
        return false
    }

    /// One short line, only while the AI isn't ready.
    @ViewBuilder
    private var statusBanner: some View {
        switch ai.status {
        case .ready:
            EmptyView()
        case .modelMissing:
            bannerRow {
                Label(LuneVoice.aiDownloadHint, systemImage: "arrow.down.circle.fill")
            }
        case .checking, .loading:
            bannerRow {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(LuneVoice.aiPreparing)
                }
            }
        case .failed:
            bannerRow {
                HStack {
                    Text(LuneVoice.aiFailed)
                    Spacer()
                    Button("Retry") {
                        Task { await ai.prepare() }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private func bannerRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.cycleText)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cycleSurface)
            .accessibilityElement(children: .combine)
    }

    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if ai.sessionMessages.isEmpty {
                        emptyState
                    } else {
                        ForEach(ai.sessionMessages) { message in
                            bubble(message)
                                .id(message.id)
                        }
                    }
                }
                .padding(20)
                .readableContentWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: ai.sessionMessages.count) { _, _ in
                if let last = ai.sessionMessages.last {
                    scrollToLast(last.id, proxy: proxy, animated: !reduceMotion)
                }
            }
            .onChange(of: ai.sessionMessages.last?.text) { _, _ in
                if let last = ai.sessionMessages.last {
                    scrollToLast(last.id, proxy: proxy, animated: false)
                }
            }
            .onChange(of: promptFocused) { _, focused in
                guard focused, let last = ai.sessionMessages.last else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    scrollToLast(last.id, proxy: proxy, animated: !reduceMotion)
                }
            }
        }
    }

    /// Lumi starts the conversation with ideas for the current phase; tapping one asks the AI.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 10) {
                LumiView(
                    feeling: env.todayFeeling ?? env.feelingForecast?.feeling,
                    phase: env.todaysLune?.phase,
                    size: 64
                )
                Text(LuneVoice.askOpener(
                    cycleDay: env.currentCycleDay,
                    moment: env.cycleMoment,
                    experiencesPMS: env.preferences.experiencesPMS,
                    canPersonalize: !isModelMissing
                ))
                .font(.body)
                .foregroundStyle(Color.cycleText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.cycleSurface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.cycleBorder, lineWidth: 1)
                )
            }
            .accessibilityElement(children: .combine)

            if let moment = env.cycleMoment {
                ForEach(CycleTipsEngine.tips(for: moment, experiencesPMS: env.preferences.experiencesPMS)) { tip in
                    CycleTipCard(tip: tip, canAsk: !isModelMissing) {
                        Task { await ask(tip.prompt) }
                    }
                }
            }

            Text(LuneVoice.askAnything)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.cycleSecondary)
                .padding(.top, 4)
            FlowSuggestionRow(suggestions: [
                "When is my next period?",
                "Summarize my last few cycles",
            ]) { suggestion in
                ai.draft = suggestion
                promptFocused = true
            }
            .disabled(isModelMissing)
            .opacity(isModelMissing ? 0.5 : 1)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private func bubble(_ message: LocalChatMessage) -> some View {
        let isStreaming = ai.streamingAssistantID == message.id
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 48)
                bubbleText(message.text)
                    .background(
                        LinearGradient(
                            colors: [Color.cycleAccentSoft, Color.cycleCoral.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .accessibilityLabel(accessibilityLabel(for: message))
            }
        case .assistant:
            HStack(alignment: .bottom, spacing: 8) {
                // Lumi as a little sticker; her face follows the tone of the reply.
                LumiView(
                    feeling: message.text.isEmpty ? nil : LumiTone.feeling(for: message.text),
                    size: 46,
                    animated: isStreaming,
                    talking: isStreaming
                )
                .accessibilityHidden(true)
                bubbleText(message.text.isEmpty && isStreaming ? "…" : message.text)
                    .background(Color.cycleSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.cycleMagic, lineWidth: 1.5)
                    )
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "sparkle")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.cycleOvulation)
                            .offset(x: 4, y: -6)
                            .accessibilityHidden(true)
                    }
                    .accessibilityLabel(accessibilityLabel(for: message))
                Spacer(minLength: 24)
            }
        case .systemNotice:
            Label(message.text, systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(Color.cycleSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func bubbleText(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(Color.cycleText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
    }

    /// Topic chips above the text box once a chat has started, so a new idea is one tap away.
    @ViewBuilder
    private var topicChips: some View {
        if !ai.sessionMessages.isEmpty, !isModelMissing, let moment = env.cycleMoment {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CycleTipsEngine.tips(for: moment, experiencesPMS: env.preferences.experiencesPMS)) { tip in
                        Button {
                            Task { await ask(tip.prompt) }
                        } label: {
                            Text("\(tip.topic.emoji) \(tip.topic.title)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.cycleText)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 36)
                                .background(Capsule().fill(Color.cycleAccentSoft))
                        }
                        .buttonStyle(.plain)
                        .disabled(ai.isGenerating)
                        .accessibilityLabel("Ask Lumi for \(tip.topic.title.lowercased()) ideas")
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func accessibilityLabel(for message: LocalChatMessage) -> String {
        switch message.role {
        case .user: "You: \(message.text)"
        case .assistant: "Lumi: \(message.text)"
        case .systemNotice: message.text
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            topicChips
            HStack(alignment: .bottom, spacing: 10) {
                TextField(isModelMissing ? LuneVoice.aiInputDisabled : "Ask about your cycle…", text: $ai.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($promptFocused)
                    .padding(12)
                    .background(Color.cycleSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .disabled(ai.isGenerating || isModelMissing)

                Button {
                    promptFocused = false
                    Task { await send() }
                } label: {
                    Image(systemName: ai.isGenerating ? "hourglass" : "arrow.up.circle.fill")
                        .font(.system(size: sendIconSize))
                        .foregroundStyle(canSend ? Color.cycleSage : Color.cycleSecondary)
                        .opacity(canSend ? 1 : 0.35)
                }
                .cycleAccessibleTapTarget()
                .disabled(!canSend)
                .accessibilityLabel("Send")
                .accessibilityHint(canSend ? "Sends your question to Lumi" : "Enter a question to send")
            }
            Text("Not medical advice. Everything stays on this iPhone.")
                .font(.caption2)
                .foregroundStyle(Color.cycleSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .readableContentWidth()
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.cycleSurface)
        .overlay(alignment: .top) {
            Divider().overlay(Color.cycleBorder)
        }
    }

    private var canSend: Bool {
        !isModelMissing && !ai.isGenerating && !ai.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() async {
        let context = LocalHealthContextBuilder.build(
            preferences: env.preferences,
            cycles: env.cycles,
            completedCycles: env.completedCycles,
            checkIns: env.recentCheckIns,
            flows: env.recentFlows,
            prediction: env.prediction,
            insights: env.insights,
            currentCycleDay: env.currentCycleDay,
            moment: env.cycleMoment
        )
        await ai.send(userText: ai.draft, context: context)
    }

    private func ask(_ prompt: String) async {
        ai.draft = prompt
        await send()
    }

    private func scrollToLast(_ id: UUID, proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation { proxy.scrollTo(id, anchor: .bottom) }
        } else {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }
}

/// One phase tip: shows the curated idea; tapping asks Lumi for personal ones.
private struct CycleTipCard: View {
    let tip: CycleTip
    /// False until the AI model is installed; the tip still shows, without the "ask more" action.
    var canAsk = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: tip.topic.systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.cycleAccentText)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.cycleAccentSoft))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.topic.title)
                        .font(.headline)
                        .foregroundStyle(Color.cycleText)
                    Text(tip.text)
                        .font(.subheadline)
                        .foregroundStyle(Color.cycleSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if canAsk {
                        Label("Ask Lumi for more", systemImage: "sparkles")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.cycleText)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cycleSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.cycleBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        // Not `.disabled`: that would fade the tip, which is still worth reading.
        .allowsHitTesting(canAsk)
        .accessibilityElement(children: .combine)
        .accessibilityHint(canAsk ? "Asks Lumi for personal \(tip.topic.title.lowercased()) ideas" : "")
    }
}

private struct FlowSuggestionRow: View {
    let suggestions: [String]
    let onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onTap(suggestion)
                } label: {
                    Text(suggestion)
                        .font(.subheadline)
                        .foregroundStyle(Color.cycleText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .background(Color.cycleSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.cycleBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Suggestion, \(suggestion)")
                .accessibilityHint("Double tap to use this question")
            }
        }
    }
}
