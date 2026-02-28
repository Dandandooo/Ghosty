import Foundation
import Darwin

struct BackendStateUpdate: Decodable {
    let state: AssistantState?
    let completed: Bool?
    let intent: String?
}

final class BackendBridge: @unchecked Sendable {
    var onStateUpdate: ((BackendStateUpdate) -> Void)?

    private var stateFileMonitor: StateFileMonitor?

    func runGemini(prompt: String) async throws -> String {
        try await ShellCommandRunner.run(
            executable: "/usr/bin/env",
            arguments: ["gemini", "-p", prompt]
        )
    }

    @MainActor
    func runPythonTemplate(input: String) throws -> String {
        let scriptURL = try pythonTemplateScriptURL()
        let response = try runBundledPythonScript(scriptURL: scriptURL, input: input)
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runBundledPythonScript(scriptURL: URL, input: String) throws -> String {
        let process = Process()

        // Try to use the virtual environment relative to the script if it exists
        let venvURL = scriptURL.deletingLastPathComponent().appendingPathComponent(".venv/bin/python3")

        if FileManager.default.fileExists(atPath: venvURL.path) {
            process.executableURL = venvURL
            process.arguments = [scriptURL.path, input]
        } else {
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

    func startMonitoringStateFile(path: String = "~/ghosty/state.json") {
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
        let directCandidates: [URL?] = [
            Bundle.module.url(forResource: "no_backend", withExtension: "py"),
            Bundle.module.url(forResource: "no_backend", withExtension: "py", subdirectory: "Backend"),
            Bundle.module.url(forResource: "no_backend", withExtension: "py", subdirectory: "Resources/Backend")
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
                if url.lastPathComponent == "no_backend.py" {
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
