import Foundation

enum LLMError: Error, LocalizedError {
    case missingAPIKey
    case httpError(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "请先在「我的」中设置 API Key"
        case .httpError(let code): return "LLM 服务返回错误（HTTP \(code)）"
        case .invalidResponse: return "LLM 返回格式异常"
        }
    }
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct ChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message

        struct Message: Decodable {
            let content: String
        }
    }
}

actor LLMService {
    static let shared = LLMService()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()

    private var baseURL: String {
        UserDefaults.standard.string(forKey: "llm_base_url")
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? "https://dashscope.aliyuncs.com/compatible-mode/v1"
    }

    private var model: String {
        UserDefaults.standard.string(forKey: "llm_model")
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? "deepseek-v4-flash"
    }

    private var apiKey: String? {
        KeychainHelper.read(key: "llm_api_key")
    }

    func chatCompletion(system: String, user: String) async throws -> String {
        guard let key = apiKey, !key.isEmpty else {
            throw LLMError.missingAPIKey
        }

        let url = URL(string: "\(baseURL)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let body = ChatRequest(
            model: model,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: user)
            ]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw LLMError.httpError(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw LLMError.invalidResponse
        }
        return content
    }
}
