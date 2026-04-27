import json
import os
import anthropic
from prompts.extract import SYSTEM_PROMPT, USER_TEMPLATE

_client = anthropic.Anthropic(api_key=os.environ.get("ANTHROPIC_API_KEY", ""))

BATCH_SIZE = 50


async def llm_filter_candidates(candidates: list[dict]) -> list[dict]:
    results = []
    for i in range(0, len(candidates), BATCH_SIZE):
        batch = candidates[i : i + BATCH_SIZE]
        batch_input = [
            {"term": c["term"], "type": c["type"], "context": c["source_sentence"][:200]}
            for c in batch
        ]
        filtered = await _call_haiku(batch_input)
        # merge back with original candidate data
        filtered_map = {item["term"].lower(): item for item in filtered}
        for c in batch:
            key = c["term"].lower()
            llm_result = filtered_map.get(key)
            if llm_result and llm_result.get("keep"):
                results.append({**c, **llm_result})
    return results


async def _call_haiku(batch: list[dict]) -> list[dict]:
    user_msg = USER_TEMPLATE.format(candidates_json=json.dumps(batch, ensure_ascii=False, indent=2))
    response = _client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=4096,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_msg}],
    )
    text = response.content[0].text.strip()
    # strip markdown code fences if present
    if text.startswith("```"):
        text = text.split("\n", 1)[1].rsplit("```", 1)[0]
    return json.loads(text)
