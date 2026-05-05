#!/usr/bin/env python3
"""
Fill in explanations for generated chains using GPT-4o-mini,
then merge into reservoir.json.

Usage:
    python3 add_explanations.py
"""

import json
import time
from pathlib import Path

import requests

# ── Config ────────────────────────────────────────────────────────────────────

GENERATED_PATH = Path(__file__).parent / "generated_chains.json"
RESERVOIR_PATH = Path(__file__).parent.parent / "WordLink" / "reservoir.json"

API_URL   = "https://api.openai.com/v1/chat/completions"
MODEL     = "gpt-4o-mini"
API_KEY   = open(Path(__file__).parent.parent / "WordLink/Services/GeminiService.swift").read()

# Extract the key from the Swift file rather than hardcoding it here
import re
_match = re.search(r'apiKey:\s*String\s*=\s*"(sk-[^"]+)"', API_KEY)
if not _match:
    raise RuntimeError("Could not find API key in GeminiService.swift")
API_KEY = _match.group(1)

# ── GPT call ──────────────────────────────────────────────────────────────────

def get_explanations(pairs: list[tuple[str, str]]) -> list[str]:
    """
    Send up to 8 word pairs to GPT-4o-mini and get back one-sentence definitions.
    Returns a list of strings like "WORD1 WORD2: definition."
    """
    pair_list = "\n".join(f"- {w1} {w2}" for w1, w2 in pairs)
    prompt = f"""For each two-word phrase below, write one concise sentence explaining what it means.
Format each answer exactly as: WORD1 WORD2: One sentence definition.

Phrases:
{pair_list}

Return ONLY a JSON object with key "explanations" containing a list of strings, one per phrase, in the same order."""

    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json",
    }
    body = {
        "model": MODEL,
        "response_format": {"type": "json_object"},
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.3,
    }

    r = requests.post(API_URL, headers=headers, json=body, timeout=30)
    r.raise_for_status()
    content = r.json()["choices"][0]["message"]["content"]
    data = json.loads(content)
    return data["explanations"]


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    generated = json.loads(GENERATED_PATH.read_text())
    reservoir = json.loads(RESERVOIR_PATH.read_text())

    total_chains = sum(len(v) for v in generated.values())
    print(f"Processing {total_chains} chains across {len(generated)} difficulties…\n")

    for difficulty, chains in generated.items():
        print(f"[{difficulty}] {len(chains)} chains")
        for i, entry in enumerate(chains):
            chain = entry["chain"]
            pairs = [(chain[j], chain[j + 1]) for j in range(len(chain) - 1)]

            # Skip if already filled in
            if not entry["explanations"][0].endswith("(add explanation)"):
                print(f"  {i+1:2}. already done, skipping")
                continue

            try:
                explanations = get_explanations(pairs)
                entry["explanations"] = explanations
                print(f"  {i+1:2}. {' → '.join(chain)}")
                time.sleep(0.3)   # stay under rate limit
            except Exception as e:
                print(f"  {i+1:2}. ERROR: {e}")
                # Leave placeholder so we can retry

        # Merge into reservoir (append, no duplicates by chain signature)
        existing_sigs = {"|".join(c["chain"]) for c in reservoir.get(difficulty, [])}
        added = 0
        for entry in chains:
            sig = "|".join(entry["chain"])
            if sig not in existing_sigs and not entry["explanations"][0].endswith("(add explanation)"):
                reservoir.setdefault(difficulty, []).append(entry)
                existing_sigs.add(sig)
                added += 1
        print(f"  → added {added} new chains to reservoir ({difficulty} now has {len(reservoir[difficulty])})\n")

    # Save both files
    GENERATED_PATH.write_text(json.dumps(generated, indent=2))
    RESERVOIR_PATH.write_text(json.dumps(reservoir, indent=2))
    print(f"reservoir.json updated: {RESERVOIR_PATH}")


if __name__ == "__main__":
    main()
