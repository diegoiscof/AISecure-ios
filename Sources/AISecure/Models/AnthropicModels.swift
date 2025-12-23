//
//  AnthropicModels.swift
//  AISecure
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation

// MARK: - Message Models

public struct AnthropicMessage: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct AnthropicMessageResponse: Codable, Sendable {
    public let id: String
    public let type: String
    public let role: String
    public let content: [Content]
    public let model: String
    public let stopReason: String?
    public let usage: Usage

    public struct Content: Codable, Sendable {
        public let type: String
        public let text: String?
    }

    public struct Usage: Codable, Sendable {
        public let inputTokens: Int
        public let outputTokens: Int

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model, usage
        case stopReason = "stop_reason"
    }
}
