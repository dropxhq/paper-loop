import re
from typing import Optional
import httpx
from bs4 import BeautifulSoup


_ARXIV_ID_RE = re.compile(r"arxiv\.org/(?:abs|pdf)/([0-9]{4}\.[0-9]+(?:v\d+)?)")


def extract_paper_id(url: str) -> str:
    m = _ARXIV_ID_RE.search(url)
    if not m:
        raise ValueError("仅支持 arXiv 链接（arxiv.org/abs/... 或 arxiv.org/pdf/...）")
    return m.group(1)


async def fetch_html(paper_id: str) -> Optional[BeautifulSoup]:
    url = f"https://arxiv.org/html/{paper_id}"
    async with httpx.AsyncClient(timeout=20, follow_redirects=True) as client:
        try:
            resp = await client.get(url)
            if resp.status_code != 200:
                return None
            return BeautifulSoup(resp.text, "html.parser")
        except Exception:
            return None


def parse_html_paragraphs(soup: BeautifulSoup) -> list[dict]:
    paragraphs = []
    current_section = ""

    for elem in soup.find_all(["h1", "h2", "h3", "h4", "section", "p"]):
        tag = elem.name
        if tag in ("h1", "h2", "h3", "h4"):
            current_section = elem.get_text(strip=True)
            continue

        if tag == "section":
            header = elem.find(["h1", "h2", "h3", "h4"])
            if header:
                current_section = header.get_text(strip=True)
            continue

        text = elem.get_text(separator=" ", strip=True)
        if len(text) < 30:
            continue

        element_id = elem.get("id") or ""
        paragraphs.append({
            "text": text,
            "element_id": element_id,
            "section_title": current_section,
        })

    return paragraphs
