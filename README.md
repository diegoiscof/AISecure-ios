![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS-blue.svg)
![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)

# SilentLayer iOS/macOS SDK
### Mobile-first AI infrastructure for mobile apps

SilentLayer is a hardened iOS SDK that provides a secure gateway to AI providers (OpenAI, Anthropic, Google, xAI and more coming soon). It manages provider access, request validation, and usage enforcement while keeping API keys fully server-side.

## Overview

SilentLayer is built for mobile developers who want to integrate AI quickly without building or operating backend infrastructure.

Integrate in under a minute: install the SDK, add your service ID, and start making AI requests. No backend setup, no API keys in your app, and no provider-specific logic to maintain.

SilentLayer sits between your app and AI providers, handling authentication, streaming, rate limiting, and usage tracking so you can ship production-ready AI features with minimal setup.


**Key Benefits:**
- **Multi-Provider Access**: Unified SDK for OpenAI, Anthropic, Gemini, and Grok. Switch models without client changes.
- **Usage Monitoring & Limits**: Track usage per device and enforce hourly, daily, or monthly caps.
- **Secure Key Handling**: Provider API keys never reach client apps and are enforced server-side.
- **Streaming Support**: Native support for real-time and streaming responses.
- **Tiered Plans**: Free tier available, with higher limits and advanced controls on paid plans.
- **Developer-Friendly**: Fast setup, minimal configuration, and no backend required.

## Security Architecture

### Split Key Strategy

SilentLayer uses a split-key control model to prevent full API key exposure while maintaining server-side enforcement.

- Clients never receive or handle provider API keys.
- Credentials are time-bound, scoped, and validated per request.
- Full keys are never persisted or returned to the client.

This design minimizes blast radius while allowing secure, high-throughput access to multiple AI providers.

### Request Security
- **Authenticated**: Short-lived credentials automatically refreshed by the SDK.
- **Signed**: Requests are cryptographically signed to prevent tampering.
- **Device-Bound**: Requests are bound to a device fingerprint.
- **Replay-Protected**: Duplicate or replayed requests are rejected.

### Additional Controls
- **Rate Limiting**: Enforced per device, with account-level caps by plan.
- **Data Protection**: Encrypted in transit; no provider keys in client apps.
- **Zero-Trust**: Every request is independently validated.

## Requirements
- iOS 15.0+ / macOS 12.0+
- Swift 5.9+
- Xcode 15.0+

## Installation
### Swift Package Manager
Add SilentLayer to your project via Xcode:
1. Go to **File → Add Package Dependencies**
2. Enter the repository URL:
```
https://github.com/diegoiscof/SilentLayer-ios.git
```
3. Select the latest version and add to your target

Or add it to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/diegoiscof/SilentLayer-ios.git", from: "1.0.0")
]
```

## Quick Start
### 1. Initialize and request
Get your Service URL from the [SilentLayer Dashboard](https://dashboard.silentlayer.ai).
```swift
import SilentLayer

// 1. Initialize the service
let openAI = try SilentLayer.openAIService(
    serviceURL: "https://gateway.silentlayer.ai/openai-svc_7f291a"
)

// 2. Make a request
Task {
    do {
        let response = try await openAI.chat(
            messages: [ChatMessage(role: "user", content: "Explain Swift in one sentence.")],
            model: "gpt-4o-mini" // Optional. If not provided, it can be adjusted later from the dashboard without redeploying.
        )
        print(response.choices.first?.message.content ?? "")
    } catch {
        print("Error: \(error)")
    }
}
```

## Configuration
### Logging
Configure logging level and optional timestamps for debugging:
```swift
// Production: Minimal logging
SilentLayer.configure(logLevel: .error)
// Development: Verbose logging with timestamps
SilentLayer.configure(logLevel: .debug, timestamps: true)
```

**Log Levels:**
| Level | Description |
|-------|-------------|
| `.debug` | Detailed information for debugging |
| `.info` | General operational information |
| `.warning` | Potential issues |
| `.error` | Errors (default) |
| `.critical` | Critical failures |
| `.none` | Disable logging |

## Providers
### OpenAI
```swift
let openAI = try SilentLayer.openAIService(
    serviceURL: "https://gateway.silentlayer.ai/openai-your-service-id"
)
```

**Supported Features:**
- Chat Completions
- Streaming Responses
- Structured Outputs (JSON Schema)
- Reasoning Models (o1, o3)
- Responses API
- Image Generation (DALL-E)
- Embeddings
- Text-to-Speech
- Content Moderation

### Anthropic
```swift
let anthropic = try SilentLayer.anthropicService(
    serviceURL: "https://gateway.silentlayer.ai/anthropic-your-service-id"
)
```

**Supported Features:**
- Messages API (Claude 3.5, Claude 3)
- Streaming Responses
- Vision (Image Inputs)

### Google Gemini
```swift
let gemini = try SilentLayer.geminiService(
    serviceURL: "https://gateway.silentlayer.ai/google-your-service-id"
)
```

**Supported Features:**
- Content Generation
- Streaming Responses

### xAI Grok
```swift
let grok = try SilentLayer.grokService(
    serviceURL: "https://gateway.silentlayer.ai/grok-your-service-id"
)
```

**Supported Features:**
- Chat Completions (OpenAI-compatible)
- Streaming Responses
- Vision Capabilities

## Usage Examples
### Chat Completion
```swift
let response = try await openAI.chat(
    messages: [
        ChatMessage(role: "system", content: "You are a helpful assistant."),
        ChatMessage(role: "user", content: "What is Swift?")
    ],
    model: "gpt-4o-mini",
    temperature: 0.7
)
if let content = response.choices.first?.message.content {
    print(content)
}
```

### Streaming
```swift
try await openAI.chatStream(
    messages: [ChatMessage(role: "user", content: "Write a short story.")],
    model: "gpt-4o-mini"
) { delta in
    if let content = delta.choices.first?.delta.content {
        print(content, terminator: "")
    }
}
```

### Structured Output (JSON Schema)
```swift
let schema: [String: Any] = [
    "type": "object",
    "properties": [
        "name": ["type": "string"],
        "age": ["type": "number"]
    ],
    "required": ["name", "age"],
    "additionalProperties": false
]
let response = try await openAI.chat(
    messages: [ChatMessage(role: "user", content: "Generate a person profile")],
    model: "gpt-4o-mini",
    responseFormat: .jsonSchema(name: "person", schema: schema, strict: true)
)
```

### Image Generation
```swift
let response = try await openAI.generateImage(
    prompt: "A sunset over mountains",
    model: "dall-e-3",
    size: "1024x1024",
    quality: "standard"
)
if let url = response.data.first?.url {
    print("Image URL: \(url)")
}
```

### Text-to-Speech
```swift
let audioData = try await openAI.textToSpeech(
    input: "Hello, welcome to SilentLayer.",
    model: "tts-1",
    voice: "alloy"
)
// Play audio using AVAudioPlayer
let player = try AVAudioPlayer(data: audioData)
player.play()
```

### Embeddings
```swift
let response = try await openAI.embeddings(
    input: ["Hello world", "How are you?"],
    model: "text-embedding-ada-002"
)
for embedding in response.data {
    print("Dimensions: \(embedding.embedding.count)")
}
```

### Anthropic Messages
```swift
let response = try await anthropic.createMessage(
    messages: [AnthropicMessage(role: "user", content: "Hello Claude!")],
    model: "claude-sonnet-4-5-20250929",
    maxTokens: 1024
)
if let text = response.content.first?.text {
    print(text)
}
```

### Anthropic Streaming
```swift
try await anthropic.createMessageStream(
    messages: [AnthropicMessage(role: "user", content: "Tell me a story.")],
    maxTokens: 1024
) { delta in
    if let text = delta.delta?.text {
        print(text, terminator: "")
    }
}
```

### Gemini Content Generation
```swift
let response = try await gemini.generateContent(
    prompt: "Explain quantum computing",
    model: "gemini-2.0-flash-exp"
)
if let text = response.candidates?.first?.content?.parts.first?.text {
    print(text)
}
```

### Grok Chat
```swift
let response = try await grok.chat(
    messages: [ChatMessage(role: "user", content: "Hello Grok!")],
    model: "grok-2-latest"
)
if let content = response.choices.first?.message.content {
    print(content)
}
```

## Error Handling
SilentLayer provides typed errors for proper error handling:
```swift
do {
    let response = try await openAI.chat(
        messages: [ChatMessage(role: "user", content: "Hello")],
        model: "gpt-4o-mini"
    )
} catch let error as SilentLayerError {
    switch error {
    case .httpError(let status, let body):
        print("HTTP \(status): \(body.message ?? "Unknown error")")
       
    case .rateLimited(let info):
        print("Rate limited. Retry after \(info.retryAfter) seconds.")
       
    case .serviceUnavailable(let retryAfter, let reason):
        print("Service unavailable: \(reason). Retry after \(retryAfter)s")
       
    case .networkError(let message):
        print("Network error: \(message)")
       
    case .decodingError(let message):
        print("Failed to decode response: \(message)")
       
    case .invalidConfiguration(let message):
        print("Configuration error: \(message)")
       
    default:
        print("Error: \(error.localizedDescription)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

### Checking Retryable Errors
```swift
if let slError = error as? SilentLayerError, slError.isRetryable {
    if let retryAfter = slError.retryAfter {
        // Wait and retry
        try await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000)
        // Retry request...
    }
}
```

## Best Practices

### 1. Handle Errors Gracefully
Always handle potential errors and provide user feedback:
```swift
func sendMessage(_ text: String) async {
    do {
        let response = try await openAI.chat(
            messages: [ChatMessage(role: "user", content: text)],
            model: "gpt-4o-mini"
        )
        // Handle success
    } catch let error as SilentLayerError {
        switch error {
        case .rateLimited:
            showAlert("You've reached your usage limit. Please try again later.")
        case .networkError:
            showAlert("Network error. Please check your connection.")
        default:
            showAlert("Something went wrong. Please try again.")
        }
    } catch {
        showAlert("An unexpected error occurred.")
    }
}
```

### 2. Use Streaming for Long Responses
For better user experience with longer responses, use streaming:
```swift
@MainActor
func streamResponse() async {
    responseText = ""
   
    do {
        try await openAI.chatStream(
            messages: messages,
            model: "gpt-4o-mini"
        ) { [weak self] delta in
            if let content = delta.choices.first?.delta.content {
                Task { @MainActor in
                    self?.responseText += content
                }
            }
        }
    } catch {
        // Handle error
    }
}
```

## Thread Safety
All SilentLayer services are thread-safe and can be used from any actor or thread. The SDK uses Swift's actor isolation internally to ensure safe concurrent access.
```swift
// Safe to call from any context
Task {
    let response = try await openAI.chat(...)
}
Task.detached {
    let response = try await openAI.chat(...)
}
```

## SwiftUI Integration Example
```swift
import SwiftUI
import SilentLayer

@Observable
class ChatViewModel {
    var messages: [ChatMessage] = []
    private var service: OpenAIService?

    init() {
        self.service = try? SilentLayer.openAIService(
            serviceURL: "https://gateway.silentlayer.ai/openai-svc_7f291a"
        )
    }

    func send(text: String) async {
        guard let service = service else { return }
        
        let userMsg = ChatMessage(role: "user", content: text)
        messages.append(userMsg)

        do {
            let response = try await service.chat(messages: messages, model: "gpt-4o")
            if let reply = response.choices.first?.message {
                messages.append(reply)
            }
        } catch let error as SilentLayerError {
            print("SDK Error: \(error.localizedDescription)")
        } catch {
            print("Unexpected error")
        }
    }
}
```

## Troubleshooting
### Common Issues
**"Invalid service URL"**
Ensure you're using the complete Service URL from your dashboard, including the protocol:
```swift
// Correct
"https://gateway.silentlayer.ai/openai-abc123"
// Incorrect
"gateway.silentlayer.ai/openai-abc123"
```

**"Rate limit exceeded"**
Your project has reached its usage limit. Check your dashboard for current usage and consider upgrading your plan.

**"Authentication failed"**
The SDK handles authentication automatically. If you see this error:
1. Verify your Service URL is correct.
2. Ensure the service is active in your dashboard.
3. Check that your subscription is active.

## Support
- **Documentation**: [docs.silentlayer.ai](https://docs.silentlayer.ai) (coming soon)
- **Dashboard**: [dashboard.silentlayer.ai](https://dashboard.silentlayer.ai)
- **Email**: diego@silentlayer.ai

## License
SilentLayer iOS SDK is available under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

---
© 2025 SilentLayer. All rights reserved.
