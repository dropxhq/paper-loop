import Foundation

struct CardData {
    let lemma: String
    let termInContext: String
    let type: String
    let sourceSentence: String
    let zhHint: String
    let valueScore: Int
    let paragraphAnchor: String   // raw anchor string, e.g. "element:s1p2" or "page:3"
    let charOffset: Int?          // UTF-16 offset of termInContext within paragraph text
}

private struct LLMCardItem: Decodable {
    let lemma: String
    let term_in_context: String
    let source_sentence: String
    let paragraph_idx: Int
    let type: String
    let keep: Bool
    let value: Int
    let zh_hint: String
}

private struct ParagraphInput: Encodable {
    let idx: Int
    let text: String
}

actor CardPipeline {
    static let shared = CardPipeline()

    private let batchSize = 30

    private let systemPrompt = """
    你是一个学术英语词汇教学专家。你的任务是从用户提供的段落列表中，提取对英语学习者有价值的词汇和术语短语，并为每个词/短语生成结构化的卡片数据。

    输入格式：JSON 数组，每个元素含 idx（段落编号）和 text（段落全文）。

    输出格式：返回一个 JSON 数组，每个元素包含：
    - lemma: 词的原型/基本形式（如 "capability"、"masked language modeling"）
    - term_in_context: 该词在原文中出现的确切形式（原文照抄，不得改写）
    - source_sentence: 包含该词的完整句子（原文照抄）
    - paragraph_idx: 该词来源段落的 idx 编号（对应输入中的 idx 字段）
    - type: "word"（单词）| "phrase"（术语短语）
    - keep: true/false（是否保留此卡片，价值分 ≤ 2 设为 false）
    - value: 1-5 整数（对英语学习者的价值，5=最高）
    - zh_hint: 中文简短释义（≤20 字）

    重要规则：
    - term_in_context 必须是原文中出现的确切文字，严禁改写或添加任何内容
    - 每个段落可以产出零到多个词/短语
    - 不生成 type: "sentence" 的卡片
    - 过滤过于常见的词（the、this、with 等）、纯数字、代词
    - 重点关注：NLP/ML 领域术语、学术写作高频词、不常见但重要的词汇

    只输出 JSON 数组，不要有任何额外文字。
    """

    func generateCards(paragraphs: [Paragraph], paperContext: String) async throws -> [CardData] {
        let batchOffsets = stride(from: 0, to: paragraphs.count, by: batchSize).map { $0 }

        return try await withThrowingTaskGroup(of: [CardData].self) { group in
            for batchOffset in batchOffsets {
                let batchEnd = min(batchOffset + batchSize, paragraphs.count)
                let batch = Array(paragraphs[batchOffset..<batchEnd])
                group.addTask {
                    await self.processBatch(batch, batchOffset: batchOffset, allParagraphs: paragraphs, paperContext: paperContext)
                }
            }

            var all: [CardData] = []
            for try await batchResult in group {
                all.append(contentsOf: batchResult)
            }
            return all
        }
    }

    private func processBatch(_ batch: [Paragraph], batchOffset: Int, allParagraphs: [Paragraph], paperContext: String) async -> [CardData] {
        let candidatesJSON = buildCandidatesJSON(from: batch, batchOffset: batchOffset)
        let userPrompt = """
        论文背景：\(paperContext)

        请从以下段落中提取有价值的词汇和术语短语：

        \(candidatesJSON)

        返回 JSON 数组。
        """

        do {
            let response = try await LLMService.shared.chatCompletion(system: systemPrompt, user: userPrompt)
            return parseResponse(response, allParagraphs: allParagraphs, batchOffset: batchOffset)
        } catch {
            return []
        }
    }

    private func buildCandidatesJSON(from batch: [Paragraph], batchOffset: Int) -> String {
        let inputs = batch.enumerated().map { (localIdx, p) in
            ParagraphInput(idx: batchOffset + localIdx, text: p.text)
        }
        guard let data = try? JSONEncoder().encode(inputs),
              let json = String(data: data, encoding: .utf8) else { return "[]" }
        return json
    }

    private func parseResponse(_ response: String, allParagraphs: [Paragraph], batchOffset: Int) -> [CardData] {
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

            let globalIdx = item.paragraph_idx
            guard globalIdx >= 0, globalIdx < allParagraphs.count else { return nil }
            let para = allParagraphs[globalIdx]

            // Locate termInContext in paragraph text with progressively looser matching
            let (resolvedTerm, charOffset) = locateTerm(item.term_in_context, in: para.text)
            // If we can't find any reasonable match, still keep the card but without an anchor offset
            let finalTerm = resolvedTerm ?? item.term_in_context

            return CardData(
                lemma: item.lemma,
                termInContext: finalTerm,
                type: item.type,
                sourceSentence: item.source_sentence,
                zhHint: item.zh_hint,
                valueScore: item.value,
                paragraphAnchor: para.anchor,
                charOffset: charOffset
            )
        }
    }

    /// Try to find `term` in `text` with progressively looser strategies.
    /// Returns (matched substring from text, UTF-16 offset), or (nil, nil) if not found.
    private func locateTerm(_ term: String, in text: String) -> (String?, Int?) {
        let options: String.CompareOptions = [.caseInsensitive]

        // 1. Exact case-insensitive match
        if let range = text.range(of: term, options: options) {
            let matched = String(text[range])
            return (matched, NSRange(range, in: text).location)
        }

        // 2. Trim whitespace / punctuation from both ends of the LLM term
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines
            .union(.punctuationCharacters))
        if trimmed != term, !trimmed.isEmpty,
           let range = text.range(of: trimmed, options: options) {
            let matched = String(text[range])
            return (matched, NSRange(range, in: text).location)
        }

        // 3. Collapse internal whitespace runs (LLM sometimes inserts extra spaces)
        let normalized = trimmed
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if normalized != trimmed, !normalized.isEmpty,
           let range = text.range(of: normalized, options: options) {
            let matched = String(text[range])
            return (matched, NSRange(range, in: text).location)
        }

        return (nil, nil)
    }
}
