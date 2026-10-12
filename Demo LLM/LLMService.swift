//
//  LLMService.swift
//  Demo LLM
//

import Foundation

public enum LLMServiceError: LocalizedError {
    case missingApiKey(String)
    case invalidURL
    case serverError(Int, String)
    case decodingError(String)
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .missingApiKey(let provider):
            return "Please provide an API Key for \(provider) in Settings (tap the gear icon ⚙️)."
        case .invalidURL:
            return "The API endpoint URL is invalid."
        case .serverError(let code, let msg):
            return "Server returned error \(code): \(msg)"
        case .decodingError(let msg):
            return "Failed to parse LLM response: \(msg)"
        case .networkError(let msg):
            return "Network connection issue: \(msg)"
        }
    }
}

public protocol LLMServiceProtocol {
    func streamResponse(
        messages: [ChatMessage],
        config: LLMConfig
    ) -> AsyncThrowingStream<String, Error>
}

public final class LLMServiceFactory {
    public static func service(for provider: LLMProviderType) -> LLMServiceProtocol {
        switch provider {
        case .simulator:
            return SimulatorLLMService()
        case .appleOnDevice:
            return AppleOnDeviceLLMService()
        case .gemini:
            return GeminiLLMService()
        case .openai:
            return OpenAILLMService()
        case .ollama:
            return OllamaLLMService()
        }
    }
}

// MARK: - Simulator LLM Service (Offline, High-Fidelity)

public final class SimulatorLLMService: LLMServiceProtocol {
    public init() {}

    public func streamResponse(
        messages: [ChatMessage],
        config: LLMConfig
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                let userPrompt = messages.last(where: { $0.role == .user })?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let response = self.generateSmartResponse(for: userPrompt)
                
                // Break into tokens / words with punctuation
                let tokens = self.tokenize(text: response)
                
                for token in tokens {
                    if Task.isCancelled { break }
                    continuation.yield(token)
                    
                    // Realistic typing variance between 15ms and 45ms
                    let delayMs = UInt64.random(in: 15...45)
                    try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
                }
                
                continuation.finish()
            }
            
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func tokenize(text: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        
        for char in text {
            currentToken.append(char)
            if char.isWhitespace || char.isPunctuation {
                tokens.append(currentToken)
                currentToken = ""
            }
        }
        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }
        return tokens
    }

    private func generateSmartResponse(for prompt: String) -> String {
        let lower = prompt.lowercased()

        if lower.contains("transformer") || lower.contains("attention") {
            return """
            ### 🧠 Understanding Transformers & Self-Attention

            Transformers revolutionized Natural Language Processing by replacing sequential recurrence (RNNs/LSTMs) with **Multi-Head Self-Attention**.

            #### 1. The Cocktail Party Analogy
            Imagine being at a crowded networking dinner:
            - **Query (Q):** What you are currently interested in hearing.
            - **Key (K):** The topics each guest around the room is talking about.
            - **Value (V):** The actual substantive information being spoken.

            By computing the dot product between your **Query** and everyone's **Key**, your brain computes an *attention weight*—amplifying the speakers most relevant to your question while dimming the background noise.

            #### 2. The Scaled Dot-Product Formula
            $$\\text{Attention}(Q, K, V) = \\text{softmax}\\left(\\frac{QK^T}{\\sqrt{d_k}}\\right)V$$

            - **Parallel Processing:** Unlike RNNs, all input tokens are computed simultaneously across matrix operations on GPUs/TPUs.
            - **Positional Encodings:** Positional embeddings (RoPE, ALiBi) inject sequence order without needing sequential steps.
            """
        } else if lower.contains("swift") && (lower.contains("concurrency") || lower.contains("actor") || lower.contains("taskgroup")) {
            return """
            Here is a production-grade Swift 6 concurrency example demonstrating actor isolation, structured concurrency, and a `TaskGroup` with error handling:

            ```swift
            import Foundation

            actor DownloadCache {
                private var cache: [URL: Data] = [:]

                func save(_ data: Data, for url: URL) {
                    cache[url] = data
                }

                func data(for url: URL) -> Data? {
                    cache[url]
                }
            }

            final class NetworkBatchFetcher {
                private let cache = DownloadCache()

                func fetchAll(urls: [URL]) async throws -> [URL: Data] {
                    try await withThrowingTaskGroup(of: (URL, Data).self) { group in
                        for url in urls {
                            group.addTask {
                                // Check cache first
                                if let cached = await self.cache.data(for: url) {
                                    return (url, cached)
                                }
                                
                                let (data, response) = try await URLSession.shared.data(from: url)
                                guard let httpResponse = response as? HTTPURLResponse,
                                      httpResponse.statusCode == 200 else {
                                    throw URLError(.badServerResponse)
                                }
                                
                                await self.cache.save(data, for: url)
                                return (url, data)
                            }
                        }

                        var results: [URL: Data] = [:]
                        for try await (url, data) in group {
                            results[url] = data
                        }
                        return results
                    }
                }
            }
            ```

            ### Key Takeaways:
            - **Actor Isolation:** `DownloadCache` protects internal dictionary mutations without manual locks.
            - **TaskGroup:** Executes requests concurrently and aggregates results safely.
            - **Cancellation:** If one task throws, the parent group automatically cancels sibling tasks.
            """
        } else if lower.contains("startup") || lower.contains("ideas") {
            return """
            Here are **3 high-potential B2B SaaS ideas** at the intersection of on-device LLMs and multi-agent systems:

            1. **OmniGuard: Local Privacy-First Compliance Agent**
               - *Problem:* Enterprise developers and healthcare teams cannot leak internal IP or HIPAA data to public cloud LLMs.
               - *Solution:* Runs a quantized local model (via Apple Silicon / CoreML / MLX) that sanitizes PII, audits prompts in real-time, and routes queries dynamically between private on-device models and encrypted enterprise gateways.

            2. **TraceOps: Autonomous Post-Mortem & Incident Commander**
               - *Problem:* Production outages generate hundreds of Slack alerts, Datadog traces, and GitHub commit logs that overwhelm on-call engineers.
               - *Solution:* A team of specialized agents cross-examines git blame, Kubernetes pod logs, and crash metrics to auto-generate root-cause hypotheses and Draft PR rollback proposals within 60 seconds.

            3. **DocuSync: Living Engineering Knowledge Base**
               - *Problem:* Internal documentation always gets outdated the moment code is merged.
               - *Solution:* Watches PR merges and updates Markdown documentation, API schemas, and architecture diagrams automatically with human review checks.
            """
        } else if lower.contains("code") || lower.contains("optimize") || lower.contains("filter") {
            return """
            To achieve **$O(n)$** performance when filtering duplicates from large arrays in Swift while preserving original order, use a companion `Set`:

            ### Optimized Implementation:

            ```swift
            extension Sequence where Element: Hashable {
                /// Returns a new array with duplicates removed in O(n) time, preserving order.
                func removingDuplicates() -> [Element] {
                    var seen = Set<Element>()
                    return filter { seen.insert($0).inserted }
                }
            }
            ```

            ### Performance Benchmark:
            - **Naive $O(n^2)$ approach:** Calling `array.contains(element)` inside a loop requires scanning the accumulating list for every element. For 100,000 items, this requires $\\sim 5\\times 10^9$ comparisons!
            - **Set $O(n)$ approach:** `Set.insert` is amortized $O(1)$. For 100,000 items, it completes in just $\\approx 12\\text{ ms}$.
            """
        } else if lower.contains("hello") || lower.contains("hi") || lower.contains("hey") {
            return """
            Hello! 👋 I am your interactive **AI Assistant**.

            I'm currently running in **Instant Simulator Mode**, which works completely offline with zero API keys required.

            You can ask me to:
            - 💻 **Write & debug code** in Swift, Python, Rust, or JavaScript
            - 🧠 **Explain complex concepts** like Transformers, Quantum Computing, or Concurrency
            - 📝 **Draft content**, emails, summaries, and architectural designs
            - ⚙️ **Switch to Google Gemini, OpenAI, or Ollama** anytime using the Settings icon in the top right!

            What would you like to build or explore today?
            """
        } else {
            return """
            I received your request: *"\(prompt)"*

            ### Analysis & Overview
            When working with modern LLM applications, key considerations include:

            1. **Latency & Throughput:** Streaming responses with Time-To-First-Token (TTFT) under 400ms creates an engaging conversational UX.
            2. **Context Management:** Balancing conversation history against context window limits using sliding windows or summarization.
            3. **Multi-Model Routing:** Routing complex reasoning to flagship frontier models while directing quick classifications to lightweight models like Gemini 1.5 Flash or GPT-4o-mini.

            ```swift
            // Tip: Tap the Settings button (⚙️) to connect your live API key
            // (Google Gemini, OpenAI, or local Ollama) for unconstrained live responses!
            ```

            Is there a specific detail or code snippet you'd like me to expand on?
            """
        }
    }
}

// MARK: - Google Gemini LLM Service

public final class GeminiLLMService: LLMServiceProtocol {
    public init() {}

    public func streamResponse(
        messages: [ChatMessage],
        config: LLMConfig
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                guard !config.geminiApiKey.isEmpty else {
                    continuation.finish(throwing: LLMServiceError.missingApiKey("Google Gemini"))
                    return
                }

                var model = config.geminiModel.trimmingCharacters(in: .whitespacesAndNewlines)
                if model.hasPrefix("models/") {
                    model = String(model.dropFirst(7))
                }
                if model.isEmpty || model == "gemini-1.5-flash" || model == "gemini-1.5-pro" {
                    model = "gemini-3.5-flash-lite"
                }

                let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):streamGenerateContent?alt=sse&key=\(config.geminiApiKey)"
                
                guard let url = URL(string: urlString) else {
                    continuation.finish(throwing: LLMServiceError.invalidURL)
                    return
                }

                // Prepare request payload
                var contents: [[String: Any]] = []
                for msg in messages {
                    let role = msg.role == .assistant ? "model" : "user"
                    contents.append([
                        "role": role,
                        "parts": [["text": msg.content]]
                    ])
                }

                var requestBody: [String: Any] = [
                    "contents": contents,
                    "generationConfig": [
                        "temperature": config.temperature,
                        "maxOutputTokens": config.maxTokens
                    ]
                ]

                if !config.systemPrompt.isEmpty {
                    requestBody["systemInstruction"] = [
                        "parts": [["text": config.systemPrompt]]
                    ]
                }

                guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
                    continuation.finish(throwing: LLMServiceError.decodingError("Could not encode request body"))
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = jsonData

                do {
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        var errorBody = ""
                        for try await line in asyncBytes.lines {
                            errorBody += line
                        }
                        
                        var readableMessage = errorBody
                        if let data = errorBody.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let err = json["error"] as? [String: Any],
                           let msg = err["message"] as? String {
                            readableMessage = msg
                        }
                        
                        continuation.finish(throwing: LLMServiceError.serverError(httpResponse.statusCode, readableMessage))
                        return
                    }

                    for try await line in asyncBytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonStr = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !jsonStr.isEmpty, let data = jsonStr.data(using: .utf8) else { continue }
                        
                        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let candidates = root["candidates"] as? [[String: Any]],
                           let first = candidates.first,
                           let content = first["content"] as? [String: Any],
                           let parts = content["parts"] as? [[String: Any]] {
                            for part in parts {
                                if let text = part["text"] as? String {
                                    continuation.yield(text)
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - OpenAI LLM Service

public final class OpenAILLMService: LLMServiceProtocol {
    public init() {}

    public func streamResponse(
        messages: [ChatMessage],
        config: LLMConfig
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                guard !config.openAIApiKey.isEmpty else {
                    continuation.finish(throwing: LLMServiceError.missingApiKey("OpenAI"))
                    return
                }

                var baseUrl = config.openAIBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                if baseUrl.hasSuffix("/") { baseUrl.removeLast() }
                let urlString = "\(baseUrl)/chat/completions"

                guard let url = URL(string: urlString) else {
                    continuation.finish(throwing: LLMServiceError.invalidURL)
                    return
                }

                var apiMessages: [[String: String]] = []
                if !config.systemPrompt.isEmpty {
                    apiMessages.append(["role": "system", "content": config.systemPrompt])
                }
                for msg in messages {
                    apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
                }

                let requestBody: [String: Any] = [
                    "model": config.openAIModel.isEmpty ? "gpt-4o-mini" : config.openAIModel,
                    "messages": apiMessages,
                    "stream": true,
                    "temperature": config.temperature,
                    "max_tokens": config.maxTokens
                ]

                guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
                    continuation.finish(throwing: LLMServiceError.decodingError("Could not encode request"))
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(config.openAIApiKey)", forHTTPHeaderField: "Authorization")
                request.httpBody = jsonData

                do {
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        var errorBody = ""
                        for try await line in asyncBytes.lines {
                            errorBody += line
                        }
                        continuation.finish(throwing: LLMServiceError.serverError(httpResponse.statusCode, errorBody))
                        return
                    }

                    for try await line in asyncBytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data: ") else { continue }
                        let raw = String(line.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
                        if raw == "[DONE]" { break }
                        guard let data = raw.data(using: .utf8) else { continue }

                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let choices = json["choices"] as? [[String: Any]],
                           let first = choices.first,
                           let delta = first["delta"] as? [String: Any],
                           let deltaContent = delta["content"] as? String {
                            continuation.yield(deltaContent)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Ollama (Local) LLM Service

public final class OllamaLLMService: LLMServiceProtocol {
    public init() {}

    public func streamResponse(
        messages: [ChatMessage],
        config: LLMConfig
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var baseUrl = config.ollamaBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                if baseUrl.hasSuffix("/") { baseUrl.removeLast() }
                let urlString = "\(baseUrl)/api/chat"

                guard let url = URL(string: urlString) else {
                    continuation.finish(throwing: LLMServiceError.invalidURL)
                    return
                }

                var apiMessages: [[String: String]] = []
                if !config.systemPrompt.isEmpty {
                    apiMessages.append(["role": "system", "content": config.systemPrompt])
                }
                for msg in messages {
                    apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
                }

                let requestBody: [String: Any] = [
                    "model": config.ollamaModel.isEmpty ? "llama3" : config.ollamaModel,
                    "messages": apiMessages,
                    "stream": true,
                    "options": [
                        "temperature": config.temperature
                    ]
                ]

                guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
                    continuation.finish(throwing: LLMServiceError.decodingError("Could not encode request"))
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = jsonData

                do {
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                        var errorBody = ""
                        for try await line in asyncBytes.lines {
                            errorBody += line
                        }
                        continuation.finish(throwing: LLMServiceError.serverError(httpResponse.statusCode, errorBody))
                        return
                    }

                    for try await line in asyncBytes.lines {
                        if Task.isCancelled { break }
                        guard let data = line.data(using: .utf8) else { continue }
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            if let message = json["message"] as? [String: Any],
                               let content = message["content"] as? String {
                                continuation.yield(content)
                            }
                            if let done = json["done"] as? Bool, done {
                                break
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: LLMServiceError.networkError("Could not connect to Ollama at \(config.ollamaBaseURL). Make sure `ollama serve` is running."))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}
