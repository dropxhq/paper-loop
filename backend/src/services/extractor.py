import re
import nltk
import spacy

nltk.download("punkt_tab", quiet=True)

_nlp = spacy.load("en_core_web_sm")

# Characters that indicate LaTeX / formula fragments
_LATEX_CHARS = set("\\ { } _ ^ $".split())
# Matches strings with non-ASCII characters (unicode math, Greek letters, etc.)
_NON_ASCII_RE = re.compile(r"[^\x00-\x7F]")
# Matches strings that start with a digit
_STARTS_WITH_DIGIT_RE = re.compile(r"^\d")

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


def _is_valid_term(term: str) -> bool:
    """Return True if term passes all noise filters."""
    # Rule 1: no non-ASCII characters (unicode math symbols, Greek letters, etc.)
    if _NON_ASCII_RE.search(term):
        return False
    # Rule 2: starts with a digit (numbers, percentages, etc.)
    if _STARTS_WITH_DIGIT_RE.match(term):
        return False
    # Rule 3: contains LaTeX command characters
    if any(ch in _LATEX_CHARS for ch in term):
        return False
    # Rule 4: too short
    if len(term) < 4:
        return False
    words = term.split()
    # Rule 5: multi-word phrase — any individual word fails rules 1-4
    if len(words) > 1:
        for w in words:
            if _NON_ASCII_RE.search(w) or _STARTS_WITH_DIGIT_RE.match(w) or any(ch in _LATEX_CHARS for ch in w) or len(w) < 1:
                return False
    # Rule 6: phrase too long (> 5 words)
    if len(words) > 5:
        return False
    return True


def extract_candidates(paragraphs: list[dict]) -> list[dict]:
    candidates = []

    for para in paragraphs:
        text = para["text"]
        doc = _nlp(text)

        # NER: named entity phrases
        for ent in doc.ents:
            term = ent.text.strip()
            if term.lower() not in _STOP_SINGLE and _is_valid_term(term):
                candidates.append(_make_candidate(term, "phrase", para))

        # AWL single-word matches — store lemma for cross-paper aggregation
        for token in doc:
            word = token.lemma_.lower()
            if word in _AWL and word not in _STOP_SINGLE and _is_valid_term(word):
                candidates.append(_make_candidate(word, "word", para))

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
