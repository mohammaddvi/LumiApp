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
    - Never invent cycle dates that are not in the context.
    - Never ask for or repeat phone numbers or contact details.
    - Speak as a supportive cycle companion, not a doctor.
    - You are Lumi, a gentle, playful moon-sprite companion. Write warmly, like a caring friend: short lines or a few bullets, and 1–3 fitting emoji per reply (for example 🌙 ✨ 💜 🍵 🌿 🫶). Never use emoji for serious or worrying topics.
    - When asked for ideas (food, drinks, mood and mental health, movement, rest), give 3–4 short, practical ideas that fit the current phase and the feelings and symptoms they logged recently. General wellness only; no supplements doses, diets or medication.
    """
}

/// Owns the LiteRT-LM engine/conversation off the main actor (Conversation is not Sendable).
actor GemmaRuntime {
    private let logger = Logger(subsystem: "app.lune.tracker", category: "GemmaRuntime")
    private var engine: Engine?
    private var conversation: Conversation?
    private(set) var modelName: String?

    var isReady: Bool { conversation != nil }

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
            maxNumTokens: 4096,
            cacheDir: GemmaModelLocator.cachesDirectory.path
        )
        let newEngine = Engine(engineConfig: config)
        try await newEngine.initialize()

        let sampler = try SamplerConfig(topK: 40, topP: 0.95, temperature: 0.7)
        let conversationConfig = ConversationConfig(
            systemMessage: Message(LocalAIPrompting.systemInstructions, role: .system),
            samplerConfig: sampler
        )
        let newConversation = try await newEngine.createConversation(with: conversationConfig)

        engine = newEngine
        conversation = newConversation
        let name = modelURL.lastPathComponent + nameSuffix
        modelName = name
        return name
    }

    func resetConversation() async throws {
        guard let engine else { return }
        let sampler = try SamplerConfig(topK: 40, topP: 0.95, temperature: 0.7)
        let conversationConfig = ConversationConfig(
            systemMessage: Message(LocalAIPrompting.systemInstructions, role: .system),
            samplerConfig: sampler
        )
        conversation = try await engine.createConversation(with: conversationConfig)
    }

    /// Streams text chunks; `onChunk` is invoked on the main actor.
    func streamReply(
        prompt: String,
        onChunk: @MainActor @escaping (String) -> Void
    ) async throws {
        guard let conversation else {
            throw LocalAIError.notReady
        }
        for try await chunk in conversation.sendMessageStream(Message(prompt)) {
            let piece = chunk.toString
            if !piece.isEmpty {
                await onChunk(piece)
            }
        }
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
    /// The visible conversation. Kept across launches (saved on device with complete file protection)
    /// until "New chat"; only bubbles, while `memory` is the clipped context fed to the model.
    private(set) var sessionMessages: [LocalChatMessage] = []
    /// Hidden on-device memory used as future prompt context.
    private(set) var memory: [LocalChatMessage] = []
    private(set) var isGenerating = false
    private(set) var streamingAssistantID: UUID?

    var draft = ""

    /// Kept for call sites that still say `messages` (delete-all / empty checks).
    var hasMemory: Bool { !memory.isEmpty }

    private static let maxMemoryMessages = 40
    private static let maxMemoryCharsPerNote = 500
    private static let maxVisibleMessages = 80

    private var historyURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LuneAI", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("chat-memory.json")
    }

    private var sessionURL: URL {
        historyURL.deletingLastPathComponent().appendingPathComponent("chat-visible.json")
    }

    init() {
        loadMemory()
        loadSession()
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
        if case .loading = status { return }

        GemmaModelLocator.ensureDirectories()
        guard let modelURL = GemmaModelLocator.resolveModelURL() else {
            status = .modelMissing(expectedName: GemmaModelLocator.preferredFileNames[0])
            return
        }

        status = .loading
        do {
            let name = try await runtime.prepare(modelURL: modelURL)
            status = .ready(modelName: name)
            logger.info("Local Gemma ready: \(name, privacy: .public)")
        } catch {
            logger.error("Gemma init failed: \(error.localizedDescription, privacy: .public)")
            status = .failed(error.localizedDescription)
        }
    }

    /// Clears the visible turn and wipes private memory (privacy).
    func forgetConversation() {
        sessionMessages.removeAll()
        saveSession()
        memory.removeAll()
        saveMemory()
        Task {
            do {
                try await runtime.resetConversation()
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    /// Alias used by delete-all / older call sites.
    func clearChat() {
        forgetConversation()
    }

    /// Starts a fresh visible chat; Lumi still remembers earlier conversations as private context.
    func startNewChat() {
        guard !isGenerating else { return }
        sessionMessages.removeAll()
        saveSession()
    }

    #if DEBUG
    /// Sample Ask MyLune thread for App Store screenshots (no on-device model required).
    func seedDemoConversationForScreenshots() {
        status = .ready(modelName: "Gemma 4 (on-device)")
        sessionMessages = [
            LocalChatMessage(
                role: .user,
                text: "I’m in my Glow phase — any gentle tips for energy?"
            ),
            LocalChatMessage(
                role: .assistant,
                text: "Glow days can feel so bright ✨ Your logs show steadier energy after your period, so:\n• keep meals regular and colorful 🍓\n• sip water through the day 💧\n• save harder workouts for your high-energy days 💜"
            ),
        ]
    }
    #endif

    func send(userText: String, context: LocalHealthContext) async {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isGenerating else { return }

        if case .ready = status {
            // ok
        } else {
            await prepare()
        }
        guard status.isReady, await runtime.isReady else {
            // Add the notice; never wipe the conversation.
            sessionMessages.removeAll { $0.role == .systemNotice }
            sessionMessages.append(LocalChatMessage(
                role: .systemNotice,
                text: "Lumi's AI isn't ready yet. Download it in Settings → AI, then try again."
            ))
            saveSession()
            return
        }

        draft = ""
        let userMessage = LocalChatMessage(role: .user, text: trimmed)
        let assistantID = UUID()
        sessionMessages.append(userMessage)
        sessionMessages.append(LocalChatMessage(id: assistantID, role: .assistant, text: ""))
        streamingAssistantID = assistantID
        isGenerating = true

        let prompt = buildPrompt(userQuestion: trimmed, cycleContext: context)

        defer {
            isGenerating = false
            streamingAssistantID = nil
            if let assistant = sessionMessages.first(where: { $0.id == assistantID }) {
                appendToMemory(user: userMessage, assistant: assistant)
            }
            saveSession()
        }

        do {
            try await runtime.streamReply(prompt: prompt) { [weak self] piece in
                self?.appendStreamingText(assistantID: assistantID, text: piece)
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

    private func buildPrompt(userQuestion: String, cycleContext: LocalHealthContext) -> String {
        var parts: [String] = []

        let memoryBlock = memoryPromptBlock()
        if !memoryBlock.isEmpty {
            parts.append(
                """
                Prior conversation memory (stored on this device for continuity; the user is not browsing this archive — use it when relevant):
                \(memoryBlock)
                """
            )
        }

        parts.append(
            """
            Local cycle context (on this device only; do not claim data outside this block):
            \(cycleContext.promptBlock)

            User question:
            \(userQuestion)
            """
        )

        return parts.joined(separator: "\n\n")
    }

    private func memoryPromptBlock() -> String {
        memory
            .filter { $0.role == .user || $0.role == .assistant }
            .map { message in
                let label = message.role == .user ? "User" : "Lumi"
                let text = clipped(message.text)
                return "\(label): \(text)"
            }
            .joined(separator: "\n")
    }

    private func clipped(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= Self.maxMemoryCharsPerNote { return trimmed }
        return String(trimmed.prefix(Self.maxMemoryCharsPerNote - 1)) + "…"
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

    private func loadSession() {
        guard let data = try? Data(contentsOf: sessionURL),
              let decoded = try? JSONDecoder().decode([LocalChatMessage].self, from: data)
        else { return }
        sessionMessages = decoded.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func saveSession() {
        let kept = Array(sessionMessages.suffix(Self.maxVisibleMessages))
        guard let data = try? JSONEncoder().encode(kept) else { return }
        try? data.write(to: sessionURL, options: [.atomic, .completeFileProtection])
    }

    private func saveMemory() {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        try? data.write(to: historyURL, options: [.atomic, .completeFileProtection])
    }
}
