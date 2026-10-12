//
//  Models.swift
//  Demo LLM
//

import Foundation
import SwiftUI

public enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

public struct ChatMessage: Identifiable, Equatable {
    public let id: UUID
    public var role: MessageRole
    public var content: String
    public var timestamp: Date
    public var isStreaming: Bool
    public var tokenCount: Int
    public var generationDuration: TimeInterval?
    public var speedTokensPerSec: Double?

    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        isStreaming: Bool = false,
        tokenCount: Int = 0,
        generationDuration: TimeInterval? = nil,
        speedTokensPerSec: Double? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.tokenCount = tokenCount
        self.generationDuration = generationDuration
        self.speedTokensPerSec = speedTokensPerSec
    }
}

public enum LLMProviderType: String, CaseIterable, Identifiable, Codable {
    case simulator = "Simulator (Offline)"
    case appleOnDevice = "Apple Core ML (On-Device)"
    case gemini = "Google Gemini"
    case openai = "OpenAI"
    case ollama = "Ollama (Local)"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .simulator: return "bolt.badge.sparkle"
        case .appleOnDevice: return "apple.logo"
        case .gemini: return "sparkles"
        case .openai: return "brain.head.profile"
        case .ollama: return "desktopcomputer"
        }
    }

    public var defaultModel: String {
        switch self {
        case .simulator: return "Simulated-LLM-4b"
        case .appleOnDevice: return "Apple-NeuralEngine-OnDevice"
        case .gemini: return "gemini-3.5-flash-lite"
        case .openai: return "gpt-4o-mini"
        case .ollama: return "llama3"
        }
    }

    public var popularModels: [String] {
        switch self {
        case .simulator:
            return ["Simulated-LLM-4b", "Simulated-Reasoning-v1"]
        case .appleOnDevice:
            return ["Apple-NeuralEngine-OnDevice", "CoreML-LLaMA-3.2-1B", "CoreML-SmolLM-135M", "Apple-NaturalLanguage-Embeddings"]
        case .gemini:
            return ["gemini-3.5-flash-lite", "gemini-3.8-flash", "gemini-3.5-flash", "gemini-3.1-flash-lite", "gemini-flash-latest"]
        case .openai:
            return ["gpt-4o-mini", "gpt-4o", "gpt-4-turbo", "o3-mini"]
        case .ollama:
            return ["llama3", "mistral", "deepseek-r1:8b", "phi3", "gemma2"]
        }
    }

    public var shortDescription: String {
        switch self {
        case .simulator:
            return "Instant offline responses without requiring API keys"
        case .appleOnDevice:
            return "100% private, on-device AI running on Apple Neural Engine & Core ML"
        case .gemini:
            return "Google Gemini Cloud API with streaming support"
        case .openai:
            return "OpenAI Chat Completions API (or compatible endpoints)"
        case .ollama:
            return "Local models running on your Mac via Ollama HTTP API"
        }
    }
}

public struct LLMConfig: Codable {
    public var provider: LLMProviderType = .gemini
    public var geminiApiKey: String = ""
    public var geminiModel: String = "gemini-3.5-flash-lite"
    
    public var openAIApiKey: String = ""
    public var openAIModel: String = "gpt-4o-mini"
    public var openAIBaseURL: String = "https://api.openai.com/v1"
    
    public var ollamaBaseURL: String = "http://localhost:11434"
    public var ollamaModel: String = "llama3"
    
    public var systemPrompt: String = "You are a helpful, knowledgeable, and concise AI assistant."
    public var temperature: Double = 0.7
    public var maxTokens: Int = 2048

    public init() {}
}

public struct PromptPreset: Identifiable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let prompt: String
    public let icon: String
    public let color: Color

    public static let defaults: [PromptPreset] = [
        PromptPreset(
            title: "Explain Transformers",
            subtitle: "Self-attention & neural LLM architecture",
            prompt: "Explain how transformer self-attention mechanisms work in modern Large Language Models, using an intuitive analogy.",
            icon: "sparkles",
            color: .purple
        ),
        PromptPreset(
            title: "Swift Concurrency",
            subtitle: "Actors & TaskGroups with code",
            prompt: "Write a clean Swift 6 example showing how to use an `actor` and `TaskGroup` to fetch multiple URLs concurrently with error handling.",
            icon: "swift",
            color: .orange
        ),
        PromptPreset(
            title: "Startup Pitch",
            subtitle: "Brainstorm 3 innovative AI ideas",
            prompt: "Brainstorm 3 innovative B2B SaaS startup ideas that leverage modern multi-agent systems and on-device LLMs.",
            icon: "lightbulb.fill",
            color: .yellow
        ),
        PromptPreset(
            title: "Code Review",
            subtitle: "Analyze & optimize complexity",
            prompt: "How can I optimize large array filtering and duplicate removal in Swift to achieve O(n) performance? Show before and after code.",
            icon: "chevron.left.forwardslash.chevron.right",
            color: .blue
        )
    ]
}
