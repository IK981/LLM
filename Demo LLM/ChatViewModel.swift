//
//  ChatViewModel.swift
//  Demo LLM
//

import Foundation
import SwiftUI
import Combine

@MainActor
public final class ChatViewModel: ObservableObject {
    @Published public var messages: [ChatMessage] = []
    @Published public var inputText: String = ""
    @Published public var isGenerating: Bool = false
    @Published public var currentStreamingMessageId: UUID? = nil
    @Published public var errorMessage: String? = nil
    @Published public var showSettings: Bool = false
    @Published public var config: LLMConfig = LLMConfig()

    private var activeTask: Task<Void, Never>? = nil
    private let configStorageKey = "DemoLLM_Config_v1"

    public init() {
        loadConfig()
        setupWelcomeMessage()
    }

    private func setupWelcomeMessage() {
        if messages.isEmpty {
            messages.append(ChatMessage(
                role: .assistant,
                content: """
                👋 **Welcome to Demo LLM!**

                This app supports **Google Gemini**, **OpenAI**, **Ollama (local)**, and an instant **Offline Simulator**.

                - Try tapping any of the prompt presets below to see live token streaming!
                - Tap the **model badge** or **gear icon** at the top right to configure API keys or switch providers.
                """,
                timestamp: Date(),
                isStreaming: false
            ))
        }
    }

    // MARK: - Message Handling

    public func sendMessage(overrideText: String? = nil) {
        let textToSend = (overrideText ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSend.isEmpty, !isGenerating else { return }

        // Clear input text if using standard input
        if overrideText == nil {
            inputText = ""
        }
        errorMessage = nil

        // Add user message
        let userMessage = ChatMessage(
            role: .user,
            content: textToSend,
            tokenCount: estimateTokens(for: textToSend)
        )
        messages.append(userMessage)

        // Create empty assistant placeholder message
        let assistantMessageId = UUID()
        let assistantMessage = ChatMessage(
            id: assistantMessageId,
            role: .assistant,
            content: "",
            timestamp: Date(),
            isStreaming: true,
            tokenCount: 0
        )
        messages.append(assistantMessage)
        currentStreamingMessageId = assistantMessageId
        isGenerating = true

        let service = LLMServiceFactory.service(for: config.provider)
        let messagesForContext = messages.filter { $0.id != assistantMessageId && !$0.content.isEmpty }
        let currentConfig = config

        let startTime = CFAbsoluteTimeGetCurrent()

        activeTask = Task { [weak self] in
            guard let self = self else { return }

            var accumulatedText = ""
            var tokenCount = 0

            do {
                let stream = service.streamResponse(messages: messagesForContext, config: currentConfig)

                for try await chunk in stream {
                    if Task.isCancelled { break }
                    accumulatedText += chunk
                    tokenCount = self.estimateTokens(for: accumulatedText)

                    let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                    let speed = elapsed > 0 ? Double(tokenCount) / elapsed : 0.0

                    if let index = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                        self.messages[index].content = accumulatedText
                        self.messages[index].tokenCount = tokenCount
                        self.messages[index].generationDuration = elapsed
                        self.messages[index].speedTokensPerSec = speed
                    }
                }

                let totalTime = CFAbsoluteTimeGetCurrent() - startTime
                let finalSpeed = totalTime > 0 ? Double(tokenCount) / totalTime : 0.0

                if let index = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    self.messages[index].isStreaming = false
                    self.messages[index].generationDuration = totalTime
                    self.messages[index].speedTokensPerSec = finalSpeed
                }

            } catch {
                if !Task.isCancelled {
                    self.errorMessage = error.localizedDescription
                    // If error occurred with empty content, show friendly notice
                    if let index = self.messages.firstIndex(where: { $0.id == assistantMessageId }) {
                        if self.messages[index].content.isEmpty {
                            self.messages[index].content = "⚠️ **Error:** \(error.localizedDescription)"
                        }
                        self.messages[index].isStreaming = false
                    }
                }
            }

            self.isGenerating = false
            self.currentStreamingMessageId = nil
            self.activeTask = nil
        }
    }

    public func cancelGeneration() {
        activeTask?.cancel()
        activeTask = nil
        isGenerating = false
        if let currentId = currentStreamingMessageId,
           let index = messages.firstIndex(where: { $0.id == currentId }) {
            messages[index].isStreaming = false
        }
        currentStreamingMessageId = nil
    }

    public func regenerateLastMessage() {
        guard !isGenerating else { return }
        guard let lastUserIndex = messages.lastIndex(where: { $0.role == .user }) else { return }
        
        let lastUserMessage = messages[lastUserIndex].content
        
        // Remove trailing assistant response if any
        if let lastAssistantIndex = messages.lastIndex(where: { $0.role == .assistant }),
           lastAssistantIndex > lastUserIndex {
            messages.remove(at: lastAssistantIndex)
        }
        
        // Remove user message so sendMessage can re-add cleanly
        messages.remove(at: lastUserIndex)
        sendMessage(overrideText: lastUserMessage)
    }

    public func clearChat() {
        cancelGeneration()
        messages.removeAll()
        setupWelcomeMessage()
    }

    public func applyPreset(_ preset: PromptPreset) {
        sendMessage(overrideText: preset.prompt)
    }

    // MARK: - Utilities

    public func estimateTokens(for text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        // Rule of thumb: ~4 characters per token for English text & code
        return max(1, Int(ceil(Double(trimmed.count) / 3.8)))
    }

    // MARK: - Persistence

    public func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configStorageKey)
        }
    }

    private func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: configStorageKey),
           let saved = try? JSONDecoder().decode(LLMConfig.self, from: data) {
            self.config = saved
            
            // Automatically upgrade deprecated/retired Gemini models
            if self.config.geminiModel == "gemini-1.5-flash" || self.config.geminiModel == "gemini-1.5-pro" || self.config.geminiModel.isEmpty {
                self.config.geminiModel = "gemini-3.5-flash-lite"
                saveConfig()
            }
        }
    }
}
