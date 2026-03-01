import Foundation
import Darwin

struct BackendStateUpdate: Decodable {
    let state: AssistantState?
    let completed: Bool?
    let intent: String?
}

final class BackendBridge: @unchecked Sendable {
    var onStateUpdate: ((BackendStateUpdate) -> Void)?

    /// Which bundled Python script to run: "template_backend" or "no_backend"
    var backendScript: String = "template_backend"

    private var stateFileMonitor: StateFileMonitor?

    func runGemini(prompt: String) async throws -> String {
        try await ShellCommandRunner.run(
            executable: "/usr/bin/env",
            arguments: ["gemini", "-p", prompt]
        )
    }

    func runPythonTemplate(input: String) throws -> String {
        let scriptURL = try pythonTemplateScriptURL()
        let response = try runBundledPythonScript(scriptURL: scriptURL, input: input)
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Launches the bundled Python script and streams its stdout back via `onChunk`.
    /// `onChunk` and `onComplete` are called on a background dispatch queue.
    func runPythonTemplateStreaming(
        input: String,
        onChunk: @escaping @Sendable (String) -> Void,
        onComplete: @escaping @Sendable (Result<Void, Error>) -> Void
    ) throws {
        let scriptURL = try pythonTemplateScriptURL()
        let process = Process()

        let venvURL = scriptURL.deletingLastPathComponent()
            .appendingPathComponent(".venv/bin/python3")
        if FileManager.default.fileExists(atPath: venvURL.path) {
            process.executableURL = venvURL
            process.arguments = [scriptURL.path, input]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", scriptURL.path, input]
        }

        let outputPipe = Pipe()
        let errorPipe  = Pipe()
        process.standardOutput = outputPipe
        process.standardError  = errorPipe

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            onChunk(text)
        }

        process.terminationHandler = { process in
            outputPipe.fileHandleForReading.readabilityHandler = nil
            if process.terminationStatus == 0 {
                onComplete(.success(()))
            } else {
                let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errText = String(decoding: errData, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                onComplete(.failure(NSError(
                    domain: "Ghosty.BackendBridge",
                    code: 3,
                    userInfo: [
                        NSLocalizedDescriptionKey: errText.isEmpty
                            ? "Script exited with status \(process.terminationStatus)."
                            : errText
                    ]
                )))
            }
        }

        do {
            try process.run()
        } catch {
            throw NSError(
                domain: "Ghosty.BackendBridge",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to launch bundled Python script via python3."]
            )
        }
    }

    private func runBundledPythonScript(scriptURL: URL, input: String) throws -> String {
        let process = Process()

        // Try to find a valid python3 executable in potential .venv locations
        let venvCandidates: [URL] = [
            // 1. Absolute path from compilation time (source-level uv .venv)
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent() // Services/
                .deletingLastPathComponent() // GhostyApp/
                .appendingPathComponent("Resources/Backend/.venv/bin/python3"),
            // 2. Relative to the bundled script (standard bundle structure)
            scriptURL.deletingLastPathComponent().appendingPathComponent(".venv/bin/python3"),
            // 3. In the user's Ghosty directory (persistent shared venv fallback)
            URL(fileURLWithPath: NSString(string: "~/Ghosty/.venv/bin/python3").expandingTildeInPath)
        ]

        if let venvURL = venvCandidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            process.executableURL = venvURL
            process.arguments = [scriptURL.path, input]
        } else {
            // Fallback to system python3
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", scriptURL.path, input]
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw NSError(
                domain: "Ghosty.BackendBridge",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to launch bundled Python script via python3."]
            )
        }

        process.waitUntilExit()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorText = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(
                domain: "Ghosty.BackendBridge",
                code: 3,
                userInfo: [
                    NSLocalizedDescriptionKey: errorText.isEmpty
                        ? "Bundled Python script exited with status \(process.terminationStatus)."
                        : errorText
                ]
            )
        }

        return String(decoding: outputData, as: UTF8.self)
    }

    func startMonitoringStateFile(path: String = "~/Ghosty/state.json") {
        let expanded = NSString(string: path).expandingTildeInPath
        stateFileMonitor = StateFileMonitor(filePath: expanded) { [weak self] data in
            guard let self else { return }
            guard let update = try? JSONDecoder().decode(BackendStateUpdate.self, from: data) else { return }

            self.onStateUpdate?(update)
            if let intent = update.intent, !intent.isEmpty {
                Task {
                    _ = try? await self.runGemini(prompt: intent)
                }
            }
        }
        stateFileMonitor?.start()
    }

    private func pythonTemplateScriptURL() throws -> URL {
        let scriptName = backendScript
        let directCandidates: [URL?] = [
            Bundle.module.url(forResource: scriptName, withExtension: "py"),
            Bundle.module.url(forResource: scriptName, withExtension: "py", subdirectory: "Backend"),
            Bundle.module.url(forResource: scriptName, withExtension: "py", subdirectory: "Resources/Backend")
        ]

        if let match = directCandidates.compactMap({ $0 }).first {
            return match
        }

        if let resourceRoot = Bundle.module.resourceURL,
           let enumerator = FileManager.default.enumerator(
            at: resourceRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
           ) {
            for case let url as URL in enumerator {
                if url.lastPathComponent == "\(scriptName).py" {
                    return url
                }
            }
        }

        throw NSError(
            domain: "Ghosty.BackendBridge",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Bundled Python backend script not found in \(Bundle.module.bundleURL.path)."
            ]
        )
    }
}

private enum ShellCommandRunner {
    static func run(executable: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                if process.terminationStatus == 0 {
                    let output = String(decoding: outputData, as: UTF8.self)
                    continuation.resume(returning: output)
                } else {
                    let errorText = String(decoding: errorData, as: UTF8.self)
                    continuation.resume(throwing: NSError(
                        domain: "Ghosty.Shell",
                        code: Int(process.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: errorText]
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private final class StateFileMonitor {
    private let filePath: String
    private let onData: (Data) -> Void

    private var fileDescriptor: CInt = -1
    private var source: DispatchSourceFileSystemObject?

    init(filePath: String, onData: @escaping (Data) -> Void) {
        self.filePath = filePath
        self.onData = onData
    }

    deinit {
        stop()
    }

    func start() {
        ensureFileExists()

        fileDescriptor = open(filePath, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let queue = DispatchQueue(label: "ghosty.state.file.monitor")
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .attrib, .rename],
            queue: queue
        )

        source?.setEventHandler { [weak self] in
            self?.readFile()
        }

        source?.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        source?.resume()
        readFile()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func ensureFileExists() {
        let manager = FileManager.default
        let url = URL(fileURLWithPath: filePath)
        let directory = url.deletingLastPathComponent()

        if !manager.fileExists(atPath: directory.path) {
            try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        if !manager.fileExists(atPath: filePath) {
            manager.createFile(atPath: filePath, contents: Data("{}".utf8))
        }
    }

    private func readFile() {
        guard let data = FileManager.default.contents(atPath: filePath) else { return }
        onData(data)
    }
}
