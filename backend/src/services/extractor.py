import re
import nltk
import spacy
from rake_nltk import Rake

nltk.download("punkt_tab", quiet=True)
nltk.download("stopwords", quiet=True)

_nlp = spacy.load("en_core_web_sm")
_rake = Rake()

# Academic Word List (abbreviated core set)
_AWL = {
    "analysis", "approach", "area", "assessment", "assume", "authority",
    "available", "benefit", "concept", "consistent", "constitutional",
    "context", "contract", "create", "data", "definition", "derived",
    "distribution", "economic", "environment", "established", "estimate",
    "evidence", "export", "factors", "financial", "formula", "function",
    "identified", "income", "indicate", "individual", "interpretation",
    "involved", "issues", "labor", "legal", "legislation", "major",
    "method", "occur", "percent", "period", "policy", "principle",
    "procedure", "process", "required", "research", "response", "role",
    "section", "sector", "significant", "similar", "source", "specific",
    "structure", "theory", "variables", "contrastive", "representation",
    "mechanism", "architecture", "encoder", "decoder", "attention",
    "embedding", "gradient", "optimization", "regularization", "inference",
    "pre-training", "fine-tuning", "downstream", "benchmark", "baseline",
    "evaluation", "classification", "regression", "generalization",
    "transformer", "activation", "normalization", "propagation",
    "corpus", "token", "tokenization", "vocabulary", "semantic",
    "syntactic", "latent", "distribution", "posterior", "prior",
    "likelihood", "objective", "loss", "accuracy", "precision", "recall",
}

# Skip common low-value tokens
_STOP_SINGLE = {
    "model", "the", "this", "that", "with", "from", "for", "are",
    "was", "our", "we", "it", "its", "their", "which", "also",
    "used", "using", "based", "show", "propose", "paper",
    "result", "results", "system", "approach", "work",
}

_DEFINITION_RE = re.compile(
    r"(?:we\s+)?(?:define|introduce|present|propose)\s+\w", re.IGNORECASE
)
_CONTRIBUTION_RE = re.compile(
    r"(?:our|we)\s+(?:main\s+)?(?:contribution|finding|result|show|demonstrate)",
    re.IGNORECASE,
)


def extract_candidates(paragraphs: list[dict]) -> list[dict]:
    candidates = []

    for para in paragraphs:
        text = para["text"]
        doc = _nlp(text)

        # NER: named entity phrases
        for ent in doc.ents:
            term = ent.text.strip()
            if len(term) >= 3 and term.lower() not in _STOP_SINGLE:
                candidates.append(_make_candidate(term, "phrase", para))

        # AWL single-word matches
        for token in doc:
            word = token.lemma_.lower()
            if word in _AWL and word not in _STOP_SINGLE and len(word) >= 4:
                candidates.append(_make_candidate(token.text, "word", para))

        # RAKE multi-word keyphrases
        _rake.extract_keywords_from_text(text)
        for phrase in _rake.get_ranked_phrases()[:5]:
            if 2 <= len(phrase.split()) <= 5:
                candidates.append(_make_candidate(phrase, "phrase", para))

        # Definition / contribution sentences
        sentences = [s.text.strip() for s in doc.sents]
        for sent in sentences:
            if _DEFINITION_RE.search(sent) or _CONTRIBUTION_RE.search(sent):
                if len(sent) > 40:
                    candidates.append(_make_candidate(sent, "sentence", para))

    return _dedupe_candidates(candidates)


def _make_candidate(term: str, ctype: str, para: dict) -> dict:
    return {
        "term": term,
        "type": ctype,
        "source_sentence": para["text"],
        "element_id": para.get("element_id", ""),
        "page": para.get("page"),
        "bbox": para.get("bbox"),
        "section_title": para.get("section_title", ""),
    }


def _dedupe_candidates(candidates: list[dict]) -> list[dict]:
    seen: set[str] = set()
    result = []
    for c in candidates:
        key = c["term"].lower()
        if key not in seen:
            seen.add(key)
            result.append(c)
    return result
