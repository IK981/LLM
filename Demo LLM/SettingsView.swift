//
//  SettingsView.swift
//  Demo LLM
//

import SwiftUI

public struct SettingsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showApiKey = false
    @State private var customModelText = ""

    public var body: some View {
        NavigationStack {
            Form {
                // Provider Selection Section
                Section {
                    Picker("LLM Provider", selection: $viewModel.config.provider) {
                        ForEach(LLMProviderType.allCases) { provider in
                            Label(provider.rawValue, systemImage: provider.iconName)
                                .tag(provider)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(viewModel.config.provider.shortDescription)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } header: {
                    Text("ACTIVE BACKEND")
                }

                // Provider-Specific Settings
                switch viewModel.config.provider {
                case .simulator:
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Ready to use offline")
                                .font(.subheadline)
                        }
                        Text("The simulator runs locally with zero latency, full streaming simulation, and sample responses for coding, architecture, reasoning, and creative writing.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } header: {
                        Text("SIMULATOR STATUS")
                    }

                case .appleOnDevice:
                    Section {
                        HStack {
                            Image(systemName: "apple.logo")
                                .foregroundColor(.primary)
                            Text("Apple Neural Engine & Core ML")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("ANE Active")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(.green)
                                Text("100% Private & Offline")
                                    .font(.subheadline)
                            }
                            Text("Runs entirely on-device using Apple's Neural Engine and NaturalLanguage vector embeddings. No data ever leaves your device.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }

                        Picker("Target Model Profile", selection: Binding(
                            get: { self.viewModel.config.geminiModel.hasPrefix("Apple") || self.viewModel.config.geminiModel.hasPrefix("CoreML") ? self.viewModel.config.geminiModel : "Apple-NeuralEngine-OnDevice" },
                            set: { self.viewModel.config.geminiModel = $0 }
                        )) {
                            ForEach(LLMProviderType.appleOnDevice.popularModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("COMPUTE UNITS: .ALL (NEURAL ENGINE + GPU + CPU)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("Optimized for Apple Silicon unified memory with FP16/INT4 low-precision weight acceleration.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("ON-DEVICE HARDWARE ENGINE")
                    }

                case .gemini:
                    Section {
                        HStack {
                            if showApiKey {
                                TextField("Gemini API Key", text: $viewModel.config.geminiApiKey)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            } else {
                                SecureField("Gemini API Key", text: $viewModel.config.geminiApiKey)
                            }

                            Button(action: { showApiKey.toggle() }) {
                                Image(systemName: showApiKey ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }

                        Picker("Model", selection: $viewModel.config.geminiModel) {
                            ForEach(LLMProviderType.gemini.popularModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }

                        HStack {
                            Text("Custom Model:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("e.g. gemini-3.5-flash-lite", text: $viewModel.config.geminiModel)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                            HStack {
                                Text("Get a Google Gemini API Key")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.subheadline)
                        }
                    } header: {
                        Text("GOOGLE GEMINI CONFIGURATION")
                    } footer: {
                        Text("Supports native REST streaming with SSE tokens.")
                    }

                case .openai:
                    Section {
                        HStack {
                            if showApiKey {
                                TextField("OpenAI API Key (sk-...)", text: $viewModel.config.openAIApiKey)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            } else {
                                SecureField("OpenAI API Key (sk-...)", text: $viewModel.config.openAIApiKey)
                            }

                            Button(action: { showApiKey.toggle() }) {
                                Image(systemName: showApiKey ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }

                        Picker("Model", selection: $viewModel.config.openAIModel) {
                            ForEach(LLMProviderType.openai.popularModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }

                        HStack {
                            Text("Base URL:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("https://api.openai.com/v1", text: $viewModel.config.openAIBaseURL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                            HStack {
                                Text("Get OpenAI API Key")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.subheadline)
                        }
                    } header: {
                        Text("OPENAI CONFIGURATION")
                    } footer: {
                        Text("Can also be used with OpenAI-compatible proxies (Groq, Together AI, OpenRouter).")
                    }

                case .ollama:
                    Section {
                        HStack {
                            Text("Endpoint:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("http://localhost:11434", text: $viewModel.config.ollamaBaseURL)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        Picker("Preset Model", selection: $viewModel.config.ollamaModel) {
                            ForEach(LLMProviderType.ollama.popularModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }

                        HStack {
                            Text("Custom Model:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            TextField("e.g. llama3, mistral", text: $viewModel.config.ollamaModel)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                    } header: {
                        Text("OLLAMA (LOCAL) CONFIGURATION")
                    } footer: {
                        Text("Ensure Ollama is running on your Mac with: `ollama run \(viewModel.config.ollamaModel)`")
                    }
                }

                // Model Hyperparameters
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(String(format: "%.2f", viewModel.config.temperature))
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $viewModel.config.temperature, in: 0.0...1.5, step: 0.05)

                        HStack {
                            Text("Precise & Focused (0.0)")
                            Spacer()
                            Text("Creative & Varied (1.5)")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("System Instructions")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextEditor(text: $viewModel.config.systemPrompt)
                            .frame(minHeight: 80)
                            .font(.system(size: 14))
                    }
                } header: {
                    Text("GENERATION PARAMETERS")
                }

                // Reset Action
                Section {
                    Button(role: .destructive) {
                        viewModel.config = LLMConfig()
                        viewModel.saveConfig()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset Settings to Default")
                        }
                    }
                }
            }
            .navigationTitle("LLM Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.saveConfig()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
