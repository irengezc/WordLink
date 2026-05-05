#!/usr/bin/env python3
"""
Remove broken chains from reservoir.json.
A chain is broken if ANY consecutive pair concatenates into a single
dictionary word (compound) or is a known morphological split.
"""

import json
from pathlib import Path

RESERVOIR_PATH = Path(__file__).parent.parent / "WordLink" / "reservoir.json"

# System dictionary for compound detection
DICT_WORDS = {
    w.strip().lower()
    for w in Path("/usr/share/dict/words").read_text().splitlines()
    if w.strip().isalpha()
}

# Pairs that the dictionary misses but are clearly broken
EXTRA_BAD = {
    ("shop", "ping"),    # shopping
    ("less", "on"),      # lesson
    ("pack", "age"),     # package
    ("move", "ment"),    # movement
    ("ment", "wide"),    # not a word
    ("shift", "er"),     # shifter
    ("er", "board"),     # not a phrase
    ("maker", "shift"),  # makeshift
    ("eyed", "witness"), # eyewitness
    ("beat", "nick"),    # beatnik
    ("changer", "over"), # changeover
    ("keeper", "sake"),  # keepsake
    ("clad", "secret"),  # not a phrase
    ("foxed", "hole"),   # foxhole (wrong form)
    ("holder", "on"),    # not a phrase
    ("shocked", "awe"),  # not a phrase
    ("backer", "board"), # not a word
    ("minded", "set"),   # mindset (backwards)
    ("lining", "up"),    # gerund fragment
    ("plan", "net"),     # not a phrase
    ("luck", "key"),     # not a phrase
}

def is_compound(w1: str, w2: str) -> bool:
    return (w1.lower() + w2.lower()) in DICT_WORDS

def chain_is_clean(chain: list[str]) -> tuple[bool, str]:
    for i in range(len(chain) - 1):
        w1, w2 = chain[i].lower(), chain[i + 1].lower()
        if (w1, w2) in EXTRA_BAD:
            return False, f"{w1.upper()}+{w2.upper()} (known bad pair)"
        if is_compound(w1, w2):
            return False, f"{w1.upper()}+{w2.upper()} → '{w1+w2}' (compound word)"
    return True, ""

def main():
    reservoir = json.loads(RESERVOIR_PATH.read_text())

    for difficulty, chains in reservoir.items():
        before = len(chains)
        kept, removed = [], []

        for entry in chains:
            clean, reason = chain_is_clean(entry["chain"])
            if clean:
                kept.append(entry)
            else:
                removed.append((entry["chain"], reason))

        reservoir[difficulty] = kept
        print(f"[{difficulty}] {before} → {len(kept)} chains  (removed {len(removed)})")
        for chain, reason in removed:
            print(f"  ✗ {' → '.join(chain)}")
            print(f"    reason: {reason}")

    RESERVOIR_PATH.write_text(json.dumps(reservoir, indent=2))
    total = sum(len(v) for v in reservoir.values())
    print(f"\nDone. reservoir.json now has {total} chains total.")

if __name__ == "__main__":
    main()
