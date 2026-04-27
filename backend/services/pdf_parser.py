import io
import httpx
import fitz  # PyMuPDF


async def download_pdf(paper_id: str) -> bytes:
    url = f"https://arxiv.org/pdf/{paper_id}"
    async with httpx.AsyncClient(timeout=30, follow_redirects=True) as client:
        resp = await client.get(url)
        resp.raise_for_status()
        return resp.content


def parse_pdf_paragraphs(pdf_bytes: bytes) -> list[dict]:
    doc = fitz.open(stream=io.BytesIO(pdf_bytes), filetype="pdf")

    has_text = any(
        page.get_text("text").strip()
        for page in doc
    )
    if not has_text:
        raise ValueError("该论文为扫描版，暂不支持")

    paragraphs = []
    for page_num, page in enumerate(doc):
        blocks = page.get_text("dict")["blocks"]
        # sort blocks: top-to-bottom, left-to-right (handles two-column layout)
        blocks.sort(key=lambda b: (round(b["bbox"][0] / 300), b["bbox"][1]))

        for block in blocks:
            if block.get("type") != 0:
                continue
            lines = block.get("lines", [])
            text = " ".join(
                span["text"]
                for line in lines
                for span in line.get("spans", [])
            ).strip()
            if len(text) < 30:
                continue
            bbox = list(block["bbox"])
            paragraphs.append({
                "text": text,
                "page": page_num,
                "bbox": bbox,
            })

    return paragraphs
