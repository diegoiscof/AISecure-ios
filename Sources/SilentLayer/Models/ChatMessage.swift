//
//  ChatMessage.swift
//  SilentLayer
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import Foundation

public struct ChatMessage: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}
