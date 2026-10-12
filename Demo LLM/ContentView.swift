//
//  ContentView.swift
//  Demo LLM
//
//  Created by CN22 on 29/09/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var showClearConfirmation = false

    private var activeModelDisplayName: String {
        switch viewModel.config.provider {
        case .simulator:
            return viewModel.config.provider.defaultModel
        case .appleOnDevice:
            return "Apple Neural Engine (On-Device)"
        case .gemini:
            return viewModel.config.geminiModel.isEmpty ? "gemini-1.5-flash" : viewModel.config.geminiModel
        case .openai:
            return viewModel.config.openAIModel.isEmpty ? "gpt-4o-mini" : viewModel.config.openAIModel
        case .ollama:
            return viewModel.config.ollamaModel.isEmpty ? "llama3" : viewModel.config.ollamaModel
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header Status Pill
                Button {
                    viewModel.showSettings = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.config.provider.iconName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.purple)

                        Text(viewModel.config.provider.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text(activeModelDisplayName)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .padding(.bottom, 8)

                Divider()

                // Chat Scroll Feed
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                ChatMessageRow(
                                    message: message,
                                    onRegenerate: {
                                        viewModel.regenerateLastMessage()
                                    }
                                )
                                .id(message.id)
                            }

                            // Show prompt suggestions when conversation is fresh
                            if viewModel.messages.count <= 1 && !viewModel.isGenerating {
                                PresetPromptsView { preset in
                                    viewModel.applyPreset(preset)
                                }
                                .padding(.top, 12)
                                .transition(.opacity)
                            }

                            // Invisible anchor for auto-scrolling
                            Color.clear
                                .frame(height: 1)
                                .id("bottomAnchor")
                        }
                        .padding(.vertical, 12)
                    }
                    .onChange(of: viewModel.messages.last?.content) { _ in
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    }
                }

                // Error Notification Banner
                if let errorMessage = viewModel.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text(errorMessage)
                            .font(.caption)
                            .lineLimit(2)
                        Spacer()
                        Button {
                            viewModel.errorMessage = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.yellow.opacity(0.15))
                }

                Divider()

                // Input Area
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("Message \(viewModel.config.provider.rawValue)...", text: $viewModel.inputText, axis: .vertical)
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .onSubmit {
                            if !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                viewModel.sendMessage()
                            }
                        }

                    if viewModel.isGenerating {
                        // Stop Generation Button
                        Button {
                            viewModel.cancelGeneration()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .shadow(color: Color.red.opacity(0.3), radius: 4, x: 0, y: 2)
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Send Button
                        Button {
                            viewModel.sendMessage()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(
                                        canSend
                                        ? LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 40, height: 40)

                                Image(systemName: "arrow.up")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .shadow(color: canSend ? Color.purple.opacity(0.3) : Color.clear, radius: 4, x: 0, y: 2)
                        }
                        .disabled(!canSend)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Demo LLM")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .disabled(viewModel.messages.isEmpty || viewModel.isGenerating)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                    }
                }
            }
            .confirmationDialog("Clear conversation history?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("Clear Chat", role: .destructive) {
                    viewModel.clearChat()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView(viewModel: viewModel)
            }
        }
    }

    private var canSend: Bool {
        !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isGenerating
    }
}

#Preview {
    ContentView()
}
