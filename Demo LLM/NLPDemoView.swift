//
//  NLPDemoView.swift
//  Demo LLM
//

import SwiftUI
import NaturalLanguage

public struct NLPDemoView: View {
    @State private var inputText: String = "Apple announced the powerful new M4 Mac in Cupertino with Tim Cook yesterday. It was an astonishing achievement!"
    @State private var selectedTab: NLPSection = .sentiment
    
    // Vector comparison states
    @State private var vectorWord1: String = "King"
    @State private var vectorWord2: String = "Queen"
    @State private var neighborSearchWord: String = "Technology"
    @State private var selectedCodeExample: CoreMLExampleType = .coreMLInference

    private let nlp = NLPService.shared
    private let semanticMatcher = OnDeviceSemanticMatcher()

    private enum CoreMLExampleType: String, CaseIterable, Identifiable {
        case coreMLInference = "Core ML Model"
        case neuralEngineConfig = "Neural Engine"
        case vectorSimilarity = "Vector Embeddings"
        case onDeviceLLM = "On-Device LLM"

        var id: String { rawValue }
    }

    private enum NLPSection: String, CaseIterable, Identifiable {
        case sentiment = "Sentiment"
        case entities = "Entities"
        case pos = "Grammar"
        case languages = "Languages"
        case embeddings = "Word Vectors"
        case coreML = "Core ML AI"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .sentiment: return "face.smiling"
            case .entities: return "tag.fill"
            case .pos: return "textformat"
            case .languages: return "globe"
            case .embeddings: return "circle.hexagongrid.fill"
            case .coreML: return "cpu.fill"
            }
        }
    }

    private struct SamplePreset: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let text: String
    }

    private let samplePresets: [SamplePreset] = [
        SamplePreset(
            title: "News & Entities",
            icon: "newspaper.fill",
            text: "Apple announced the powerful new M4 Mac in Cupertino with Tim Cook yesterday. It was an astonishing achievement!"
        ),
        SamplePreset(
            title: "Positive Review",
            icon: "star.fill",
            text: "The customer support team was absolutely delightful, helpful, and lightning fast. Highly recommended!"
        ),
        SamplePreset(
            title: "Negative Feedback",
            icon: "exclamationmark.triangle.fill",
            text: "My flight was delayed by seven agonizing hours and the airline misplaced my luggage in Frankfurt. Terrible experience."
        ),
        SamplePreset(
            title: "French Language",
            icon: "globe.europe.africa.fill",
            text: "Bonjour le monde! La tour Eiffel à Paris est vraiment magnifique sous le soleil du matin."
        )
    ]

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Privacy & On-Device Badge
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        Text("100% On-Device Apple NaturalLanguage Engine • Zero Latency • Private")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(Capsule())

                    // Text Input Area
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("INPUT TEXT")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Clear") {
                                inputText = ""
                            }
                            .font(.system(size: 12))
                            .disabled(inputText.isEmpty)
                        }

                        TextEditor(text: $inputText)
                            .frame(minHeight: 80, maxHeight: 120)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )

                        // Sample Chips
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(samplePresets) { preset in
                                    Button {
                                        inputText = preset.text
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: preset.icon)
                                            Text(preset.title)
                                        }
                                        .font(.system(size: 12, weight: .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(.tertiarySystemBackground))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color.primary.opacity(0.06), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Feature Tool Switcher (Horizontal Scroll for all tools)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(NLPSection.allCases) { section in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        selectedTab = section
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: section.icon)
                                        Text(section.rawValue)
                                    }
                                    .font(.system(size: 13, weight: selectedTab == section ? .bold : .medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(selectedTab == section ? Color.accentColor : Color(.secondarySystemBackground))
                                    .foregroundColor(selectedTab == section ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Tool Details Content
                    Group {
                        switch selectedTab {
                        case .sentiment:
                            sentimentSection
                        case .entities:
                            entitiesSection
                        case .pos:
                            posSection
                        case .languages:
                            languagesSection
                        case .embeddings:
                            embeddingsSection
                        case .coreML:
                            coreMLSection
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 14)
            }
            .navigationTitle("Apple NLP Studio")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Sentiment Section
    private var sentimentSection: some View {
        let (score, label) = nlp.analyzeSentiment(text: inputText)
        let normalizedProgress = (score + 1.0) / 2.0 // Map -1...1 to 0...1

        return VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sentiment Analysis")
                        .font(.headline)
                    Text("Computed using Apple's paragraph-level polarity model.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(label)
                    .font(.system(size: 14, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(sentimentColor(for: score).opacity(0.15))
                    .foregroundColor(sentimentColor(for: score))
                    .clipShape(Capsule())
            }

            // Polarity Bar
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [.red, .yellow, .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 16)
                            .opacity(0.8)

                        // Marker Indicator
                        Circle()
                            .fill(Color.white)
                            .frame(width: 22, height: 22)
                            .shadow(radius: 2)
                            .offset(x: max(0, min(geo.size.width - 22, (geo.size.width - 22) * CGFloat(normalizedProgress))))
                    }
                }
                .frame(height: 22)

                HStack {
                    Text("Negative (-1.0)")
                    Spacer()
                    Text("Neutral (0.0)")
                    Spacer()
                    Text("Positive (+1.0)")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            HStack {
                Text("Raw Polarity Score:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%+.3f", score))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sentimentColor(for score: Double) -> Color {
        if score > 0.2 { return .green }
        if score < -0.2 { return .red }
        return .orange
    }

    // MARK: - Named Entities (NER) Section
    private var entitiesSection: some View {
        let entities = nlp.extractEntities(text: inputText)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Named Entity Recognition (NER)")
                        .font(.headline)
                    Text("Identifies People, Organizations, and Places without sending data to servers.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(entities.count) found")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
            }

            if entities.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tag.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No named entities detected.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
                    ForEach(entities) { entity in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: entity.type.icon)
                                    .font(.system(size: 11))
                                Text(entity.type.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(entityColor(for: entity.type))

                            Text(entity.text)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(entityColor(for: entity.type).opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func entityColor(for type: NamedEntity.EntityType) -> Color {
        switch type {
        case .person: return .blue
        case .organization: return .purple
        case .place: return .green
        case .other: return .orange
        }
    }

    // MARK: - Parts of Speech (POS) Section
    private var posSection: some View {
        let tokens = nlp.analyzePartsOfSpeech(text: inputText)

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Grammar & Lexical Analysis")
                    .font(.headline)
                Text("Tokenizes text and tags parts of speech (POS) with dictionary lemmas.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if tokens.isEmpty {
                Text("Enter text above to analyze tokens.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tokens) { token in
                            VStack(spacing: 4) {
                                Text(token.word)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)

                                Text(token.tag)
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(posTagColor(for: token.tag).opacity(0.18))
                                    .foregroundColor(posTagColor(for: token.tag))
                                    .clipShape(Capsule())

                                Text("root: \(token.lemma)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func posTagColor(for tag: String) -> Color {
        switch tag.lowercased() {
        case "noun": return .blue
        case "verb": return .red
        case "adjective": return .purple
        case "adverb": return .orange
        case "pronoun": return .indigo
        case "preposition": return .teal
        default: return .secondary
        }
    }

    // MARK: - Language Detection Section
    private var languagesSection: some View {
        let languages = nlp.detectLanguages(text: inputText)

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Language Identification")
                    .font(.headline)
                Text("Statistical language model determining probability across 50+ languages.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if languages.isEmpty {
                Text("Enter text above to detect language.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(languages) { lang in
                        VStack(spacing: 6) {
                            HStack {
                                Text(lang.flag)
                                    .font(.system(size: 20))
                                Text(lang.localizedName)
                                    .font(.system(size: 14, weight: .semibold))
                                Text("(\(lang.languageCode.uppercased()))")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%.1f%%", lang.confidence * 100))
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.tertiarySystemBackground))
                                        .frame(height: 6)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.blue)
                                        .frame(width: geo.size.width * CGFloat(lang.confidence), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(10)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Word Vectors / Embeddings Section
    private var embeddingsSection: some View {
        let distance = nlp.semanticDistance(word1: vectorWord1, word2: vectorWord2)
        let neighbors = nlp.findSimilarWords(for: neighborSearchWord, count: 5)

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Semantic Word Embeddings")
                    .font(.headline)
                Text("Uses Apple's high-dimensional on-device vector space to calculate semantic similarity.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Word Comparison Card
            VStack(alignment: .leading, spacing: 12) {
                Text("VECTOR DISTANCE CALCULATOR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    TextField("Word 1", text: $vectorWord1)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)

                    Image(systemName: "arrow.left.and.right")
                        .foregroundColor(.secondary)

                    TextField("Word 2", text: $vectorWord2)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                }

                if let dist = distance {
                    let similarity = max(0, 1.0 - (dist / 2.0)) * 100
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cosine Distance: \(String(format: "%.3f", dist))")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                            Text("Semantic Match: \(String(format: "%.1f%%", similarity))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(similarity > 60 ? .green : .blue)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text("Could not calculate distance. Ensure both words exist in the dictionary.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Nearest Neighbor Words Card
            VStack(alignment: .leading, spacing: 12) {
                Text("NEAREST NEIGHBORS IN VECTOR SPACE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                HStack {
                    TextField("Search word (e.g. Technology)", text: $neighborSearchWord)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                }

                if neighbors.isEmpty {
                    Text("No neighbors found. Try common English words like 'Computer', 'Science', or 'Music'.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 6) {
                        ForEach(neighbors, id: \.word) { item in
                            HStack {
                                Text(item.word)
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(String(format: "distance: %.3f", item.distance))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Core ML & On-Device AI Section
    private var coreMLSection: some View {
        let candidateIntents = [
            "Customer Support & Inquiries",
            "Bug Report & Technical Troubleshooting",
            "Product Feature Feedback & Request",
            "Company News & Press Announcement",
            "General Conversation & Creative Chat"
        ]

        let intentScores = candidateIntents.map { intent in
            (intent: intent, score: semanticMatcher.cosineSimilarity(between: inputText, and: intent))
        }.sorted { $0.score > $1.score }

        let topMatch = intentScores.first

        return VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Apple Core ML & On-Device AI")
                        .font(.headline)
                    Text("Hardware-accelerated AI on Apple Silicon (Neural Engine & GPU).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "cpu.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }

            // Apple Silicon Hardware Architecture Status Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.orange)
                    Text("APPLE SILICON HARDWARE STATUS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("ANE Active")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Compute Units")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(".all (ANE + GPU + CPU)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                    Divider().frame(height: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Privacy")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("100% On-Device")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    Divider().frame(height: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Network Calls")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("0 (Offline)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Live On-Device Semantic Intent Classifier Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "scope")
                        .foregroundColor(.blue)
                    Text("LIVE ON-DEVICE INTENT CLASSIFIER")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                    Spacer()
                    if let top = topMatch {
                        Text(String(format: "Top: %.0f%%", top.score * 100))
                            .font(.caption2.bold())
                            .foregroundColor(.blue)
                    }
                }

                Text("Classifies input text against candidate semantic categories using Apple's on-device 512-D sentence embeddings.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    ForEach(intentScores, id: \.intent) { item in
                        let isTop = item.intent == topMatch?.intent
                        VStack(spacing: 4) {
                            HStack {
                                Text(item.intent)
                                    .font(.system(size: 12, weight: isTop ? .bold : .regular))
                                    .foregroundColor(isTop ? .primary : .secondary)
                                Spacer()
                                Text(String(format: "%.1f%%", item.score * 100))
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundColor(isTop ? .blue : .secondary)
                            }

                            // Progress Bar
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color(.tertiarySystemBackground))
                                        .frame(height: 6)
                                    Capsule()
                                        .fill(isTop ? Color.blue : Color.gray.opacity(0.4))
                                        .frame(width: max(4, g.size.width * CGFloat(item.score)), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Code Examples Selector
            VStack(alignment: .leading, spacing: 10) {
                Text("APPLE FRAMEWORK CODE EXAMPLES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                Picker("Code Example", selection: $selectedCodeExample) {
                    ForEach(CoreMLExampleType.allCases) { example in
                        Text(example.rawValue).tag(example)
                    }
                }
                .pickerStyle(.segmented)

                // Code Display Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(codeSnippetTitle)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Swift")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(codeSnippetText)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var codeSnippetTitle: String {
        switch selectedCodeExample {
        case .coreMLInference:
            return "1. Load & Run Core ML Model (.mlpackage)"
        case .neuralEngineConfig:
            return "2. Target Apple Neural Engine (ANE)"
        case .vectorSimilarity:
            return "3. On-Device Semantic Vectors (NaturalLanguage)"
        case .onDeviceLLM:
            return "4. Run Local LLM on Apple Silicon (MLX Swift)"
        }
    }

    private var codeSnippetText: String {
        switch selectedCodeExample {
        case .coreMLInference:
            return """
            import CoreML

            // 1. Configure for Apple Neural Engine & GPU
            let config = MLModelConfiguration()
            config.computeUnits = .all

            // 2. Load compiled model (e.g. TextClassifier.mlmodelc)
            guard let modelURL = Bundle.main.url(forResource: "TextClassifier", withExtension: "mlmodelc") else {
                return
            }
            let model = try await MLModel.load(contentsOf: modelURL, configuration: config)

            // 3. Prepare dictionary input feature provider
            let input = try MLDictionaryFeatureProvider(dictionary: ["text": "Input prompt here"])

            // 4. Run hardware-accelerated prediction
            let output = try await model.prediction(from: input)
            if let label = output.featureValue(for: "label")?.stringValue {
                print("Prediction: \\(label)")
            }
            """

        case .neuralEngineConfig:
            return """
            import CoreML

            // Optimize compute resource allocation
            let config = MLModelConfiguration()

            // .all leverages Apple Neural Engine (ANE), Metal GPU, and CPU
            config.computeUnits = .all

            // Allow low-precision (FP16 / INT8) accumulation for speed
            config.allowLowPrecisionAccumulationOnGPU = true

            // Set model thread pool limits for smooth 120Hz UI
            config.modelDisplayName = "OnDeviceModel"
            """

        case .vectorSimilarity:
            return """
            import NaturalLanguage

            // Built-in 512-dimension vector embedding (zero cloud calls)
            let embedding = NLEmbedding.sentenceEmbedding(for: .english)!

            // Calculate cosine distance (0.0 = identical, 2.0 = opposite)
            let distance = embedding.distance(
                between: "Cancel my subscription",
                and: "Customer Support & Inquiries"
            )

            let similarity = 1.0 - (distance / 2.0)
            print("Semantic Match: \\(similarity * 100)%")
            """

        case .onDeviceLLM:
            return """
            // Using Apple's MLX Swift (or swift-transformers with Core ML)
            import MLX
            import MLXLLM

            // 1. Load quantized local model (e.g. LLaMA-3.2-1B-4bit or SmolLM)
            let modelContainer = try await LLMModelFactory.shared.loadContainer(
                configuration: ModelConfiguration(id: "mlx-community/Llama-3.2-1B-Instruct-4bit")
            )

            // 2. Stream tokens directly on Apple Silicon Metal GPU
            let prompt = "Explain quantum computing in one sentence."
            for try await token in modelContainer.streamResponse(prompt: prompt) {
                print(token, terminator: "")
            }
            """
        }
    }
}
