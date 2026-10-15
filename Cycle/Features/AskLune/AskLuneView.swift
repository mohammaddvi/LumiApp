import SwiftUI

struct AskLuneView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable private var ai: LocalAIController
    @FocusState private var promptFocused: Bool
    /// Height of the visible chat, so the latest exchange can fill a screen and its question can sit at the top.
    @State private var viewportHeight: CGFloat = 0

    private static let latestTurnID = "latestTurn"
    private static let chatPadding: CGFloat = 20
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
            .fantasySkyBackground()
            // No title: the tab already says Ask, and Lumi greets you right below.
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !ai.sessionMessages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            ai.startNewChat()
                        } label: {
                            Label("Reset chat", systemImage: "arrow.counterclockwise")
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
        case .ready, .modelMissing:
            // Missing model: the text box itself says to download it, so no second banner.
            EmptyView()
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
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.cycleSurface, in: Capsule())
            .overlay(Capsule().stroke(Color.cycleBorder, lineWidth: 1))
            .padding(.top, 6)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
    }

    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if ai.sessionMessages.isEmpty {
                        emptyState
                    } else {
                        let messages = ai.sessionMessages
                        let split = messages.lastIndex { $0.role == .user } ?? messages.count
                        ForEach(messages[..<split]) { message in
                            bubble(message)
                                .id(message.id)
                        }
                        if split < messages.count {
                            // Your latest message and Lumi's reply fill at least a screen, so the
                            // message can scroll to the top while the reply types out below it.
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(messages[split...]) { message in
                                    bubble(message)
                                        .id(message.id)
                                }
                            }
                            .frame(
                                maxWidth: .infinity,
                                minHeight: max(0, viewportHeight - Self.chatPadding * 2),
                                alignment: .topLeading
                            )
                            .id(Self.latestTurnID)
                        }
                    }
                }
                .padding(Self.chatPadding)
                .readableContentWidth()
            }
            .scrollDismissesKeyboard(.interactively)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { viewportHeight = $0 }
            .onChange(of: ai.sessionMessages.count) { _, _ in
                showLatestTurn(proxy: proxy, animated: !reduceMotion)
            }
            .onChange(of: promptFocused) { _, focused in
                guard focused else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    showLatestTurn(proxy: proxy, animated: !reduceMotion)
                }
            }
        }
    }

    /// Lumi in the middle with a short hello, and one row of topics to start from.
    private var emptyState: some View {
        VStack(spacing: 16) {
            LumiView(
                feeling: env.todayFeeling ?? env.feelingForecast?.feeling,
                phase: env.todaysLune?.phase,
                size: 120
            )
            .accessibilityHidden(true)
            Text(LuneVoice.askOpener(
                cycleDay: env.currentCycleDay,
                moment: env.cycleMoment,
                experiencesPMS: env.preferences.experiencesPMS,
                name: env.preferences.userName
            ))
            .font(.system(.body, design: .rounded).weight(.medium))
            .foregroundStyle(Color.cycleText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.cycleSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.cycleBorder, lineWidth: 1)
            )
            ChipFlow(spacing: 8) {
                ForEach(chips) { chip in
                    chipButton(chip)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
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
                bubbleText(message.text.isEmpty && isStreaming ? "…" : message.text, styled: true)
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

    /// `styled` renders the Markdown in Lumi's replies (bold, bullets); your own messages stay as typed.
    private func bubbleText(_ text: String, styled: Bool = false) -> some View {
        Text(styled ? LumiMarkdown.attributed(text) : AttributedString(text))
            .font(.body)
            .foregroundStyle(Color.cycleText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
    }

    /// Topic chips above the text box once a chat has started, so a new idea is one tap away.
    @ViewBuilder
    private var topicChips: some View {
        if !ai.sessionMessages.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips) { chip in
                        chipButton(chip)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    /// Something to ask Lumi in one tap: a wellness topic for today's phase, or the next period.
    private struct Chip: Identifiable {
        let id: String
        let label: String
        /// What the AI is asked.
        let prompt: String
        /// Lumi's built-in answer when the AI isn't downloaded.
        let offlineAnswer: String
    }

    private var chips: [Chip] {
        var chips: [Chip] = []
        if let moment = env.cycleMoment {
            chips = CycleTipsEngine.tips(for: moment, experiencesPMS: env.preferences.experiencesPMS).map { tip in
                Chip(id: tip.topic.rawValue, label: "\(tip.topic.emoji) \(tip.topic.title)", prompt: tip.prompt, offlineAnswer: tip.text)
            }
        }
        chips.append(Chip(
            id: "nextPeriod",
            label: "🔮 Next period",
            prompt: "When is my next period?",
            offlineAnswer: LuneVoice.nextPeriodAnswer(env.prediction?.predictedDate)
        ))
        return chips
    }

    private func chipButton(_ chip: Chip) -> some View {
        Button {
            if isModelMissing {
                ai.addLocalExchange(question: chip.label, answer: chip.offlineAnswer)
            } else {
                Task { await ask(chip.prompt) }
            }
        } label: {
            Text(chip.label)
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color.cycleText)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(Capsule().fill(Color.cycleSurface))
                .overlay(Capsule().stroke(Color.cycleBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(ai.isGenerating)
        .accessibilityHint("Asks Lumi")
    }

    private func accessibilityLabel(for message: LocalChatMessage) -> String {
        switch message.role {
        case .user: "You: \(message.text)"
        case .assistant: "Lumi: \(LumiMarkdown.plain(message.text))"
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
            Text("Not medical advice · stays on this iPhone")
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
            moment: env.cycleMoment,
            outlook: env.cycleOutlook
        )
        await ai.send(userText: ai.draft, context: context)
    }

    private func ask(_ prompt: String) async {
        ai.draft = prompt
        await send()
    }

    /// Puts your latest message at the top; without one (only a notice), shows the newest message.
    private func showLatestTurn(proxy: ScrollViewProxy, animated: Bool) {
        let hasTurn = ai.sessionMessages.contains { $0.role == .user }
        let scroll = {
            if hasTurn {
                proxy.scrollTo(Self.latestTurnID, anchor: .top)
            } else if let last = ai.sessionMessages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
        if animated {
            withAnimation(.smooth(duration: 0.35)) { scroll() }
        } else {
            scroll()
        }
    }
}

/// Chips that wrap onto new lines, centered, like words in a sentence.
private struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX + (bounds.width - row.width) / 2
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
