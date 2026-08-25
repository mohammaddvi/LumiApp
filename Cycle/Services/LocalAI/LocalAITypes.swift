import Foundation

enum LocalAIStatus: Equatable, Sendable {
    case checking
    case modelMissing(expectedName: String)
    case loading
    case ready(modelName: String)
    case failed(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var statusLabel: String {
        switch self {
        case .checking: "Checking for local model…"
        case .modelMissing: "Gemma model not installed"
        case .loading: "Loading Gemma on device…"
        case .ready(let name): "Ready · \(name)"
        case .failed(let message): "Unavailable · \(message)"
        }
    }
}

struct LocalChatMessage: Identifiable, Hashable, Codable, Sendable {
    enum Role: String, Codable, Sendable {
        case user
        case assistant
        case systemNotice
    }

    let id: UUID
    let role: Role
    var text: String
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, text: String, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

enum LocalAIError: LocalizedError {
    case modelNotFound
    case notReady
    case emptyPrompt
    case inference(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            "Place a Gemma 4 `.litertlm` file in the app’s Models folder or app bundle."
        case .notReady:
            "Local AI isn’t ready yet."
        case .emptyPrompt:
            "Ask a question first."
        case .inference(let message):
            message
        }
    }
}

enum GemmaModelLocator {
    static let preferredFileNames = [
        "gemma-4-E2B-it.litertlm",
        "gemma-4-E2B-it-q8.litertlm",
        "gemma-4-E2B-it-q4.litertlm",
    ]

    /// Writable folder where the user (or a future download helper) can drop the model.
    static var documentsModelsDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Models", isDirectory: true)
    }

    static var cachesDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    static func ensureDirectories() {
        try? FileManager.default.createDirectory(
            at: documentsModelsDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Resolves the first available Gemma LiteRT-LM model file.
    static func resolveModelURL() -> URL? {
        ensureDirectories()
        let fm = FileManager.default

        for name in preferredFileNames {
            let docs = documentsModelsDirectory.appendingPathComponent(name)
            if fm.fileExists(atPath: docs.path) { return docs }
        }

        if let contents = try? fm.contentsOfDirectory(
            at: documentsModelsDirectory,
            includingPropertiesForKeys: nil
        ) {
            if let match = contents.first(where: {
                $0.pathExtension.lowercased() == "litertlm"
                    && $0.lastPathComponent.lowercased().contains("gemma")
            }) {
                return match
            }
            if let any = contents.first(where: { $0.pathExtension.lowercased() == "litertlm" }) {
                return any
            }
        }

        for name in preferredFileNames {
            let stem = (name as NSString).deletingPathExtension
            if let path = Bundle.main.path(forResource: stem, ofType: "litertlm") {
                return URL(fileURLWithPath: path)
            }
        }

        if let urls = Bundle.main.urls(forResourcesWithExtension: "litertlm", subdirectory: nil),
           let first = urls.first {
            return first
        }

        return nil
    }
}
