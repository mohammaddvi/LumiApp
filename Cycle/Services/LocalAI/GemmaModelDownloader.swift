import Foundation
import Observation

/// Downloads the on-device Gemma 4 LiteRT-LM weights into Documents/Models.
@MainActor
@Observable
final class GemmaModelDownloader {
    enum State: Equatable {
        case idle
        case downloading(fraction: Double, bytesWritten: Int64, bytesExpected: Int64)
        case finishing
        case ready(fileName: String, byteCount: Int64)
        case failed(String)

        var isDownloading: Bool {
            if case .downloading = self { return true }
            if case .finishing = self { return true }
            return false
        }
    }

    static let fileName = "gemma-4-E2B-it.litertlm"
    static let remoteURL = URL(
        string: "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm"
    )!
    /// Approximate size used for free-space checks and UI copy (~2.59 GB).
    static let approximateByteCount: Int64 = 2_590_000_000
    /// Require a little more free space than the model size for temp + final copy.
    static let requiredFreeBytes: Int64 = 3_200_000_000

    private(set) var state: State = .idle
    private(set) var installedByteCount: Int64?

    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var delegateProxy: DownloadDelegateProxy?
    private var continuation: CheckedContinuation<URL, Error>?

    var isModelInstalled: Bool {
        GemmaModelLocator.resolveModelURL() != nil
    }

    var installedFileName: String? {
        GemmaModelLocator.resolveModelURL()?.lastPathComponent
    }

    init() {
        refreshInstalledState()
    }

    func refreshInstalledState() {
        guard !state.isDownloading else { return }
        if let url = GemmaModelLocator.resolveModelURL() {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            installedByteCount = size
            state = .ready(fileName: url.lastPathComponent, byteCount: size)
        } else {
            installedByteCount = nil
            if case .failed = state { return }
            state = .idle
        }
    }

    func startDownload() async {
        guard !state.isDownloading else { return }

        GemmaModelLocator.ensureDirectories()

        if let free = Self.availableDiskBytes(), free < Self.requiredFreeBytes {
            let freeGB = Double(free) / 1_000_000_000
            state = .failed(
                String(
                    format: "Need about 3.2 GB free. This device has %.1f GB available.",
                    freeGB
                )
            )
            return
        }

        // Replace any partial previous download.
        let destination = GemmaModelLocator.documentsModelsDirectory
            .appendingPathComponent(Self.fileName)
        let partial = destination.appendingPathExtension("download")
        try? FileManager.default.removeItem(at: partial)

        state = .downloading(fraction: 0, bytesWritten: 0, bytesExpected: Self.approximateByteCount)

        do {
            let tempURL = try await performDownload()
            state = .finishing
            try finalize(tempURL: tempURL, destination: destination)
            let size = (try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            installedByteCount = size
            state = .ready(fileName: Self.fileName, byteCount: size)
        } catch is CancellationError {
            refreshInstalledState()
            if case .ready = state { /* keep */ } else { state = .idle }
        } catch {
            state = .failed(Self.friendlyMessage(for: error))
        }

        tearDownSession()
    }

    func cancel() {
        task?.cancel()
    }

    func deleteInstalledModel() {
        task?.cancel()
        if let cont = continuation {
            continuation = nil
            cont.resume(throwing: CancellationError())
        }
        tearDownSession()

        let fm = FileManager.default
        let dir = GemmaModelLocator.documentsModelsDirectory
        if let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for url in contents where url.pathExtension.lowercased() == "litertlm"
                || url.pathExtension.lowercased() == "download"
            {
                try? fm.removeItem(at: url)
            }
        }
        installedByteCount = nil
        state = .idle
    }

    // MARK: - Private

    private func performDownload() async throws -> URL {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            self.continuation = continuation

            let proxy = DownloadDelegateProxy { [weak self] written, expected in
                Task { @MainActor in
                    guard let self else { return }
                    let total = expected > 0 ? expected : Self.approximateByteCount
                    let fraction = min(0.99, Double(written) / Double(max(total, 1)))
                    self.state = .downloading(
                        fraction: fraction,
                        bytesWritten: written,
                        bytesExpected: total
                    )
                }
            } onComplete: { [weak self] result in
                Task { @MainActor in
                    guard let self else { return }
                    guard let cont = self.continuation else { return }
                    self.continuation = nil
                    switch result {
                    case .success(let url):
                        cont.resume(returning: url)
                    case .failure(let error):
                        cont.resume(throwing: error)
                    }
                }
            }

            let config = URLSessionConfiguration.default
            config.allowsCellularAccess = true
            config.waitsForConnectivity = true
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 60 * 60 * 6 // large model on slow networks

            let session = URLSession(configuration: config, delegate: proxy, delegateQueue: nil)
            self.delegateProxy = proxy
            self.session = session

            var request = URLRequest(url: Self.remoteURL)
            request.setValue("Lune/1.0 (iOS; on-device Gemma)", forHTTPHeaderField: "User-Agent")
            request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

            let downloadTask = session.downloadTask(with: request)
            self.task = downloadTask
            downloadTask.resume()
        }
    }

    private func finalize(tempURL: URL, destination: URL) throws {
        let fm = FileManager.default
        GemmaModelLocator.ensureDirectories()
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: tempURL, to: destination)
        try? (destination as NSURL).setResourceValue(
            URLFileProtection.completeUnlessOpen,
            forKey: .fileProtectionKey
        )
    }

    private func tearDownSession() {
        task = nil
        session?.invalidateAndCancel()
        session = nil
        delegateProxy = nil
    }

    private static func availableDiskBytes() -> Int64? {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let free = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        return free
    }

    private static func friendlyMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled:
                return "Download cancelled."
            case .notConnectedToInternet:
                return "No internet connection."
            case .timedOut:
                return "Download timed out. Try again on Wi‑Fi."
            case .dataNotAllowed:
                return "Cellular data is disabled for downloads."
            default:
                break
            }
        }
        if let downloadError = error as? DownloadError {
            return downloadError.localizedDescription
        }
        return error.localizedDescription
    }

    static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - URLSession delegate

private enum DownloadError: LocalizedError {
    case badStatus(Int)
    case missingFile
    case gatedOrUnauthorized

    var errorDescription: String? {
        switch self {
        case .badStatus(let code):
            "Download failed (HTTP \(code))."
        case .missingFile:
            "The download finished but the file was missing."
        case .gatedOrUnauthorized:
            "Hugging Face needs you to accept the Gemma license in a browser, then try again. If the model is gated for your account, download may require signing in on huggingface.co first."
        }
    }
}

private final class DownloadDelegateProxy: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Int64, Int64) -> Void
    private let onComplete: @Sendable (Result<URL, Error>) -> Void
    private var finished = false

    init(
        onProgress: @escaping @Sendable (Int64, Int64) -> Void,
        onComplete: @escaping @Sendable (Result<URL, Error>) -> Void
    ) {
        self.onProgress = onProgress
        self.onComplete = onComplete
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        onProgress(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard !finished else { return }

        if let response = downloadTask.response as? HTTPURLResponse {
            let code = response.statusCode
            if code == 401 || code == 403 {
                finished = true
                onComplete(.failure(DownloadError.gatedOrUnauthorized))
                return
            }
            if !(200...299).contains(code) {
                finished = true
                onComplete(.failure(DownloadError.badStatus(code)))
                return
            }
        }

        do {
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent("lune-gemma-\(UUID().uuidString).litertlm")
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: location, to: tempURL)
            finished = true
            onComplete(.success(tempURL))
        } catch {
            finished = true
            onComplete(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        guard !finished else { return }
        finished = true
        if let urlError = error as? URLError, urlError.code == .cancelled {
            onComplete(.failure(CancellationError()))
        } else {
            onComplete(.failure(error))
        }
    }
}
