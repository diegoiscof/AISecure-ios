//
//  ContentView.swift
//  AISecureDemo
//
//  Created by Diego Francisco Oruna Cabrera on 22/12/25.
//

import SwiftUI
import AISecure

struct ContentView: View {

    var body: some View {
        VStack(spacing: 20) {
            Text("AISecure Demo")
                .font(.headline)

            Button("Test OpenAI Direct") {
                Task {
                    await testOpenAI()
                }
            }

            Button("Test Anthropic Direct") {
                Task {
                    await testAnthropic()
                }
            }
        }
        .padding()
        .onAppear {
            AISecure.configure(logLevel: .debug)
        }
    }

    // MARK: - Direct Routing Tests

    /// Test direct OpenAI routing with full feature access
    /// You specify the model in the request
    @MainActor
    func testOpenAI() async {
        do {
            let openAI = try AISecure.openAIService(
                serviceURL: "https://xifm3whdw1.execute-api.us-east-2.amazonaws.com/openai-0c8bef0e834f7294",
                backendURL: "https://str-concord-browsing-helped.trycloudflare.com"
            )

            // With direct routing, YOU specify the model
            let chatResponse = try await openAI.chat(
                messages: [
                    .init(role: "user", content: "Say hello in one sentence in spanish")
                ],
                model: "" // You control which model to use
            )

            print("✅ OpenAI Direct Response:")
            print("   Content:", chatResponse.choices.first?.message.content ?? "")
            print("   Model:", chatResponse.model)
            print("   Tokens:", chatResponse.usage?.totalTokens ?? 0)
        } catch let AISecureError.httpError(status, body) {
            print("❌ OpenAI Direct failed:", status)
            if let jsonData = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted]),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("DEBUG INFO:")
                print(jsonString)
            }
        } catch {
            print("❌ Unexpected error:", error)
        }
    }

    /// Test direct Anthropic routing with full feature access
    @MainActor
    func testAnthropic() async {
        do {
            let anthropic = try AISecure.anthropicService(
                serviceURL: "https://xifm3whdw1.execute-api.us-east-2.amazonaws.com/anthropic-bf08e7c14d1ef2f8",
                backendURL: "https://str-concord-browsing-helped.trycloudflare.com"
            )

            // With direct routing, YOU specify the model
            let response = try await anthropic.createMessage(
                messages: [.init(role: "user", content: "Say a common italian phrase")],
                maxTokens: 100
            )

            print("✅ Anthropic Direct Response:")
            print("   Content:", response.content.first?.text ?? "")
            print("   Model:", response.model)
            print("   Tokens:", response.usage.inputTokens + response.usage.outputTokens)
        } catch let AISecureError.httpError(status, body) {
            print("❌ Anthropic Direct failed:", status)
            if let jsonData = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted]),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("DEBUG INFO:")
                print(jsonString)
            }
        } catch {
            print("❌ Unexpected error:", error)
        }
    }
}

#Preview {
    ContentView()
}
