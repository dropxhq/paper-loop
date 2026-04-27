import httpx
from collections import defaultdict
from services.extractor import extract_candidates
from services.llm_filter import llm_filter_candidates


async def _fetch_paper_meta(paper_id: str) -> dict:
    """Fetch title and abstract from arXiv API."""
    url = f"https://export.arxiv.org/abs/{paper_id}"
    async with httpx.AsyncClient(timeout=10, follow_redirects=True) as client:
        try:
            resp = await client.get(url)
            from bs4 import BeautifulSoup
            soup = BeautifulSoup(resp.text, "html.parser")
            title_tag = soup.find("h1", class_="title")
            abstract_tag = soup.find("blockquote", class_="abstract")
            title = title_tag.get_text(strip=True).removeprefix("Title:").strip() if title_tag else paper_id
            abstract = abstract_tag.get_text(strip=True).removeprefix("Abstract:").strip() if abstract_tag else ""
        except Exception:
            title = paper_id
            abstract = ""
    return {
        "arxivId": paper_id,
        "title": title,
        "abstract": abstract,
        "htmlURL": f"https://arxiv.org/html/{paper_id}",
        "pdfURL": f"https://arxiv.org/pdf/{paper_id}",
    }


def _build_context(paragraphs: list[dict], source_para: dict) -> tuple[str, str]:
    try:
        idx = paragraphs.index(source_para)
    except ValueError:
        return ("", "")
    before = paragraphs[idx - 1]["text"] if idx > 0 else ""
    after = paragraphs[idx + 1]["text"] if idx < len(paragraphs) - 1 else ""
    return (before, after)


def _merge_duplicates(cards: list[dict]) -> list[dict]:
    groups: dict[str, dict] = {}
    for card in cards:
        key = card["term"].lower()
        if key in groups:
            groups[key]["occurrenceCount"] = groups[key].get("occurrenceCount", 1) + 1
        else:
            groups[key] = {**card, "occurrenceCount": 1}
    return list(groups.values())


def _make_anchor(candidate: dict, source: str) -> dict | None:
    if source == "html" and candidate.get("element_id"):
        return {
            "type": "html",
            "elementId": candidate["element_id"],
        }
    elif source == "pdf" and candidate.get("page") is not None:
        return {
            "type": "pdf",
            "page": candidate["page"],
            "bbox": candidate.get("bbox", []),
        }
    return None


async def build_cards(
    paper_id: str,
    paragraphs: list[dict],
    source: str,
    html_url: str | None,
) -> tuple[dict, list[dict]]:
    paper_meta = await _fetch_paper_meta(paper_id)
    if html_url:
        paper_meta["htmlURL"] = html_url

    candidates = extract_candidates(paragraphs)
    filtered = await llm_filter_candidates(candidates)

    # build para lookup for context
    para_by_text = {p["text"]: p for p in paragraphs}

    raw_cards = []
    for item in filtered:
        para = para_by_text.get(item["source_sentence"])
        context_before, context_after = _build_context(paragraphs, para) if para else ("", "")
        anchor = _make_anchor(item, source)

        raw_cards.append({
            "term": item["term"],
            "type": item["type"],
            "sourceSentence": item["source_sentence"],
            "contextBefore": context_before,
            "contextAfter": context_after,
            "zhHint": item.get("zh_hint", ""),
            "valueScore": item.get("value", 3),
            "anchor": anchor,
        })

    merged = _merge_duplicates(raw_cards)
    return paper_meta, merged
