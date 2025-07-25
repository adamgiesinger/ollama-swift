import Foundation
import Testing

@testable import Ollama

@Suite(
    .serialized,
    .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil)
)
struct ClientTests {
    let ollama: Client

    init() async {
        ollama = await Client(host: Client.defaultHost)
    }

    @Test
    func testGenerateWithImage() async throws {
        // Create a transparent 1x1 pixel image
        let imageData = Data(
            base64Encoded:
                "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII="
        )!
        let prompt = "Describe this image in detail."

        let response = try await ollama.generate(
            model: "llama3.2",
            prompt: prompt,
            images: [imageData]
        )

        #expect(!response.response.isEmpty)
        #expect(response.done)
        #expect(response.model == "llama3.2")
        #expect(response.totalDuration ?? 0 > 0)
        #expect(response.loadDuration ?? 0 > 0)
        #expect(response.promptEvalCount ?? 0 > 0)
    }

    @Test
    func testGenerateStream() async throws {
        let response = await ollama.generateStream(
            model: "llama3.2",
            prompt: "Write a haiku about llamas."
        )

        var collect: [String] = []
        for try await res in response {
            collect.append(res.response)
        }

        #expect(!collect.isEmpty)
    }

    @Test
    func testChatCompletion() async throws {
        let messages: [Chat.Message] = [
            .system("You are a helpful AI assistant."),
            .user("Write a haiku about llamas."),
        ]

        let response = try await ollama.chat(
            model: "llama3.2",
            messages: messages)
        #expect(!response.message.content.isEmpty)
    }

    @Test
    func testChatStream() async throws {
        let messages: [Chat.Message] = [
            .system("You are a helpful AI assistant."),
            .user("Write a haiku about llamas."),
        ]

        let response = try await ollama.chatStream(
            model: "llama3.2",
            messages: messages)

        var collect: [String] = []
        for try await res in response {
            collect.append(res.message.content)
        }

        #expect(!collect.isEmpty)
    }

    @Test
    func testEmbed() async throws {
        let input = "This is a test sentence for embedding."
        let response = try await ollama.embed(model: "llama3.2", input: input)

        #expect(!response.embeddings.rawValue.isEmpty)
        #expect(response.totalDuration > 0)
        #expect(response.loadDuration > 0)
        #expect(response.promptEvalCount > 0)
    }

    @Test
    func testBatchEmbed() async throws {
        let inputs = [
            "This is the first test sentence.",
            "This is the second test sentence.",
            "This is the third test sentence.",
        ]
        let response = try await ollama.embed(model: "llama3.2", inputs: inputs)

        #expect(response.embeddings.rawValue.count == inputs.count)
        #expect(!response.embeddings.rawValue.isEmpty)
        #expect(response.totalDuration > 0)
        #expect(response.loadDuration > 0)
        #expect(response.promptEvalCount > 0)

        // Verify each embedding is non-empty
        for embedding in response.embeddings.rawValue {
            #expect(!embedding.isEmpty)
        }
    }

    @Test
    func testListModels() async throws {
        let response = try await ollama.listModels()

        #expect(!response.models.isEmpty)
        #expect(response.models.first != nil)
    }

    @Test
    func testListRunningModels() async throws {
        let _ = try await ollama.listRunningModels()
    }

    @Test
    func testVersion() async throws {
        let response = try await ollama.version()

        #expect(!response.version.isEmpty)
        #expect(response.version.contains("."))
    }

    @Test(.disabled())
    func testCreateShowDeleteModel() async throws {
        let base = "llama3.2"
        let name: Model.ID = "test-\(UUID().uuidString)"
        let modelfile =
            """
            FROM \(base)
            PARAMETER temperature 0.7
            """

        // Create model
        var success = try await ollama.createModel(name: name, modelfile: modelfile)
        #expect(success)

        // Show model
        let response = try await ollama.showModel(name)
        #expect(response.details.parentModel?.hasPrefix(base + ":") ?? false)

        // Delete model
        success = try await ollama.deleteModel(name)
        #expect(success)

        // Verify deletion
        do {
            _ = try await ollama.showModel(name)
            Issue.record("Model should have been deleted")
        } catch {
            // Expected error
        }
    }

    @Test
    func testGenerateWithFormat() async throws {
        // Test string format
        do {
            let response = try await ollama.generate(
                model: "llama3.2",
                prompt: "List 3 colors and their hex codes.",
                format: "json"
            )

            #expect(!response.response.isEmpty)
            #expect(response.done)

            // Verify response is valid JSON
            let data = response.response.data(using: .utf8)!
            let _ = try JSONSerialization.jsonObject(with: data)
        }

        // Test JSON schema format
        do {
            let schema: Value = [
                "type": "object",
                "properties": [
                    "colors": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "name": ["type": "string"],
                                "hex": ["type": "string"],
                            ],
                            "required": ["name", "hex"],
                        ],
                    ]
                ],
                "required": ["colors"],
            ]

            let response = try await ollama.generate(
                model: "llama3.2",
                prompt: "List 3 colors and their hex codes.",
                format: schema
            )

            #expect(!response.response.isEmpty)
            #expect(response.done)

            // Verify response matches schema
            let data = response.response.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            #expect(json["colors"] is [[String: String]])
        }
    }

    @Test
    func testChatWithFormat() async throws {
        let messages: [Chat.Message] = [
            .system("You are a helpful AI assistant."),
            .user("List 3 programming languages and when they were created."),
        ]

        // Test string format
        do {
            let response = try await ollama.chat(
                model: "llama3.2",
                messages: messages,
                format: "json"
            )

            #expect(!response.message.content.isEmpty)

            // Verify response is valid JSON
            let data = response.message.content.data(using: .utf8)!
            let _ = try JSONSerialization.jsonObject(with: data)
        }

        // Test JSON schema format
        do {
            let schema: Value = [
                "type": "object",
                "properties": [
                    "languages": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "name": ["type": "string"],
                                "year": ["type": "integer"],
                                "creator": ["type": "string"],
                            ],
                            "required": ["name", "year"],
                        ],
                    ]
                ],
                "required": ["languages"],
            ]

            let response = try await ollama.chat(
                model: "llama3.2",
                messages: messages,
                format: schema
            )

            #expect(!response.message.content.isEmpty)

            // Verify response matches schema
            let data = response.message.content.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
            #expect(json["languages"] is [[String: Any]])
        }
    }

    @Test
    func testChatWithTool() async throws {
        let messages: [Chat.Message] = [
            .system(
                """
                You are a helpful AI assistant that can convert colors.
                When asked about colors, use the rgb_to_hex tool to convert them.
                """),
            .user("What's the hex code for yellow?"),
        ]

        let response = try await ollama.chat(
            model: "llama3.2",
            messages: messages,
            tools: [hexColorTool]
        )

        #expect(response.message.toolCalls?.count == 1)
        guard let toolCall = response.message.toolCalls?.first else {
            Issue.record("No tool call found in response")
            return
        }

        #expect(toolCall.function.name == "rgb_to_hex")
        let args = toolCall.function.arguments
        guard let red = Double(args["red"]!, strict: false),
            let green = Double(args["green"]!, strict: false),
            let blue = Double(args["blue"]!, strict: false)
        else {
            Issue.record("Failed to convert arguments to Double")
            return
        }
        #expect(red == 1.0)
        #expect(green == 1.0)
        #expect(blue == 0.0)
    }

    @Test
    func testChatStreamWithTool() async throws {
        let messages: [Chat.Message] = [
            .system(
                """
                You are a helpful AI assistant that can convert colors.
                When asked about colors, use the rgb_to_hex tool to convert them.
                """),
            .user("What's the hex code for yellow?"),
        ]

        let stream = try await ollama.chatStream(
            model: "llama3.2",
            messages: messages,
            tools: [hexColorTool]
        )

        var foundToolCall = false

        for try await res in stream {
            // Check for tool calls in the message
            if let toolCalls = res.message.toolCalls,
                let toolCall = toolCalls.first,
                toolCall.function.name == "rgb_to_hex"
            {
                foundToolCall = true

                // Check if we can get the color values
                if let redValue = toolCall.function.arguments["red"],
                    let greenValue = toolCall.function.arguments["green"],
                    let blueValue = toolCall.function.arguments["blue"]
                {
                    // Try to convert to Double and validate
                    if let redDouble = Double(redValue, strict: false),
                        let greenDouble = Double(greenValue, strict: false),
                        let blueDouble = Double(blueValue, strict: false)
                    {
                        // Verify yellow color values (1.0, 1.0, 0.0)
                        #expect(redDouble == 1.0, "Invalid red value: \(redDouble)")
                        #expect(greenDouble == 1.0, "Invalid green value: \(greenDouble)")
                        #expect(blueDouble == 0.0, "Invalid blue value: \(blueDouble)")
                    }
                }
            }
        }

        #expect(foundToolCall, "No tool call found in any stream message")
    }

    @Test
    func testGenerateWithThinking() async throws {
        // Test with thinking enabled (using deepseek-r1 which supports thinking)
        do {
            let response = try await ollama.generate(
                model: "deepseek-r1:8b",
                prompt: "What is 9.9 + 9.11? Think about this carefully.",
                think: true
            )

            #expect(!response.response.isEmpty)
            #expect(response.done)
            #expect(response.thinking != nil)
            #expect(!response.thinking!.isEmpty)
            #expect(response.model.rawValue.contains("deepseek-r1"))
        } catch {
            // Model might not be available, skip this test
            print("Skipping thinking test: \(error)")
        }
    }

    @Test
    func testGenerateStreamWithThinking() async throws {
        // Test streaming with thinking enabled
        do {
            let stream = await ollama.generateStream(
                model: "deepseek-r1:8b",
                prompt: "Count from 1 to 5. Show your reasoning.",
                think: true
            )

            var responses: [Client.GenerateResponse] = []
            var foundThinking = false

            for try await res in stream {
                responses.append(res)
                if res.thinking != nil && !res.thinking!.isEmpty {
                    foundThinking = true
                }
            }

            #expect(!responses.isEmpty)
            #expect(foundThinking, "Expected to find thinking content in stream")
        } catch {
            // Model might not be available, skip this test
            print("Skipping thinking stream test: \(error)")
        }
    }

    @Test
    func testGenerateWithoutThinking() async throws {
        // Test with thinking explicitly disabled
        let response = try await ollama.generate(
            model: "llama3.2",
            prompt: "What is 2 + 2?",
            think: false
        )

        #expect(!response.response.isEmpty)
        #expect(response.done)
        // Should not have thinking content when disabled
        #expect(response.thinking == nil)
    }

    @Test
    func testChatWithThinking() async throws {
        let messages: [Chat.Message] = [
            .system("You are a helpful mathematician."),
            .user("What is 17 * 23? Please show your reasoning step by step."),
        ]

        // Test with thinking enabled (using deepseek-r1 which supports thinking)
        do {
            let response = try await ollama.chat(
                model: "deepseek-r1:8b",
                messages: messages,
                think: true
            )

            #expect(!response.message.content.isEmpty)
            #expect(response.message.role == .assistant)
            #expect(response.message.thinking != nil)
            #expect(!response.message.thinking!.isEmpty)
        } catch {
            // Model might not be available, skip this test
            print("Skipping chat thinking test: \(error)")
        }
    }

    @Test
    func testChatStreamWithThinking() async throws {
        let messages: [Chat.Message] = [
            .system("You are a helpful assistant."),
            .user(
                "Solve this riddle: I have cities, but no houses. I have mountains, but no trees. What am I?"
            ),
        ]

        // Test streaming with thinking enabled
        do {
            let stream = try await ollama.chatStream(
                model: "deepseek-r1:8b",
                messages: messages,
                think: true
            )

            var responses: [Client.ChatResponse] = []
            var foundThinking = false

            for try await res in stream {
                responses.append(res)
                if res.message.thinking != nil && !res.message.thinking!.isEmpty {
                    foundThinking = true
                }
            }

            #expect(!responses.isEmpty)
            #expect(foundThinking, "Expected to find thinking content in chat stream")
        } catch {
            // Model might not be available, skip this test
            print("Skipping chat thinking stream test: \(error)")
        }
    }

    @Test
    func testChatWithoutThinking() async throws {
        let messages: [Chat.Message] = [
            .system("You are a helpful assistant."),
            .user("What is the capital of France?"),
        ]

        // Test with thinking explicitly disabled
        let response = try await ollama.chat(
            model: "llama3.2",
            messages: messages,
            think: false
        )

        #expect(!response.message.content.isEmpty)
        #expect(response.message.role == .assistant)
        // Should not have thinking content when disabled
        #expect(response.message.thinking == nil)
    }

    @Test
    func testChatWithToolsMultipleTurns() async throws {
        enum ColorError: Error {
            case unknownColor(String)
        }

        // Create a color name mapping tool
        let colorNameTool = Tool<String, HexColorInput>(
            name: "lookup_color",
            description: "Gets the RGB values (0-1) for common HTML color names",
            parameters: [
                "colorName": [
                    "type": "string",
                    "description": "Name of the HTML color",
                ]
            ],
            required: ["colorName"]
        ) { colorName in
            let colors: [String: HexColorInput] = [
                "papayawhip": .init(red: 1.0, green: 0.937, blue: 0.835),
                "cornflowerblue": .init(red: 0.392, green: 0.584, blue: 0.929),
                "mediumseagreen": .init(red: 0.235, green: 0.702, blue: 0.443),
            ]

            guard let color = colors[colorName.lowercased()] else {
                throw ColorError.unknownColor(colorName)
            }
            return color
        }

        // First request - get RGB values
        var messages: [Chat.Message] = [
            .system(
                """
                You are a helpful AI assistant that can help with color conversions.
                First, use the lookup_color tool to get RGB values for color names.
                """),
            .user("What is the RGB for papayawhip?"),
        ]

        var response: Client.ChatResponse

        // First turn
        do {
            response = try await ollama.chat(
                model: "llama3.2",
                messages: messages,
                tools: [colorNameTool]
            )

            // Verify color tool call
            #expect(response.message.toolCalls?.count == 1)
            guard let colorCall = response.message.toolCalls?.first else {
                Issue.record("Missing color tool call")
                return
            }
            #expect(colorCall.function.name == "lookup_color")

            guard let colorName = colorCall.function.arguments["colorName"]?.stringValue else {
                Issue.record("Missing color name")
                return
            }
            #expect(colorName == "papayawhip")

            let color = try await colorNameTool(colorName)
            guard let colorJSON = String(data: try JSONEncoder().encode(color), encoding: .utf8)
            else {
                Issue.record("Failed to encode color")
                return
            }
            messages.append(.tool(colorJSON))
        }

        // Second turn
        do {
            messages.append(.user("Now convert those RGB values to hex."))

            // Second request - convert to hex
            response = try await ollama.chat(
                model: "llama3.2",
                messages: messages,
                tools: [hexColorTool]
            )

            // Verify hex tool call
            #expect(response.message.toolCalls?.count == 1)
            guard let hexCall = response.message.toolCalls?.first else {
                Issue.record("Missing hex tool call")
                return
            }
            #expect(hexCall.function.name == "rgb_to_hex")

            // Verify RGB values
            guard let red = Double(hexCall.function.arguments["red"]!, strict: false),
                let green = Double(hexCall.function.arguments["green"]!),
                let blue = Double(hexCall.function.arguments["blue"]!)
            else {
                Issue.record("Failed to parse RGB values")
                return
            }

            // Allow for some floating point variance
            #expect(abs(red - 1.0) < 0.1)
            #expect(abs(green - 0.937) < 0.1)
            #expect(abs(blue - 0.835) < 0.1)
        }
    }
}
