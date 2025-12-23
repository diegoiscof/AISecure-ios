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

            Button("Test OpenAI") {
                Task {
                    await testOpenAI()
                }
            }

            Button("Test Anthropic") {
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

    @MainActor
    func testOpenAI() async {
        do {
            let openAI = try AISecure.openAIService(
                serviceURL: "https://xifm3whdw1.execute-api.us-east-2.amazonaws.com/openai-df56eb4a4befeb88",
                partialKey: "c2stcHJvai1mb2JLMHNXbUNFZFlVNUd6OUlXR1NyZWxSWXZaTi1ia1lzc18zbDY3aC1Gd1pPaXFiRjZ6ZjdZak1wQUZNUHA5QTlEQWdHcW1QTA==",
                backendURL: "https://bee-extras-intellectual-walt.trycloudflare.com"
            )

            let chatResponse = try await openAI.chat(messages: [
                .init(role: "user", content: "Say hello in one sentence in spanish")
            ])
            print("OpenAI Response:", chatResponse.choices.first?.message.content ?? "")
        } catch let AISecureError.httpError(status, body) {
            print("Request failed:", status)
            if let jsonData = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted]),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("DEBUG INFO:")
                print(jsonString)
            } else {
                print(body)
            }
        } catch {
            print("Unexpected error:", error)
        }
    }

    @MainActor
    func testAnthropic() async {
        do {
            let anthropic = try AISecure.anthropicService(
                serviceURL: "https://xifm3whdw1.execute-api.us-east-2.amazonaws.com/anthropic-8bffcad853d69314",
                partialKey: "c2stYW50LWFwaTAzLXdPSmh6QWRHT2NaTGo1YVdfWUZGb1ZsUzJPZWJtU3BhdDRTbWY3WHNR",
                backendURL: "https://bee-extras-intellectual-walt.trycloudflare.com"
            )

            let response = try await anthropic.createMessage(
                messages: [.init(role: "user", content: "Say a common italian phrase")],
                maxTokens: 100
            )
            print("Anthropic Response:", response.content.first?.text ?? "")
        } catch let AISecureError.httpError(status, body) {
            print("Request failed:", status)
            if let jsonData = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted]),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("DEBUG INFO:")
                print(jsonString)
            } else {
                print(body)
            }
        } catch {
            print("Unexpected error:", error)
        }
    }
}

#Preview {
    ContentView()
}
