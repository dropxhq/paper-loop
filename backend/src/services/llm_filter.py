import asyncio
import json
import os
from openai import AsyncOpenAI
from ..prompts.extract import SYSTEM_PROMPT, USER_TEMPLATE

_client = AsyncOpenAI(
    api_key=os.environ.get("OPENAI_API_KEY", ""),
    base_url=os.environ.get("OPENAI_BASE_URL", "https://api.tokencow.dev/v1"),
)

MODEL_NAME = "deepseek/deepseek-v4-flash"

BATCH_SIZE = 50


async def llm_filter_candidates(candidates: list[dict]) -> list[dict]:
    batches = [
        candidates[i : i + BATCH_SIZE]
        for i in range(0, len(candidates), BATCH_SIZE)
    ]

    async def process_batch(batch: list[dict]) -> list[dict]:
        batch_input = [
            {"term": c["term"], "type": c["type"], "context": c["source_sentence"][:200]}
            for c in batch
        ]
        filtered = await _call_haiku(batch_input)
        filtered_map = {item["term"].lower(): item for item in filtered}
        results = []
        for c in batch:
            key = c["term"].lower()
            llm_result = filtered_map.get(key)
            if llm_result and llm_result.get("keep"):
                results.append({**c, **llm_result})
        return results

    batch_results = await asyncio.gather(*[process_batch(b) for b in batches])
    return [item for sublist in batch_results for item in sublist]


async def _call_haiku(batch: list[dict]) -> list[dict]:
    user_msg = USER_TEMPLATE.format(candidates_json=json.dumps(batch, ensure_ascii=False, indent=2))
    response = await _client.chat.completions.create(
        model=MODEL_NAME,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_msg},
        ],
    )
    text = (response.choices[0].message.content or "").strip()
    # strip markdown code fences if present
    if text.startswith("```"):
        text = text.split("\n", 1)[1].rsplit("```", 1)[0]
    return json.loads(text)
