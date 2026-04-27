import Foundation

struct PaperResponse: Decodable {
    let arxivId: String
    let title: String
    let abstract: String
    let htmlURL: String?
    let pdfURL: String
}

struct AnchorResponse: Decodable {
    let type: String
    let elementId: String?
    let htmlURL: String?
    let page: Int?
    let bbox: [Double]?
}

struct CardResponse: Decodable {
    let term: String
    let type: String
    let sourceSentence: String
    let contextBefore: String
    let contextAfter: String
    let zhHint: String
    let valueScore: Int
    let anchor: AnchorResponse?
    let occurrenceCount: Int
}

struct ImportStatusResponse: Decodable {
    let status: String
    let paper: PaperResponse?
    let cards: [CardResponse]?
    let error: String?
}

struct StartImportResponse: Decodable {
    let jobId: String
    let status: String
}

enum ImportError: Error, LocalizedError {
    case invalidURL
    case serverError(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "仅支持 arXiv 链接"
        case .serverError(let msg): return msg
        case .timeout: return "导入超时，请重试"
        }
    }
}

actor ImportService {
    static let shared = ImportService()

    private let baseURL = "http://localhost:8000"
    private let session = URLSession.shared

    func startImport(url: String) async throws -> String {
        let endpoint = URL(string: "\(baseURL)/import")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["url": url])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let detail = (try? JSONDecoder().decode([String: String].self, from: data))?["detail"] ?? "未知错误"
            throw ImportError.serverError(detail)
        }
        let result = try JSONDecoder().decode(StartImportResponse.self, from: data)
        return result.jobId
    }

    func pollStatus(jobId: String) async throws -> ImportStatusResponse {
        let endpoint = URL(string: "\(baseURL)/import/\(jobId)")!
        let (data, _) = try await session.data(from: endpoint)
        return try JSONDecoder().decode(ImportStatusResponse.self, from: data)
    }

    func waitForCompletion(jobId: String, timeout: TimeInterval = 30) async throws -> ImportStatusResponse {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let status = try await pollStatus(jobId: jobId)
            switch status.status {
            case "done": return status
            case "error": throw ImportError.serverError(status.error ?? "导入失败")
            default:
                try await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
        throw ImportError.timeout
    }
}
