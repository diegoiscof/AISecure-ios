//
//  GrokModels.swift
//  SilentLayer
//
//  Created by Diego Francisco Oruna Cabrera on 26/12/25.
//

import Foundation

// MARK: - Grok uses OpenAI-compatible API
// We reuse OpenAI response models for compatibility
// Including OpenAIChatResponse and OpenAIChatStreamDelta

/// Grok-specific request configuration
public struct GrokChatRequest {
    public let messages: [ChatMessage]
    public let model: String
    public let temperature: Double
    public let maxTokens: Int?
    public let stream: Bool

    public init(
        messages: [ChatMessage],
        model: String = "grok-beta",
        temperature: Double = 0.7,
        maxTokens: Int? = nil,
        stream: Bool = false
    ) {
        self.messages = messages
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stream = stream
    }
}

// Grok models available:
// - grok-beta (latest Grok model)
// - grok-vision-beta (with vision capabilities)
