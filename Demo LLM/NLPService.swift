//
//  NLPService.swift
//  Demo LLM
//

import Foundation
import NaturalLanguage

public struct NamedEntity: Identifiable, Equatable {
    public let id = UUID()
    public let text: String
    public let type: EntityType
    public let range: Range<String.Index>

    public enum EntityType: String {
        case person = "Person"
        case organization = "Organization"
        case place = "Location"
        case other = "Other"

        public var icon: String {
            switch self {
            case .person: return "person.fill"
            case .organization: return "building.2.fill"
            case .place: return "mappin.and.ellipse"
            case .other: return "tag.fill"
            }
        }
    }
}

public struct POSToken: Identifiable, Equatable {
    public let id = UUID()
    public let word: String
    public let tag: String
    public let lemma: String
}

public struct LanguageCandidate: Identifiable, Equatable {
    public let id = UUID()
    public let languageCode: String
    public let localizedName: String
    public let confidence: Double
    public let flag: String
}

public final class NLPService {
    public static let shared = NLPService()
    private init() {}

    // MARK: - Sentiment Analysis
    public func analyzeSentiment(text: String) -> (score: Double, label: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (0.0, "Neutral")
        }

        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let (sentimentTag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)

        let score = Double(sentimentTag?.rawValue ?? "0") ?? 0.0

        let label: String
        if score > 0.25 {
            label = "Positive"
        } else if score < -0.25 {
            label = "Negative"
        } else {
            label = "Neutral"
        }

        return (score, label)
    }

    // MARK: - Language Detection
    public func detectLanguages(text: String) -> [LanguageCandidate] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        let hypotheses = recognizer.languageHypotheses(withMaximum: 4)
        return hypotheses
            .sorted { $0.value > $1.value }
            .compactMap { (lang, confidence) in
                let code = lang.rawValue
                let name = Locale.current.localizedString(forIdentifier: code) ?? code.uppercased()
                let flag = flagEmoji(for: code)
                return LanguageCandidate(
                    languageCode: code,
                    localizedName: name,
                    confidence: confidence,
                    flag: flag
                )
            }
    }

    // MARK: - Named Entity Recognition (NER)
    public func extractEntities(text: String) -> [NamedEntity] {
        guard !text.isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        let tags: [NLTag] = [.personalName, .placeName, .organizationName]

        var entities: [NamedEntity] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, tokenRange in
            if let tag = tag, tags.contains(tag) {
                let entityText = String(text[tokenRange])
                let type: NamedEntity.EntityType
                switch tag {
                case .personalName:
                    type = .person
                case .placeName:
                    type = .place
                case .organizationName:
                    type = .organization
                default:
                    type = .other
                }
                entities.append(NamedEntity(text: entityText, type: type, range: tokenRange))
            }
            return true
        }

        return entities
    }

    // MARK: - Tokenization & Parts of Speech
    public func analyzePartsOfSpeech(text: String) -> [POSToken] {
        guard !text.isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text
        let options: NLTagger.Options = [.omitWhitespace]

        var tokens: [POSToken] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange in
            let word = String(text[tokenRange])
            let posTag = tag?.rawValue ?? "Punctuation"

            // Get lemma (dictionary root form)
            let (lemmaTag, _) = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lemma)
            let lemma = lemmaTag?.rawValue ?? word.lowercased()

            tokens.append(POSToken(word: word, tag: posTag, lemma: lemma))
            return true
        }

        return tokens
    }

    // MARK: - Word Embeddings & Vector Similarity
    public func semanticDistance(word1: String, word2: String) -> Double? {
        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else { return nil }
        let clean1 = word1.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let clean2 = word2.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard embedding.contains(clean1), embedding.contains(clean2) else { return nil }
        
        let distance = embedding.distance(between: clean1, and: clean2)
        return distance
    }

    public func findSimilarWords(for word: String, count: Int = 6) -> [(word: String, distance: Double)] {
        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else { return [] }
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard embedding.contains(clean) else { return [] }

        return embedding.neighbors(for: clean, maximumCount: count)
    }

    // Helper: Map language code to approximate country flag emoji
    private func flagEmoji(for languageCode: String) -> String {
        let code = languageCode.lowercased()
        let mapping: [String: String] = [
            "en": "🇺🇸", "es": "🇪🇸", "fr": "🇫🇷", "de": "🇩🇪", "it": "🇮🇹",
            "pt": "🇵🇹", "ja": "🇯🇵", "zh": "🇨🇳", "ko": "🇰🇷", "hi": "🇮🇳",
            "ar": "🇸🇦", "ru": "🇷🇺", "nl": "🇳🇱", "sv": "🇸🇪", "tr": "🇹🇷"
        ]
        return mapping[code] ?? "🌐"
    }
}
