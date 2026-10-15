import Foundation
@preconcurrency import LiteRTLM
import OSLog

enum LocalAIPrompting {
    static let systemInstructions = """
    You are Lumi, the on-device companion in the Lumi app for menstrual cycle tracking.
    You run fully offline using Gemma. The user’s health data never leaves this iPhone.

    Rules:
    - Answer only from the provided local cycle context, prior conversation memory, and general wellness knowledge.
    - Use prior conversation memory for continuity (names they used for symptoms, follow-ups, preferences they stated). Do not quote the memory block back unless helpful.
    - Do not diagnose medical conditions, prescribe treatments, or claim clinical certainty.
    - If something sounds urgent or concerning, gently suggest contacting a clinician.
    - Prefer short, calm, practical answers.
    - For any date question (next period, ovulation, PMS), use the "Key dates" in the context exactly and say they are estimates. Never invent or calculate other cycle dates.
    - Always reply in the same language the user writes in.
    - Never ask for or repeat phone numbers or contact details.
    - Speak as a supportive cycle companion, not a doctor.
    - You are Lumi, a gentle, playful moon-sprite companion. Write warmly, like a caring friend: short lines or a few bullets, and 1–3 fitting emoji per reply (for example 🌙 ✨ 💜 🍵 🌿 🫶). Never use emoji for serious or worrying topics.
    - When asked for ideas (food, drinks, mood and mental health, movement, rest), give 3–4 short, practical ideas that fit the current phase and the feelings and symptoms they logged recently. General wellness only; no supplements doses, diets or medication.
    """
}

/// One earlier turn handed to a new conversation so it can carry on where the last one stopped.
struct GemmaTurn: Sendable, Equatable {
    let fromUser: Bool
    let text: String
}

/// Owns the LiteRT-LM engine/conversation off the main actor (Conversation is not Sendable).
///
/// A chat is one real conversation, so Gemma remembers what was said. Its KV cache holds
/// `maxNumTokens` in total, so the runtime keeps a rough count and the controller starts a new
/// conversation, seeded with the latest turns, before the cache would overflow.
actor GemmaRuntime {
    private let logger = Logger(subsystem: "app.lune.tracker", category: "GemmaRuntime")
    private var engine: Engine?
    private var conversation: Conversation?
    private(set) var modelName: String?
    /// Rough count of tokens already in the conversation's KV cache.
    private(set) var estimatedTokensUsed = 0

    /// Total tokens per conversation (prompts + replies); also the KV-cache size.
    static let maxNumTokens = 4096
    static let maxReplyTokens = 600
    /// Kept free for the chat template and estimate error.
    static let safetyTokens = 300

    var isReady: Bool { engine != nil }
    var hasConversation: Bool { conversation != nil }

    /// Conservative estimate: about 3 UTF-8 bytes per token, so non-Latin scripts count higher.
    static func estimatedTokens(_ text: String) -> Int { text.utf8.count / 3 + 8 }

    /// Whether `message` and a full reply still fit in the current conversation.
    func fits(_ message: String) -> Bool {
        conversation != nil
            && estimatedTokensUsed + Self.estimatedTokens(message) + Self.maxReplyTokens + Self.safetyTokens
                <= Self.maxNumTokens
    }

    func prepare(modelURL: URL) async throws -> String {
        do {
            return try await start(modelURL: modelURL, backend: .gpu)
        } catch {
            logger.error("GPU init failed, trying CPU: \(error.localizedDescription, privacy: .public)")
            return try await start(modelURL: modelURL, backend: .cpu(threadCount: 4), nameSuffix: " · CPU")
        }
    }

    private func start(modelURL: URL, backend: Backend, nameSuffix: String = "") async throws -> String {
        let config = try EngineConfig(
            modelPath: modelURL.path,
            backend: backend,
            maxNumTokens: Self.maxNumTokens,
            cacheDir: GemmaModelLocator.cachesDirectory.path
        )
        let newEngine = Engine(engineConfig: config)
        try await newEngine.initialize()
        // Make sure the model can hold a conversation before calling it ready.
        _ = try await newEngine.createConversation(with: ConversationConfig(
            systemMessage: Message(LocalAIPrompting.systemInstructions, role: .system)
        ))

        engine = newEngine
        conversation = nil
        estimatedTokensUsed = 0
        let name = modelURL.lastPathComponent + nameSuffix
        modelName = name
        return name
    }

    /// Starts a new conversation with `systemPrompt`, continuing from `history` (oldest first).
    func startConversation(system systemPrompt: String, history: [GemmaTurn]) async throws {
        guard let engine else { throw LocalAIError.notReady }
        conversation = nil // free the old KV cache first
        let sampler = try SamplerConfig(topK: 40, topP: 0.95, temperature: 0.7)
        let config = ConversationConfig(
            systemMessage: Message(systemPrompt, role: .system),
            initialMessages: history.map { Message($0.text, role: $0.fromUser ? .user : .model) },
            samplerConfig: sampler
        )
        conversation = try await engine.createConversation(with: config)
        estimatedTokensUsed = Self.estimatedTokens(systemPrompt)
            + history.reduce(0) { $0 + Self.estimatedTokens($1.text) }
    }

    func endConversation() {
        conversation = nil
        estimatedTokensUsed = 0
    }

    /// Streams text chunks; `onChunk` is invoked on the main actor. A failed reply ends the
    /// conversation so the next message starts a fresh one.
    func streamReply(
        message: String,
        onChunk: @MainActor @escaping (String) -> Void
    ) async throws {
        guard let conversation else {
            throw LocalAIError.notReady
        }
        estimatedTokensUsed += Self.estimatedTokens(message)
        var reply = ""
        do {
            for try await chunk in conversation.sendMessageStream(Message(message), maxOutputTokens: Self.maxReplyTokens) {
                let piece = chunk.toString
                if !piece.isEmpty {
                    reply += piece
                    await onChunk(piece)
                }
            }
        } catch {
            endConversation()
            throw error
        }
        estimatedTokensUsed += Self.estimatedTokens(reply)
    }
}

/// Runs Google Gemma via LiteRT-LM entirely on-device. No network calls.
///
/// Past chats are stored as private memory for the model, not shown as a browsable history.
@MainActor
@Observable
final class LocalAIController {
    private let logger = Logger(subsystem: "app.lune.tracker", category: "LocalAI")
    private let runtime = GemmaRuntime()

    private(set) var status: LocalAIStatus = .checking
    /// The visible conversation, kept in memory only: it survives switching apps but resets when the
    /// app is closed (a fresh launch starts a new chat). `memory` is the clipped context fed to the model.
    private(set) var sessionMessages: [LocalChatMessage] = []
    /// Hidden on-device memory used as future prompt context.
    private(set) var memory: [LocalChatMessage] = []
    private(set) var isGenerating = false
    private(set) var streamingAssistantID: UUID?
    /// The model load in progress, so everyone who needs the model waits for the same one.
    private var loadTask: Task<Void, Never>?

    var draft = ""

    /// Kept for call sites that still say `messages` (delete-all / empty checks).
    var hasMemory: Bool { !memory.isEmpty }

    private static let maxMemoryMessages = 40
    private static let maxMemoryCharsPerNote = 500
    /// Earlier chats given to a new conversation, shortened, so the start fits the token budget.
    private static let promptMemoryMessages = 6
    private static let promptMemoryCharsPerNote = 280
    /// Latest turns of this chat carried into a new conversation when the old one is full.
    private static let carriedTurns = 6
    private static let carriedCharsPerTurn = 400

    /// Cycle context the current model conversation knows; sent again mid-chat if it changes.
    private var conversationContext: String?

    private var historyURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LuneAI", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("chat-memory.json")
    }

    /// Where an earlier build saved the visible chat; removed at launch so nothing lingers on disk.
    private var legacySessionURL: URL {
        historyURL.deletingLastPathComponent().appendingPathComponent("chat-visible.json")
    }

    init() {
        loadMemory()
        try? FileManager.default.removeItem(at: legacySessionURL)
    }

    func refreshModelAvailability() {
        #if DEBUG
        if AppStoreScreenshotMode.isEnabled, case .ready = status { return }
        #endif
        if case .ready = status { return }
        if case .loading = status { return }
        if GemmaModelLocator.resolveModelURL() == nil {
            status = .modelMissing(expectedName: GemmaModelLocator.preferredFileNames[0])
        } else {
            status = .checking
        }
    }

    func prepare() async {
        #if DEBUG
        if AppStoreScreenshotMode.isEnabled, case .ready = status { return }
        #endif
        if case .ready = status, await runtime.isReady { return }
        // Already loading (opening Ask starts it): wait for that load instead of giving up.
        if let loadTask {
            await loadTask.value
            return
        }

        GemmaModelLocator.ensureDirectories()
        guard let modelURL = GemmaModelLocator.resolveModelURL() else {
            status = .modelMissing(expectedName: GemmaModelLocator.preferredFileNames[0])
            return
        }

        status = .loading
        let task = Task {
            do {
                let name = try await runtime.prepare(modelURL: modelURL)
                status = .ready(modelName: name)
                logger.info("Local Gemma ready: \(name, privacy: .public)")
            } catch {
                logger.error("Gemma init failed: \(error.localizedDescription, privacy: .public)")
                status = .failed(error.localizedDescription)
            }
        }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// What Lumi says when she can't answer, matching the real reason.
    private var notReadyNotice: String {
        switch status {
        case .modelMissing: "Download Lumi's AI in Settings → AI first, then ask again."
        case .failed: "Lumi's AI couldn't start this time. Try again in a moment."
        default: "Lumi's AI is still waking up. Try again in a moment."
        }
    }

    /// Clears the visible turn and wipes private memory (privacy).
    func forgetConversation() {
        sessionMessages.removeAll()
        memory.removeAll()
        saveMemory()
        endModelConversation()
    }

    /// Alias used by delete-all / older call sites.
    func clearChat() {
        forgetConversation()
    }

    /// Adds a ready-made reply (built-in tips, predicted dates) that needs no model, so Lumi's
    /// topic chips work before the AI is downloaded too.
    func addLocalExchange(question: String, answer: String) {
        guard !isGenerating else { return }
        sessionMessages.removeAll { $0.role == .systemNotice }
        sessionMessages.append(LocalChatMessage(role: .user, text: question))
        sessionMessages.append(LocalChatMessage(role: .assistant, text: answer))
    }

    /// Starts a fresh visible chat; Lumi still remembers earlier conversations as private context.
    func startNewChat() {
        guard !isGenerating else { return }
        sessionMessages.removeAll()
        endModelConversation()
    }

    private func endModelConversation() {
        conversationContext = nil
        Task { await runtime.endConversation() }
    }

    #if DEBUG
    /// Sample Ask Lumi thread for App Store screenshots (no on-device model required).
    func seedDemoConversationForScreenshots() {
        status = .ready(modelName: "Gemma 4 (on-device)")
        sessionMessages = [
            LocalChatMessage(
                role: .user,
                text: "I’m in my Glow phase — any gentle tips for energy?"
            ),
            LocalChatMessage(
                role: .assistant,
                text: "Glow days can feel so bright ✨ Your logs show steadier energy after your period, so:\n* **Meals:** regular and colorful 🍓\n* **Water:** sip through the day 💧\n* **Workouts:** save harder ones for high-energy days 💜"
            ),
        ]
    }
    #endif

    func send(userText: String, context: LocalHealthContext) async {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isGenerating else { return }

        // Show the message and Lumi's typing bubble right away, even if the model is still loading.
        draft = ""
        let userMessage = LocalChatMessage(role: .user, text: trimmed)
        let assistantID = UUID()
        sessionMessages.removeAll { $0.role == .systemNotice }
        sessionMessages.append(userMessage)
        sessionMessages.append(LocalChatMessage(id: assistantID, role: .assistant, text: ""))
        streamingAssistantID = assistantID
        isGenerating = true

        let isReady = status.isReady ? await runtime.isReady : false
        if !isReady {
            await prepare()
        }
        let canAnswer = status.isReady ? await runtime.isReady : false
        guard canAnswer else {
            // Explain why instead of a reply; never wipe the conversation.
            sessionMessages.removeAll { $0.id == assistantID }
            sessionMessages.append(LocalChatMessage(role: .systemNotice, text: notReadyNotice))
            isGenerating = false
            streamingAssistantID = nil
            return
        }

        defer {
            isGenerating = false
            streamingAssistantID = nil
            if let assistant = sessionMessages.first(where: { $0.id == assistantID }) {
                appendToMemory(user: userMessage, assistant: assistant)
            }
        }

        do {
            do {
                try await reply(to: trimmed, context: context, assistantID: assistantID)
            } catch {
                // Usually the model ran out of room: start over from the recent turns and try once more.
                logger.error("Inference failed, retrying in a new conversation: \(error.localizedDescription, privacy: .public)")
                conversationContext = nil
                if let idx = sessionMessages.firstIndex(where: { $0.id == assistantID }) {
                    sessionMessages[idx].text = ""
                }
                try await reply(to: trimmed, context: context, assistantID: assistantID)
            }
            if let idx = sessionMessages.firstIndex(where: { $0.id == assistantID }),
               sessionMessages[idx].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sessionMessages[idx].text = "I couldn’t generate a reply. Try again in a moment."
            }
        } catch {
            if let idx = sessionMessages.firstIndex(where: { $0.id == assistantID }) {
                sessionMessages[idx].text = "Local inference error: \(error.localizedDescription)"
            }
            logger.error("Inference failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Sends `question` in the ongoing model conversation, starting a new one (seeded with the
    /// latest turns of this chat) when there is none yet or it is too full for another exchange.
    private func reply(to question: String, context: LocalHealthContext, assistantID: UUID) async throws {
        var message = question
        let hasConversation = await runtime.hasConversation
        if hasConversation, conversationContext != context.promptBlock {
            message = """
            Updated cycle context (use this from now on):
            \(context.promptBlock)

            User question:
            \(question)
            """
        }
        if !(await runtime.fits(message)) {
            let system = systemPrompt(context: context)
            try await runtime.startConversation(system: system, history: carriedTurns(excluding: assistantID))
            message = question
            if !(await runtime.fits(message)) {
                try await runtime.startConversation(system: system, history: [])
            }
        }
        conversationContext = context.promptBlock
        try await runtime.streamReply(message: message) { [weak self] piece in
            self?.appendStreamingText(assistantID: assistantID, text: piece)
        }
    }

    /// Rules, short memory of earlier chats, and the cycle context: what a new conversation starts from.
    private func systemPrompt(context: LocalHealthContext) -> String {
        var parts = [LocalAIPrompting.systemInstructions]
        let memoryBlock = memoryPromptBlock()
        if !memoryBlock.isEmpty {
            parts.append(
                """
                Memory of earlier chats (stored on this device for continuity; use it when relevant; if it disagrees with the cycle context below, the cycle context is right):
                \(memoryBlock)
                """
            )
        }
        parts.append(
            """
            Local cycle context (on this device only; do not claim data outside this block):
            \(context.promptBlock)
            """
        )
        return parts.joined(separator: "\n\n")
    }

    /// The latest finished turns of this chat (not the question being answered), oldest first.
    private func carriedTurns(excluding assistantID: UUID) -> [GemmaTurn] {
        let finished = sessionMessages.filter { message in
            (message.role == .user || message.role == .assistant)
                && message.id != assistantID
                && !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !message.text.hasPrefix("Local inference error:")
        }
        // Drop the question being answered; it is sent as the new message.
        var turns = Array(finished.dropLast().suffix(Self.carriedTurns))
        // A conversation's history should start with the user.
        while turns.first?.role == .assistant { turns.removeFirst() }
        return turns.map {
            GemmaTurn(fromUser: $0.role == .user, text: clipped($0.text, to: Self.carriedCharsPerTurn))
        }
    }

    private func memoryPromptBlock() -> String {
        let inThisChat = Set(sessionMessages.map(\.id))
        return memory
            .filter { ($0.role == .user || $0.role == .assistant) && !inThisChat.contains($0.id) }
            .suffix(Self.promptMemoryMessages)
            .map { message in
                let label = message.role == .user ? "User" : "Lumi"
                let text = clipped(message.text, to: Self.promptMemoryCharsPerNote)
                return "\(label): \(text)"
            }
            .joined(separator: "\n")
    }

    private func clipped(_ text: String, to limit: Int = maxMemoryCharsPerNote) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= limit { return trimmed }
        return String(trimmed.prefix(limit - 1)) + "…"
    }

    private func appendToMemory(user: LocalChatMessage, assistant: LocalChatMessage) {
        let assistantText = assistant.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !assistantText.isEmpty else { return }
        // Don't memorize pure error notices as lasting context.
        if assistantText.hasPrefix("Local inference error:") { return }

        memory.append(user)
        memory.append(
            LocalChatMessage(id: assistant.id, role: .assistant, text: clipped(assistantText), createdAt: assistant.createdAt)
        )
        if memory.count > Self.maxMemoryMessages {
            memory = Array(memory.suffix(Self.maxMemoryMessages))
        }
        saveMemory()
    }

    private func appendStreamingText(assistantID: UUID, text: String) {
        guard let idx = sessionMessages.firstIndex(where: { $0.id == assistantID }) else { return }
        sessionMessages[idx].text += text
    }

    private func loadMemory() {
        // Prefer new file; migrate old chat-history.json once if present.
        let legacy = historyURL.deletingLastPathComponent().appendingPathComponent("chat-history.json")
        let url = FileManager.default.fileExists(atPath: historyURL.path) ? historyURL : legacy
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([LocalChatMessage].self, from: data)
        else { return }
        memory = decoded
            .filter { $0.role == .user || $0.role == .assistant }
            .suffix(Self.maxMemoryMessages)
            .map { message in
                LocalChatMessage(
                    id: message.id,
                    role: message.role,
                    text: clipped(message.text),
                    createdAt: message.createdAt
                )
            }
        saveMemory()
        if url != historyURL {
            try? FileManager.default.removeItem(at: legacy)
        }
    }



    private func saveMemory() {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        try? data.write(to: historyURL, options: [.atomic, .completeFileProtection])
    }
}
