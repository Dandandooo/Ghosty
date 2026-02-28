import AppKit
import QuickLookUI
import SwiftUI

struct NotchPanelView: View {
    @ObservedObject var model: GhostAssistantModel
    @State private var focusRequestID = 0
    @State private var isPromptFocused = false
    @State private var scrollOffset: CGFloat = 0

    private let shadowInset: CGFloat = 12
    private let outputFadeHeight: CGFloat = 24
    private let scrollFadeThreshold: CGFloat = 4

    private var showTopFade: Bool { scrollOffset > scrollFadeThreshold }

    var body: some View {
        VStack(spacing: 12) {
            GhostCharacterView(state: model.assistantState, size: 88, gazeTarget: model.textCursorScreenPoint, gazeActivityToken: model.textActivityToken)
                .offset(y: 6)

            if !model.isVoiceEnabled {
                if !model.outputItems.isEmpty {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(model.outputItems) { item in
                                outputBubble(for: item)
                            }
                        }
                        .frame(width: 236, alignment: .leading)
                        .padding(.vertical, outputFadeHeight)
                    }
                    .scrollClipDisabled()
                    .frame(maxWidth: 236, maxHeight: 300)
                    .onScrollGeometryChange(for: CGFloat.self) { geo in
                        geo.contentOffset.y
                    } action: { _, newY in
                        scrollOffset = newY
                    }
                    .mask {
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: showTopFade ? outputFadeHeight : 0)
                            Rectangle()
                                .fill(.black)
                            LinearGradient(
                                colors: [.black, .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: outputFadeHeight)
                        }
                    }
                    .animation(.easeInOut(duration: 0.18), value: showTopFade)
                }

                HStack(spacing: 8) {
                    PromptTextField(
                        text: $model.textDraft,
                        placeholder: "Message Ghosty",
                        focusRequestID: focusRequestID,
                        onFocusChanged: { focused in
                            isPromptFocused = focused

                            guard !focused, !model.isSubmittingText, !model.isVoiceEnabled, model.isPeeked else { return }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                guard !isPromptFocused, model.isPeeked else { return }
                                model.retreatGhost()
                            }
                        },
                        onCancel: {
                            model.retreatGhost()
                        },
                        onCursorMoved: { point in
                            model.textCursorScreenPoint = point
                            model.textActivityToken &+= 1
                        },
                        onSubmit: submitTypedPrompt
                    )

                    Button(action: submitTypedPrompt) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .purple)
                    }
                    .buttonStyle(.plain)
                    .opacity(model.textDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
                    .allowsHitTesting(!model.textDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(
                    ZStack {
                        Capsule(style: .continuous)
                            .fill(.ultraThinMaterial)
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.58),
                                        Color.white.opacity(0.38)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.pink.opacity(0.16),
                                        Color.clear,
                                        Color.cyan.opacity(0.16)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                )
                .overlay(
                    ZStack {
                        Capsule(style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.pink.opacity(0.72),
                                        Color.white.opacity(0.65),
                                        Color.cyan.opacity(0.74)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1.25
                            )
                        Capsule(style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.pink.opacity(0.42),
                                        Color.clear,
                                        Color.cyan.opacity(0.42)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 6
                            )
                            .blur(radius: 3)
                            .clipShape(Capsule(style: .continuous))
                    }
                )
                .shadow(color: .pink.opacity(0.24), radius: 9, x: -5, y: 0)
                .shadow(color: .cyan.opacity(0.2), radius: 9, x: 5, y: 0)
                .frame(width: 236)
            }
        }
        .padding(.top, 6)
        .frame(width: model.isVoiceEnabled ? 180 : 260, height: model.isVoiceEnabled ? 90 : 450, alignment: .top)
        .shadow(color: .black.opacity(0.25), radius: 8, y: 5)
        .padding(shadowInset)
        .frame(width: model.isVoiceEnabled ? 204 : 284, height: model.isVoiceEnabled ? 114 : 474, alignment: .top)
        .onAppear {
            requestPromptFocus()
        }
        .onChange(of: model.isPeeked) { _, isPeeked in
            if isPeeked {
                requestPromptFocus()
            } else {
                isPromptFocused = false
            }
        }
        .onChange(of: model.isVoiceEnabled) {
            requestPromptFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            requestPromptFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            requestPromptFocus()
        }
    }

    private func submitTypedPrompt() {
        let prompt = model.textDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            model.retreatGhost()
            return
        }

        if prompt.lowercased() == "clear" {
            model.outputItems.removeAll()
            model.textDraft = ""
            return
        }

        model.isSubmittingText = true

        if !model.isVoiceEnabled {
            model.submitTextIntent(prompt)
        } else {
            model.submitIntent(prompt)
        }
        model.textDraft = ""
    }

    private func requestPromptFocus() {
        guard model.isPeeked, !model.isVoiceEnabled else { return }

        let delays: [Double] = [0.0, 0.05, 0.12, 0.22]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard self.model.isPeeked, !self.model.isVoiceEnabled else { return }
                self.focusRequestID += 1
            }
        }
    }

    @ViewBuilder
    private func outputBubble(for item: AssistantOutputItem) -> some View {
        switch item.content {
        case let .text(text):
            VStack(alignment: .leading, spacing: 4) {
                Text("Ghosty")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 236, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
            )

        case let .image(resourceName):
            VStack(alignment: .leading, spacing: 8) {
                Text("Ghosty")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)

                outputImage(named: resourceName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard let imageURL = outputImageURL(named: resourceName) else { return }
                        model.retreatGhost()
                        QuickLookImagePreview.shared.present(url: imageURL)
                    }
            }
            .padding(.vertical, 10)
            .frame(width: 236, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func outputImage(named resourceName: String) -> Image {
        if let imageURL = outputImageURL(named: resourceName),
           let nsImage = NSImage(contentsOf: imageURL) {
            return Image(nsImage: nsImage)
        }

        return Image(systemName: "photo")
    }

    private func outputImageURL(named resourceName: String) -> URL? {
        if let imageURL = Bundle.module.url(forResource: resourceName, withExtension: nil, subdirectory: "Placeholder") {
            return imageURL
        }

        if let imageURL = Bundle.module.url(forResource: resourceName, withExtension: "png", subdirectory: "Placeholder") {
            return imageURL
        }

        if let imageURL = Bundle.module.url(forResource: resourceName, withExtension: nil) {
            return imageURL
        }

        if let imageURL = Bundle.module.url(forResource: resourceName, withExtension: "png") {
            return imageURL
        }

        return nil
    }
}

private final class QuickLookImagePreview: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    nonisolated(unsafe) static let shared = QuickLookImagePreview()

    private var previewURL: URL?

    @MainActor func present(url: URL) {
        previewURL = url
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        previewURL as NSURL?
    }
}


private struct PromptTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let focusRequestID: Int
    let onFocusChanged: (Bool) -> Void
    let onCancel: () -> Void
    let onCursorMoved: ((CGPoint) -> Void)?
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: text)
        textField.placeholderString = placeholder
        textField.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.75),
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold)
            ]
        )
        textField.delegate = context.coordinator
        textField.isBezeled = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 13, weight: .medium)
        textField.textColor = .labelColor
        textField.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.observeSelectionChanges(in: textField)
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self

        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        guard focusRequestID != context.coordinator.lastFocusRequestID else { return }
        context.coordinator.lastFocusRequestID = focusRequestID

        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.makeKey()
            window.makeFirstResponder(nsView)
            onFocusChanged(true)
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: PromptTextField
        var lastFocusRequestID = -1
        nonisolated(unsafe) private var selectionObserver: NSObjectProtocol?

        init(_ parent: PromptTextField) {
            self.parent = parent
        }

        func observeSelectionChanges(in textField: NSTextField) {
            selectionObserver = NotificationCenter.default.addObserver(
                forName: NSTextView.didChangeSelectionNotification,
                object: nil,
                queue: .main
            ) { [weak self, weak textField] _ in
                MainActor.assumeIsolated {
                    guard let self, let textField,
                          let editor = textField.currentEditor() as? NSTextView,
                          let window = textField.window,
                          let onCursorMoved = self.parent.onCursorMoved else { return }

                    let fieldFrameInWindow = textField.convert(textField.bounds, to: nil)
                    let fieldFrameInScreen = window.convertToScreen(fieldFrameInWindow)

                    let range = editor.selectedRange()
                    var actualRange = NSRange()
                    let cursorRect = editor.firstRect(forCharacterRange: range, actualRange: &actualRange)

                    let cursorX: CGFloat
                    if cursorRect == .zero || cursorRect.midX > fieldFrameInScreen.maxX || cursorRect.midX < fieldFrameInScreen.minX {
                        cursorX = cursorRect.midX > fieldFrameInScreen.maxX || cursorRect == .zero
                            ? fieldFrameInScreen.maxX
                            : fieldFrameInScreen.minX
                    } else {
                        cursorX = cursorRect.midX
                    }
                    onCursorMoved(CGPoint(x: cursorX, y: fieldFrameInScreen.midY))
                }
            }
        }

        deinit {
            if let obs = selectionObserver {
                NotificationCenter.default.removeObserver(obs)
            }
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            parent.onFocusChanged(true)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            parent.onFocusChanged(false)
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            if parent.text != textField.stringValue {
                parent.text = textField.stringValue
            }
            // Cursor position reporting is handled by the selection-change observer.
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }

            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }

            return false
        }
    }
}
