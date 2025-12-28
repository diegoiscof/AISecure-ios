//
//  GeminiModels.swift
//  SilentLayer
//
//  Created by Diego Francisco Oruna Cabrera on 25/12/25.
//

import Foundation

// MARK: - Generate Content

public struct GeminiGenerateContentResponse: Codable, Sendable {
    public let candidates: [GeminiCandidate]?
    public let usageMetadata: GeminiUsageMetadata?
    public let modelVersion: String?

    enum CodingKeys: String, CodingKey {
        case candidates
        case usageMetadata
        case modelVersion
    }
}

public struct GeminiCandidate: Codable, Sendable {
    public let content: GeminiContent?
    public let finishReason: String?
    public let safetyRatings: [GeminiSafetyRating]?
    public let citationMetadata: GeminiCitationMetadata?

    enum CodingKeys: String, CodingKey {
        case content
        case finishReason
        case safetyRatings
        case citationMetadata
    }
}

public struct GeminiContent: Codable, Sendable {
    public let parts: [GeminiPart]
    public let role: String?
}

public struct GeminiPart: Codable, Sendable {
    public let text: String?
    public let inlineData: GeminiInlineData?
    public let fileData: GeminiFileData?

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inline_data"
        case fileData = "file_data"
    }
}

public struct GeminiInlineData: Codable, Sendable {
    public let mimeType: String
    public let data: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case data
    }
}

public struct GeminiFileData: Codable, Sendable {
    public let mimeType: String
    public let fileUri: String

    enum CodingKeys: String, CodingKey {
        case mimeType = "mime_type"
        case fileUri = "file_uri"
    }
}

public struct GeminiSafetyRating: Codable, Sendable {
    public let category: String
    public let probability: String
}

public struct GeminiCitationMetadata: Codable, Sendable {
    public let citationSources: [GeminiCitationSource]?

    enum CodingKeys: String, CodingKey {
        case citationSources = "citation_sources"
    }
}

public struct GeminiCitationSource: Codable, Sendable {
    public let startIndex: Int?
    public let endIndex: Int?
    public let uri: String?
    public let license: String?

    enum CodingKeys: String, CodingKey {
        case startIndex
        case endIndex
        case uri
        case license
    }
}

public struct GeminiUsageMetadata: Codable, Sendable {
    public let promptTokenCount: Int?
    public let candidatesTokenCount: Int?
    public let totalTokenCount: Int?

    enum CodingKeys: String, CodingKey {
        case promptTokenCount
        case candidatesTokenCount
        case totalTokenCount
    }
}

// MARK: - Safety Settings

public struct GeminiSafetySetting: Codable, Sendable {
    public let category: String
    public let threshold: String

    public init(category: String, threshold: String) {
        self.category = category
        self.threshold = threshold
    }
}

// MARK: - Generation Config

public struct GeminiGenerationConfig: Codable, Sendable {
    public let temperature: Double?
    public let topP: Double?
    public let topK: Int?
    public let candidateCount: Int?
    public let maxOutputTokens: Int?
    public let stopSequences: [String]?

    enum CodingKeys: String, CodingKey {
        case temperature
        case topP
        case topK
        case candidateCount
        case maxOutputTokens
        case stopSequences
    }

    public init(
        temperature: Double? = nil,
        topP: Double? = nil,
        topK: Int? = nil,
        candidateCount: Int? = nil,
        maxOutputTokens: Int? = nil,
        stopSequences: [String]? = nil
    ) {
        self.temperature = temperature
        self.topP = topP
        self.topK = topK
        self.candidateCount = candidateCount
        self.maxOutputTokens = maxOutputTokens
        self.stopSequences = stopSequences
    }
}
