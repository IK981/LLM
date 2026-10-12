//
//  MessageViews.swift
//  Demo LLM
//

import SwiftUI

public struct ChatMessageRow: View {
    public let message: ChatMessage
    public let onRegenerate: (() -> Void)?

    @State private var hasCopied = false

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .assistant {
                // Assistant Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.indigo, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(color: Color.purple.opacity(0.3), radius: 4, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 6) {
                    // Message Header
                    HStack(spacing: 8) {
                        Text("AI Assistant")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        if message.isStreaming {
                            PulsingDotView()
                        }

                        Spacer()

                        // Action Bar
                        if !message.content.isEmpty {
                            Button(action: copyToClipboard) {
                                Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(hasCopied ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Content
                    if message.content.isEmpty && message.isStreaming {
                        HStack(spacing: 4) {
                            Text("Thinking")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TypingIndicatorDots()
                        }
                        .padding(.vertical, 8)
                    } else {
                        MarkdownMessageView(rawText: message.content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Performance & Token metrics badge
                    if let speed = message.speedTokensPerSec, speed > 0, message.tokenCount > 0 {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "gauge.with.needle")
                                Text(String(format: "%.1f tok/s", speed))
                            }
                            
                            Text("•")

                            HStack(spacing: 4) {
                                Image(systemName: "number")
                                Text("\(message.tokenCount) tokens")
                            }

                            if let duration = message.generationDuration {
                                Text("•")
                                Text(String(format: "%.1fs", duration))
                            }
                        }
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                Spacer(minLength: 24)
            } else {
                // User Message
                Spacer(minLength: 40)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.content)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: Color.blue.opacity(0.2), radius: 4, x: 0, y: 2)

                    Text(message.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(.trailing, 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = message.content
        withAnimation { hasCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { hasCopied = false }
        }
    }
}

// MARK: - Markdown & Code Block Formatter

public struct MarkdownMessageView: View {
    public let rawText: String

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(parseContent(rawText), id: \.id) { block in
                switch block.type {
                case .text(let content):
                    Text(.init(content))
                        .font(.system(size: 15))
                        .lineSpacing(4)
                        .textSelection(.enabled)

                case .code(let code, let language):
                    CodeBlockView(code: code, language: language)
                }
            }
        }
    }

    private func parseContent(_ text: String) -> [ContentBlock] {
        var blocks: [ContentBlock] = []
        let pattern = "```([a-zA-Z0-9_+-]*)\\n([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return [ContentBlock(type: .text(text))]
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        var lastEnd = 0

        for match in matches {
            let codeRange = match.range
            if codeRange.location > lastEnd {
                let textBefore = nsString.substring(with: NSRange(location: lastEnd, length: codeRange.location - lastEnd))
                if !textBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(ContentBlock(type: .text(textBefore)))
                }
            }

            let langRange = match.range(at: 1)
            let lang = langRange.location != NSNotFound ? nsString.substring(with: langRange) : "code"

            let contentRange = match.range(at: 2)
            let code = contentRange.location != NSNotFound ? nsString.substring(with: contentRange) : ""

            blocks.append(ContentBlock(type: .code(code: code.trimmingCharacters(in: .newlines), language: lang.isEmpty ? "code" : lang)))
            lastEnd = codeRange.location + codeRange.length
        }

        if lastEnd < nsString.length {
            let remainingText = nsString.substring(from: lastEnd)
            if !remainingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(ContentBlock(type: .text(remainingText)))
            }
        }

        if blocks.isEmpty {
            return [ContentBlock(type: .text(text))]
        }

        return blocks
    }
}

private struct ContentBlock: Identifiable {
    let id = UUID()
    let type: BlockType

    enum BlockType {
        case text(String)
        case code(code: String, language: String)
    }
}

// MARK: - Code Block View

public struct CodeBlockView: View {
    public let code: String
    public let language: String

    @State private var copied = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.red.opacity(0.8)).frame(width: 9, height: 9)
                    Circle().fill(Color.yellow.opacity(0.8)).frame(width: 9, height: 9)
                    Circle().fill(Color.green.opacity(0.8)).frame(width: 9, height: 9)
                    Text(language.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.leading, 6)
                }

                Spacer()

                Button(action: copyCode) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied" : "Copy")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))

            Divider()

            // Code Content
            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .lineSpacing(3)
                    .padding(12)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(.separator), lineWidth: 0.8)
        )
    }

    private func copyCode() {
        UIPasteboard.general.string = code
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { copied = false }
        }
    }
}

// MARK: - Prompt Preset Carousel

public struct PresetPromptsView: View {
    public let onSelect: (PromptPreset) -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SUGGESTED PROMPTS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PromptPreset.defaults) { preset in
                        Button {
                            onSelect(preset)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(preset.color.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: preset.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(preset.color)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(preset.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text(preset.subtitle)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Animated Indicators

public struct PulsingDotView: View {
    @State private var isPulsing = false

    public var body: some View {
        Circle()
            .fill(Color.purple)
            .frame(width: 7, height: 7)
            .scaleEffect(isPulsing ? 1.3 : 0.8)
            .opacity(isPulsing ? 1.0 : 0.4)
            .animation(
                Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

public struct TypingIndicatorDots: View {
    @State private var phase = 0

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 4, height: 4)
                    .offset(y: phase == index ? -4 : 0)
            }
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}
