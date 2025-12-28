//
//  OpenAIModels.swift
//  SilentLayer
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation

// MARK: - Chat Models

public struct OpenAIChatResponse: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [OpenAIChatChoice]
    public let usage: OpenAIUsage?

    public struct OpenAIChatChoice: Codable, Sendable {
        public let index: Int
        public let message: OpenAIChatMessage
        public let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }

    public struct OpenAIChatMessage: Codable, Sendable {
        public let role: String
        public let content: String
    }
}

public struct OpenAIUsage: Codable, Sendable {
    public let promptTokens: Int
    public let completionTokens: Int?
    public let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Embeddings

public struct OpenAIEmbeddingsResponse: Codable, Sendable {
    public let object: String
    public let data: [OpenAIEmbedding]
    public let model: String
    public let usage: OpenAIUsage

    public struct OpenAIEmbedding: Codable, Sendable {
        public let object: String
        public let embedding: [Double]
        public let index: Int
    }
}

// MARK: - Image Generation (DALL-E)

public struct OpenAIImageGenerationResponse: Codable, Sendable {
    public let created: Int
    public let data: [OpenAIImage]

    public struct OpenAIImage: Codable, Sendable {
        public let url: String?
        public let b64Json: String?
        public let revisedPrompt: String?

        enum CodingKeys: String, CodingKey {
            case url
            case b64Json = "b64_json"
            case revisedPrompt = "revised_prompt"
        }
    }
}

// MARK: - Audio Transcription (Whisper)

public struct OpenAITranscriptionResponse: Codable, Sendable {
    public let text: String
    public let language: String?
    public let duration: Double?
    public let words: [TranscriptionWord]?
    public let segments: [TranscriptionSegment]?

    public struct TranscriptionWord: Codable, Sendable {
        public let word: String
        public let start: Double
        public let end: Double
    }

    public struct TranscriptionSegment: Codable, Sendable {
        public let id: Int
        public let seek: Int
        public let start: Double
        public let end: Double
        public let text: String
        public let tokens: [Int]
        public let temperature: Double
        public let avgLogprob: Double
        public let compressionRatio: Double
        public let noSpeechProb: Double

        enum CodingKeys: String, CodingKey {
            case id, seek, start, end, text, tokens, temperature
            case avgLogprob = "avg_logprob"
            case compressionRatio = "compression_ratio"
            case noSpeechProb = "no_speech_prob"
        }
    }
}

// MARK: - Streaming Chat Models

/// Streaming response chunk from OpenAI chat completions
public struct OpenAIChatStreamDelta: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [StreamChoice]

    public struct StreamChoice: Codable, Sendable {
        public let index: Int
        public let delta: Delta
        public let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case index, delta
            case finishReason = "finish_reason"
        }
    }

    public struct Delta: Codable, Sendable {
        public let role: String?
        public let content: String?
    }

    public init(id: String, object: String, created: Int, model: String, choices: [StreamChoice]) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.choices = choices
    }
}

// MARK: - Moderation

public struct OpenAIModerationResponse: Codable, Sendable {
    public let id: String
    public let model: String
    public let results: [ModerationResult]

    public struct ModerationResult: Codable, Sendable {
        public let flagged: Bool
        public let categories: ModerationCategories
        public let categoryScores: ModerationCategoryScores

        enum CodingKeys: String, CodingKey {
            case flagged, categories
            case categoryScores = "category_scores"
        }
    }

    public struct ModerationCategories: Codable, Sendable {
        public let hate: Bool
        public let hateThreatening: Bool
        public let harassment: Bool
        public let harassmentThreatening: Bool
        public let selfHarm: Bool
        public let selfHarmIntent: Bool
        public let selfHarmInstructions: Bool
        public let sexual: Bool
        public let sexualMinors: Bool
        public let violence: Bool
        public let violenceGraphic: Bool

        enum CodingKeys: String, CodingKey {
            case hate
            case hateThreatening = "hate/threatening"
            case harassment
            case harassmentThreatening = "harassment/threatening"
            case selfHarm = "self-harm"
            case selfHarmIntent = "self-harm/intent"
            case selfHarmInstructions = "self-harm/instructions"
            case sexual
            case sexualMinors = "sexual/minors"
            case violence
            case violenceGraphic = "violence/graphic"
        }
    }

    public struct ModerationCategoryScores: Codable, Sendable {
        public let hate: Double
        public let hateThreatening: Double
        public let harassment: Double
        public let harassmentThreatening: Double
        public let selfHarm: Double
        public let selfHarmIntent: Double
        public let selfHarmInstructions: Double
        public let sexual: Double
        public let sexualMinors: Double
        public let violence: Double
        public let violenceGraphic: Double

        enum CodingKeys: String, CodingKey {
            case hate
            case hateThreatening = "hate/threatening"
            case harassment
            case harassmentThreatening = "harassment/threatening"
            case selfHarm = "self-harm"
            case selfHarmIntent = "self-harm/intent"
            case selfHarmInstructions = "self-harm/instructions"
            case sexual
            case sexualMinors = "sexual/minors"
            case violence
            case violenceGraphic = "violence/graphic"
        }
    }
}

// MARK: - Responses API

/// Streaming event from OpenAI's Responses API
/// The Responses API uses event-based SSE format with event names
public struct OpenAIResponseStreamEvent: Codable, Sendable {
    public let type: String
    public let sequenceNumber: Int?
    public let response: OpenAIResponseObject?
    public let outputIndex: Int?
    public let contentIndex: Int?
    public let itemId: String?
    public let delta: String?
    public let text: String?

    enum CodingKeys: String, CodingKey {
        case type
        case sequenceNumber = "sequence_number"
        case response
        case outputIndex = "output_index"
        case contentIndex = "content_index"
        case itemId = "item_id"
        case delta
        case text
    }
}

/// Response from OpenAI's Responses API
/// This is OpenAI's most advanced interface for generating model responses
public struct OpenAIResponseObject: Codable, Sendable {
    public let id: String?
    public let createdAt: Double?
    public let model: String?
    public let output: [ResponseOutputItem]?
    public let status: Status?
    public let usage: ResponseUsage?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case model
        case output
        case status
        case usage
    }

    public enum Status: String, Codable, Sendable {
        case completed
        case failed
        case incomplete
        case inProgress = "in_progress"
    }

    public struct ResponseUsage: Codable, Sendable {
        public let inputTokens: Int?
        public let outputTokens: Int?
        public let totalTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case totalTokens = "total_tokens"
        }
    }

    public enum ResponseOutputItem: Codable, Sendable {
        case message(ResponseOutputMessage)
        case reasoning(ReasoningOutput)

        enum CodingKeys: String, CodingKey {
            case type
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "message":
                self = .message(try ResponseOutputMessage(from: decoder))
            case "reasoning":
                self = .reasoning(try ReasoningOutput(from: decoder))
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .type,
                    in: container,
                    debugDescription: "Unknown output item type: \(type)"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            switch self {
            case .message(let msg):
                try msg.encode(to: encoder)
            case .reasoning(let reasoning):
                try reasoning.encode(to: encoder)
            }
        }
    }

    public struct ResponseOutputMessage: Codable, Sendable {
        public let content: [Content]
        public let role: String?

        public enum Content: Codable, Sendable {
            case outputText(String)
            case refusal(String)

            enum CodingKeys: String, CodingKey {
                case type, text, refusal
            }

            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                let type = try container.decode(String.self, forKey: .type)

                switch type {
                case "output_text":
                    let text = try container.decode(String.self, forKey: .text)
                    self = .outputText(text)
                case "refusal":
                    let refusal = try container.decode(String.self, forKey: .refusal)
                    self = .refusal(refusal)
                default:
                    throw DecodingError.dataCorruptedError(
                        forKey: .type,
                        in: container,
                        debugDescription: "Unknown content type: \(type)"
                    )
                }
            }

            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                switch self {
                case .outputText(let text):
                    try container.encode("output_text", forKey: .type)
                    try container.encode(text, forKey: .text)
                case .refusal(let refusal):
                    try container.encode("refusal", forKey: .type)
                    try container.encode(refusal, forKey: .refusal)
                }
            }
        }
    }

    public struct ReasoningOutput: Codable, Sendable {
        public let id: String?

        enum CodingKeys: String, CodingKey {
            case type, id
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decodeIfPresent(String.self, forKey: .id)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("reasoning", forKey: .type)
            try container.encodeIfPresent(id, forKey: .id)
        }
    }
}

// MARK: - Image Editing

/// Response from image editing endpoint
public typealias OpenAIImageEditResponse = OpenAIImageGenerationResponse
