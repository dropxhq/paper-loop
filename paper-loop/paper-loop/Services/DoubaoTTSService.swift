import Foundation
import AVFoundation

/// DashScope 文本转语音服务
/// API 文档: https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation
actor DashScopeTTSService {
    static let shared = DashScopeTTSService()

    private let endpoint = URL(string: "https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation")!
    private let model = "qwen3-tts-flash"
    private var player: AVAudioPlayer?

    // MARK: - Public API

    /// 合成并播放文本
    /// - Parameters:
    ///   - text: 要朗读的文本
    ///   - apiKey: DashScope API Key
    ///   - speaker: 音色 ID
    func speak(
        text: String,
        apiKey: String,
        speaker: String = DashScopeVoiceType.defaultSpeaker
    ) async throws {
        let audioData = try await synthesize(text: text, apiKey: apiKey, speaker: speaker)
        await MainActor.run {
            playAudio(data: audioData)
        }
    }

    // MARK: - Private

    private func synthesize(text: String, apiKey: String, speaker: String) async throws -> Data {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw TTSError.apiError("缺少 DASHSCOPE_API_KEY")
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")

        let body = DashScopeTTSRequest(
            model: model,
            input: DashScopeTTSInput(
                text: text,
                speaker: speaker,
                languageType: languageType(for: text)
            )
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TTSError.httpError(0)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw TTSError.apiError(msg)
        }

        let decoded = try JSONDecoder().decode(DashScopeTTSResponse.self, from: data)

        if let base64Data = decoded.output?.audio.data,
           !base64Data.isEmpty,
           let audioData = Data(base64Encoded: base64Data, options: .ignoreUnknownCharacters) {
            return audioData
        }

        if let rawURL = decoded.output?.audio.url,
           var audioURL = URL(string: rawURL) {
            if audioURL.scheme == "http",
               var components = URLComponents(url: audioURL, resolvingAgainstBaseURL: false) {
                components.scheme = "https"
                audioURL = components.url ?? audioURL
            }
            let (audioData, audioResp) = try await URLSession.shared.data(from: audioURL)
            guard let audioHTTPResp = audioResp as? HTTPURLResponse,
                  (200..<300).contains(audioHTTPResp.statusCode),
                  !audioData.isEmpty else {
                throw TTSError.invalidAudioData
            }
            return audioData
        }

        if let responseText = String(data: data, encoding: .utf8), !responseText.isEmpty {
            throw TTSError.apiError(responseText)
        }

        throw TTSError.invalidAudioData
    }

    private func languageType(for text: String) -> String {
        if text.unicodeScalars.contains(where: { $0.value >= 0x4E00 && $0.value <= 0x9FFF }) {
            return "Chinese"
        }
        return "English"
    }

    @MainActor
    private func playAudio(data: Data) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(data: data)
            Task { await storePlayer(p) }
            p.play()
        } catch {
            // 播放失败时静默处理
        }
    }

    private func storePlayer(_ p: AVAudioPlayer) {
        player = p
    }
}

// MARK: - DashScope Request / Response Models

private struct DashScopeTTSRequest: Encodable {
    let model: String
    let input: DashScopeTTSInput
}

private struct DashScopeTTSInput: Encodable {
    let text: String
    let speaker: String
    let languageType: String

    enum CodingKeys: String, CodingKey {
        case text
        case speaker = "voice"
        case languageType = "language_type"
    }
}

private struct DashScopeTTSResponse: Decodable {
    let output: DashScopeOutput?
}

private struct DashScopeOutput: Decodable {
    let audio: DashScopeAudio
}

private struct DashScopeAudio: Decodable {
    let data: String?
    let url: String?
}

// MARK: - Voice Types

enum DashScopeVoiceType {
    static let defaultSpeaker = "Maia"

    /// DashScope qwen3-tts-flash / qwen3-tts-instruct-flash 常用系统音色
    static let speakers: [(id: String, label: String)] = [
        // 中文/多语种通用
        ("Cherry", "Cherry（芊悦·阳光女声）"),
        ("Serena", "Serena（苏瑶·温柔女声）"),
        ("Ethan", "Ethan（晨煦·活力男声）"),
        ("Chelsie", "Chelsie（千雪·二次元女声）"),
        ("Momo", "Momo（茉兔·撒娇搞怪）"),
        ("Vivian", "Vivian（十三·俏皮女声）"),
        ("Moon", "Moon（月白·率性男声）"),
        ("Maia", "Maia（四月·知性温柔）"),
        ("Kai", "Kai（凯·磁性男声）"),
        ("Nofish", "Nofish（不吃鱼·特色男声）"),
        ("Bella", "Bella（萌宝·萝莉女声）"),
        ("Jennifer", "Jennifer（詹妮弗·电影感女声）"),
        ("Ryan", "Ryan（甜茶·戏感男声）"),
        ("Katerina", "Katerina（卡捷琳娜·御姐女声）"),
        ("Aiden", "Aiden（艾登·清朗男声）"),
        ("Mia", "Mia（乖小妹·温顺女声）"),
        ("Mochi", "Mochi（沙小弥·童声男）"),
        ("Bunny", "Bunny（萌小姬·萌系女声）"),
        ("Neil", "Neil（阿闻·播音男声）"),

        // 角色/叙事风格
        ("Eldric Sage", "Eldric Sage（沧明子·老者男声）"),
        ("Bellona", "Bellona（燕铮莺·戏剧女声）"),
        ("Vincent", "Vincent（田叔·烟嗓男声）"),
        ("Arthur", "Arthur（徐大爷·故事男声）"),
        ("Nini", "Nini（邻家妹妹·甜美女声）"),
        ("Seren", "Seren（小婉·助眠女声）"),
        ("Pip", "Pip（顽屁小孩·童声男）"),
        ("Stella", "Stella（少女阿月·元气女声）"),

        // 海外风格
        ("Bodega", "Bodega（西语大叔）"),
        ("Sonrisa", "Sonrisa（拉美女声）"),
        ("Alek", "Alek（俄语男声）"),
        ("Dolce", "Dolce（意语男声）"),
        ("Sohee", "Sohee（韩语女声）"),
        ("Ono Anna", "Ono Anna（日语女声）"),
        ("Lenn", "Lenn（德语男声）"),
        ("Emilien", "Emilien（法语男声）"),
        ("Andre", "Andre（沉稳男声）"),
        ("Radio Gol", "Radio Gol（葡语解说男声）"),

        // 中文方言
        ("Jada", "Jada（上海话·阿珍）"),
        ("Dylan", "Dylan（北京话·晓东）"),
        ("Li", "Li（南京话·老李）"),
        ("Marcus", "Marcus（陕西话·秦川）"),
        ("Roy", "Roy（闽南语·阿杰）"),
        ("Peter", "Peter（天津话·李彼得）"),
        ("Sunny", "Sunny（四川话·晴儿）"),
        ("Eric", "Eric（四川话·程川）"),
        ("Rocky", "Rocky（粤语·阿强）"),
        ("Kiki", "Kiki（粤语·阿清）")
    ]
}

// MARK: - Errors

enum TTSError: LocalizedError {
    case httpError(Int)
    case apiError(String)
    case invalidAudioData

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "网络错误 (HTTP \(code))"
        case .apiError(let msg): return msg
        case .invalidAudioData: return "音频数据异常"
        }
    }
}
