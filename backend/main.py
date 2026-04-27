import asyncio
import uuid
from typing import Any

from fastapi import BackgroundTasks, FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from services.arxiv import extract_paper_id, fetch_html, parse_html_paragraphs
from services.pdf_parser import download_pdf, parse_pdf_paragraphs
from services.card_pipeline import build_cards

app = FastAPI(title="PaperLoop API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# in-memory job store
_jobs: dict[str, dict[str, Any]] = {}


class ImportRequest(BaseModel):
    url: str


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/import")
async def start_import(req: ImportRequest, background_tasks: BackgroundTasks):
    try:
        paper_id = extract_paper_id(req.url)
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))

    job_id = str(uuid.uuid4())
    _jobs[job_id] = {"status": "processing", "paperId": paper_id}
    background_tasks.add_task(_run_import, job_id, paper_id)
    return {"jobId": job_id, "status": "processing"}


@app.get("/import/{job_id}")
async def get_import_status(job_id: str):
    job = _jobs.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")
    return job


async def _run_import(job_id: str, paper_id: str):
    try:
        _jobs[job_id]["status"] = "parsing"

        soup = await fetch_html(paper_id)
        if soup:
            paragraphs = parse_html_paragraphs(soup)
            source = "html"
            html_url = f"https://arxiv.org/html/{paper_id}"
        else:
            _jobs[job_id]["status"] = "parsing_pdf"
            pdf_bytes = await download_pdf(paper_id)
            paragraphs = parse_pdf_paragraphs(pdf_bytes)
            source = "pdf"
            html_url = None

        _jobs[job_id]["status"] = "generating_cards"
        paper_meta, cards = await build_cards(paper_id, paragraphs, source, html_url)

        _jobs[job_id].update({
            "status": "done",
            "paper": paper_meta,
            "cards": cards,
        })
    except Exception as e:
        _jobs[job_id].update({"status": "error", "error": str(e)})
