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
            .navigationTitle("Ask Lune")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        promptFocused = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.cycleSage)
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

    private var statusBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(ai.status.statusLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.cycleText)
                Spacer()
                if case .modelMissing = ai.status {
                    Button("Retry") {
                        Task { await ai.prepare() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cycleSage)
                } else if case .failed = ai.status {
                    Button("Retry") {
                        Task { await ai.prepare() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.cycleSage)
                }
            }
            Text("Answers use your on-device logs with Gemma 4. Nothing is uploaded.")
                .font(.footnote)
                .foregroundStyle(Color.cycleSecondary)
            if case .modelMissing(let name) = ai.status {
                Text("Download \(name) in Settings → Local AI, or add it under Files → On My iPhone → Lune → Models.")
                    .font(.footnote)
                    .foregroundStyle(Color.cycleSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cycleSurface)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Local AI status, \(ai.status.statusLabel)")
    }

    private var statusColor: Color {
        switch ai.status {
        case .ready: Color.cycleSage
        case .loading, .checking: Color.cycleSage
        case .modelMissing, .failed: Color.cycleSecondary
        }
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
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ask lune anything")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.cycleText)
                .accessibilityAddTraits(.isHeader)
            Text("past questions stay on your phone as private context. chat clears when you leave the app — lune still remembers.")
                .font(.body)
                .foregroundStyle(Color.cycleSecondary)
            FlowSuggestionRow(suggestions: [
                "when's my reset coming?",
                "what signals show up before my period?",
                "summarize my last few cycles",
            ]) { suggestion in
                ai.draft = suggestion
                promptFocused = true
            }
        }
        .padding(.top, 8)
    }

    private func bubble(_ message: LocalChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 36) }
            Text(message.text.isEmpty && ai.streamingAssistantID == message.id ? "…" : message.text)
                .font(.body)
                .foregroundStyle(Color.cycleText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground(message.role))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(bubbleBorder(message.role))
                .accessibilityLabel(accessibilityLabel(for: message))
            if message.role != .user { Spacer(minLength: 36) }
        }
    }

    private func bubbleBackground(_ role: LocalChatMessage.Role) -> Color {
        switch role {
        case .user: Color.cycleAccentSoft
        case .assistant: Color.cycleSurface
        case .systemNotice: Color.cycleAccentSoft
        }
    }

    @ViewBuilder
    private func bubbleBorder(_ role: LocalChatMessage.Role) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(role == .user ? Color.cycleCoral.opacity(0.75) : Color.cycleBorder, lineWidth: 1)
    }

    private func accessibilityLabel(for message: LocalChatMessage) -> String {
        switch message.role {
        case .user: "You: \(message.text)"
        case .assistant: "Lune: \(message.text)"
        case .systemNotice: message.text
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask about your cycle…", text: $ai.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($promptFocused)
                    .padding(12)
                    .background(Color.cycleSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .disabled(ai.isGenerating)

                Button {
                    promptFocused = false
                    Task { await send() }
                } label: {
                    Image(systemName: ai.isGenerating ? "hourglass" : "arrow.up.circle.fill")
                        .font(.system(size: sendIconSize))
                        .foregroundStyle(canSend ? Color.cycleSage : Color.cycleSecondary)
                }
                .cycleAccessibleTapTarget()
                .disabled(!canSend)
                .accessibilityLabel("Send")
                .accessibilityHint(canSend ? "Sends your question to Lune" : "Enter a question to send")
            }
            Text("Not medical advice. Grounded only in data stored on this device.")
                .font(.caption2)
                .foregroundStyle(Color.cycleSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.cycleSurface)
        .overlay(alignment: .top) {
            Divider().overlay(Color.cycleBorder)
        }
    }

    private var canSend: Bool {
        !ai.isGenerating && !ai.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            currentCycleDay: env.currentCycleDay
        )
        await ai.send(userText: ai.draft, context: context)
    }

    private func scrollToLast(_ id: UUID, proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation { proxy.scrollTo(id, anchor: .bottom) }
        } else {
            proxy.scrollTo(id, anchor: .bottom)
        }
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
