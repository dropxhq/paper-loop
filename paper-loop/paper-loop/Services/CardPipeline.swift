import Foundation

struct CardData {
    let term: String
    let type: String
    let sourceSentence: String
    let zhHint: String
    let valueScore: Int
    let anchor: String
    let section: String
}

private struct LLMCardItem: Decodable {
    let term: String
    let type: String
    let keep: Bool
    let value: Int
    let zh_hint: String
}

actor CardPipeline {
    static let shared = CardPipeline()

    private let batchSize = 30

    // System prompt translated from backend/src/prompts/extract.py
    private let systemPrompt = """
    你是一个学术英语词汇教学专家。你的任务是从用户提供的候选词/短语/句子列表中，筛选出对英语学习者有价值的条目，并为每个条目生成结构化的卡片数据。

    输出格式要求：
    返回一个 JSON 数组，每个元素包含以下字段：
    - term: 原候选词（保持原样）
    - type: "word"（单词）| "phrase"（术语短语）| "sentence"（例句）
    - keep: true/false（是否保留此卡片，价值分 ≤ 2 设为 false）
    - value: 1-5 整数（对英语学习者的价值，5=最高）
    - zh_hint: 中文简短释义或翻译（≤20 字）

    筛选标准：
    - 保留：有学术价值的词汇、领域术语、典型句型
    - 过滤：过于常见的词（the、this、with）、纯数字、代词、缩略词（除非是重要技术术语）
    - 重点关注：NLP/ML 领域术语、学术写作高频词、不常见但重要的词汇

    只输出 JSON 数组，不要有任何额外文字。
    """

    func generateCards(paragraphs: [Paragraph], paperContext: String) async throws -> [CardData] {
        let batches = stride(from: 0, to: paragraphs.count, by: batchSize).map {
            Array(paragraphs[$0..<min($0 + batchSize, paragraphs.count)])
        }

        return try await withThrowingTaskGroup(of: [CardData].self) { group in
            for batch in batches {
                group.addTask {
                    await self.processBatch(batch, paperContext: paperContext)
                }
            }

            var all: [CardData] = []
            for try await batchResult in group {
                all.append(contentsOf: batchResult)
            }
            return all
        }
    }

    private func processBatch(_ paragraphs: [Paragraph], paperContext: String) async -> [CardData] {
        let candidatesJSON = buildCandidatesJSON(from: paragraphs)
        let userPrompt = """
        论文背景：\(paperContext)

        请处理以下候选列表，每个候选项包含 term、type 和原文句子上下文：

        \(candidatesJSON)

        返回 JSON 数组。
        """

        do {
            let response = try await LLMService.shared.chatCompletion(system: systemPrompt, user: userPrompt)
            return parseResponse(response, paragraphs: paragraphs)
        } catch {
            return []
        }
    }

    private func buildCandidatesJSON(from paragraphs: [Paragraph]) -> String {
        // Treat each paragraph as a candidate sentence
        let candidates = paragraphs.map { p -> [String: String] in
            ["term": p.text.prefix(120).description,
             "type": "sentence",
             "context": p.text]
        }
        guard let data = try? JSONEncoder().encode(candidates),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }

    private func parseResponse(_ response: String, paragraphs: [Paragraph]) -> [CardData] {
        // Strip markdown code fence if present
        var json = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if json.hasPrefix("```") {
            let lines = json.components(separatedBy: "\n")
            json = lines.dropFirst().dropLast().joined(separator: "\n")
        }

        guard let data = json.data(using: .utf8),
              let items = try? JSONDecoder().decode([LLMCardItem].self, from: data) else {
            return []
        }

        return items.compactMap { item -> CardData? in
            guard item.keep, item.value > 2 else { return nil }

            // Match back to source paragraph for anchor/section
            let source = paragraphs.first { p in
                p.text.contains(item.term)
            }

            return CardData(
                term: item.term,
                type: item.type,
                sourceSentence: source?.text ?? "",
                zhHint: item.zh_hint,
                valueScore: item.value,
                anchor: source?.anchor ?? "",
                section: source?.section ?? ""
            )
        }
    }
}
