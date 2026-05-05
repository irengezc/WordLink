#!/usr/bin/env python3
"""
Generate WordLink chains using Datamuse API.

Strategy (two phases):
  Phase 1 — build_graph: query Datamuse for every word in a curated
             "bridge-word" vocabulary; keep only pairs where BOTH words
             are in the vocabulary and the bigram score is high enough.
             Save to phrase_graph.json (run once, then reuse).

  Phase 2 — find_chains: DFS through the graph to find 9-word paths.

Usage:
    # First time — build graph (~200 API calls, ~30 s):
    python3 generate_chains.py --build-graph

    # Generate chains (uses saved graph):
    python3 generate_chains.py [count_per_difficulty]
    python3 generate_chains.py 20
"""

import argparse
import json
import random
import time
from pathlib import Path

import requests

# ── Vocabulary ────────────────────────────────────────────────────────────────
# Curated set of words that appear frequently in compound two-word phrases.
# Limiting candidates to this set prevents sentence-fragment bigrams.

VOCAB = {
    # adjectives that start common phrases
    "black", "blue", "bright", "broad", "broken", "clean", "clear", "close",
    "cold", "cool", "dark", "dead", "deep", "double", "dry", "dull", "fair",
    "fine", "firm", "flat", "free", "fresh", "full", "glass", "gold", "golden",
    "grand", "green", "grey", "hard", "high", "hot", "keen", "light", "live",
    "long", "low", "narrow", "open", "prime", "quick", "raw", "red", "rough",
    "round", "sharp", "short", "silver", "slow", "smooth", "soft", "solid",
    "sharp", "steep", "stiff", "still", "strong", "thick", "thin", "tight",
    "warm", "white", "wide", "wild",

    # short nouns that bridge many phrases
    "air", "arm", "art", "ash", "back", "bag", "ball", "bank", "base", "bay",
    "bed", "bill", "bird", "bite", "blood", "blow", "board", "boat", "body",
    "bone", "book", "bow", "box", "brain", "break", "brick", "bridge", "brush",
    "bus", "camp", "cap", "card", "cash", "chain", "chair", "chest", "child",
    "chip", "class", "clay", "clock", "cloth", "cloud", "club", "coat", "code",
    "coin", "core", "corn", "court", "cover", "craft", "crew", "crop", "cross",
    "crowd", "crown", "cup", "cut", "day", "deck", "desk", "dirt", "door",
    "drain", "draw", "dream", "dress", "drill", "drive", "drop", "drum",
    "dust", "earth", "edge", "eye", "face", "fall", "fan", "farm", "feet",
    "field", "film", "fire", "fish", "flag", "flash", "flight", "floor",
    "flow", "foam", "fog", "fold", "foot", "force", "form", "frame", "fruit",
    "fuel", "fund", "game", "gap", "gate", "gear", "glass", "globe", "glove",
    "grade", "grain", "grass", "ground", "guard", "guide", "gun", "hall",
    "hand", "head", "heat", "heel", "hill", "hold", "hole", "home", "hook",
    "house", "hunt", "ice", "iron", "joint", "judge", "key", "kick", "king",
    "knee", "knife", "knot", "lake", "land", "lane", "lead", "leaf", "line",
    "link", "list", "lock", "loop", "loss", "mail", "man", "map", "mark",
    "match", "meal", "meat", "milk", "mine", "moon", "motor", "mouth", "mud",
    "nail", "neck", "nest", "net", "news", "night", "note", "nurse", "oil",
    "pack", "page", "paint", "palm", "park", "pass", "path", "peak", "pipe",
    "pit", "place", "plane", "plant", "plate", "play", "plot", "plug", "pool",
    "port", "post", "power", "press", "print", "proof", "pull", "pump", "push",
    "race", "rail", "rain", "range", "rank", "rate", "ring", "road", "rock",
    "roof", "room", "root", "rope", "round", "rule", "run", "rush", "sale",
    "sand", "school", "screen", "sea", "seed", "sheet", "shell", "shift",
    "ship", "shop", "shot", "show", "sign", "sink", "skin", "slip", "smoke",
    "snow", "soil", "space", "spell", "spin", "sport", "spot", "spring",
    "stage", "stain", "stand", "star", "stem", "step", "stone", "stop",
    "storm", "street", "strip", "stroke", "sun", "surf", "swing", "table",
    "tail", "team", "tide", "time", "tip", "top", "town", "track", "trade",
    "trail", "train", "trap", "tree", "trim", "trip", "trunk", "tube", "tune",
    "turf", "turn", "type", "wall", "ward", "watch", "water", "wave", "wax",
    "way", "web", "week", "wheel", "wind", "wing", "wire", "wood", "word",
    "work", "world", "yard",
}

GRAPH_PATH = Path(__file__).parent / "phrase_graph.json"

# ── Datamuse ──────────────────────────────────────────────────────────────────

def get_followers(word: str, n: int = 60) -> list[dict]:
    """Words that most commonly FOLLOW `word` in real text (bigram corpus)."""
    url = f"https://api.datamuse.com/words?rel_bga={word}&max={n}"
    try:
        r = requests.get(url, timeout=8)
        r.raise_for_status()
        return r.json()
    except Exception as e:
        print(f"  [API error for '{word}': {e}]")
        return []


def load_dictionary() -> set[str]:
    path = Path("/usr/share/dict/words")
    if path.exists():
        return {w.strip().lower() for w in path.read_text().splitlines() if w.strip().isalpha()}
    return set()

DICT_WORDS = load_dictionary()


def is_compound(w1: str, w2: str) -> bool:
    """True if concatenating w1+w2 forms a single dictionary word."""
    return (w1.lower() + w2.lower()) in DICT_WORDS

# ── Phase 1: Build phrase graph ───────────────────────────────────────────────

def build_graph(min_score: int = 500) -> dict[str, list[tuple[str, int]]]:
    """
    For each word in VOCAB, find its top followers that are also in VOCAB.
    Returns adjacency list: { word → [(next_word, score), ...] }
    """
    graph: dict[str, list[tuple[str, int]]] = {}
    vocab_lower = {w.lower() for w in VOCAB}
    total = len(vocab_lower)

    for i, word in enumerate(sorted(vocab_lower), 1):
        print(f"  [{i:3}/{total}] {word}", end="  ", flush=True)
        followers = get_followers(word)
        time.sleep(0.08)

        edges = []
        for f in followers:
            w = f["word"].lower()
            if (w in vocab_lower
                    and w != word
                    and f["score"] >= min_score
                    and not is_compound(word, w)):
                edges.append((w, f["score"]))

        edges.sort(key=lambda x: -x[1])
        graph[word] = edges
        print(f"→ {len(edges)} edges" if edges else "→ (none)")

    return graph


def save_graph(graph: dict) -> None:
    GRAPH_PATH.write_text(json.dumps(graph, indent=2))
    total_edges = sum(len(v) for v in graph.values())
    print(f"\nGraph saved: {len(graph)} nodes, {total_edges} edges → {GRAPH_PATH}")


def load_graph() -> dict[str, list[tuple[str, int]]]:
    if not GRAPH_PATH.exists():
        raise FileNotFoundError(
            f"Phrase graph not found. Run: python3 {__file__} --build-graph"
        )
    raw = json.loads(GRAPH_PATH.read_text())
    return {k: [tuple(e) for e in v] for k, v in raw.items()}

# ── Phase 2: Find chains ──────────────────────────────────────────────────────

def find_chains(
    graph: dict[str, list[tuple[str, int]]],
    seed: str,
    chain_len: int = 9,
    min_score: int = 0,
) -> list[str] | None:
    """DFS to find a chain of `chain_len` words starting from `seed`."""

    def dfs(path: list[str]) -> list[str] | None:
        if len(path) == chain_len:
            return path
        current = path[-1]
        neighbors = graph.get(current, [])
        # Shuffle so different runs produce different chains
        candidates = [
            (w, s) for w, s in neighbors
            if w not in path and s >= min_score
        ]
        random.shuffle(candidates)
        for w, _ in candidates:
            result = dfs(path + [w])
            if result:
                return result
        return None

    return dfs([seed.lower()])


def generate(
    graph: dict,
    difficulty: str,
    count: int,
    seeds: list[str],
    min_score: int,
) -> list[dict]:
    random.shuffle(seeds)
    results: list[dict] = []
    seen: set[str] = set()
    seed_idx = 0
    attempts = 0

    while len(results) < count:
        attempts += 1
        if attempts > count * 30:
            print(f"  ⚠ only produced {len(results)}/{count} for {difficulty}")
            break

        seed = seeds[seed_idx % len(seeds)]
        seed_idx += 1
        if seed not in graph:
            continue

        chain = find_chains(graph, seed, min_score=min_score)
        if chain is None:
            continue

        sig = "|".join(chain)
        if sig in seen or len(set(chain)) != len(chain):
            continue

        seen.add(sig)
        chain_upper = [w.upper() for w in chain]
        results.append({
            "chain": chain_upper,
            "explanations": [
                f"{chain_upper[i]} {chain_upper[i+1]}: (add explanation)"
                for i in range(len(chain_upper) - 1)
            ],
        })
        print(f"  ✓ [{difficulty}] {' → '.join(chain_upper)}")

    return results

# ── Difficulty config ─────────────────────────────────────────────────────────

DIFFICULTY_CONFIG = {
    "easy": {
        "min_score": 2000,
        "seeds": ["cold", "hot", "rain", "book", "play", "sun", "ice", "light",
                  "night", "air", "food", "home", "door", "road", "sea", "gold",
                  "green", "blue", "red", "black", "white", "full", "free", "fresh"],
    },
    "medium": {
        "min_score": 2000,
        "seeds": ["prime", "social", "field", "double", "master", "silver", "glass",
                  "smoke", "brain", "market", "short", "spin", "ground", "storm",
                  "sharp", "cross", "spring", "rock", "broad", "grand", "deep",
                  "wild", "dead", "stage", "ring", "long"],
    },
    "hard": {
        "min_score": 500,
        "seeds": ["cold", "night", "iron", "double", "razor", "bitter", "bone",
                  "steel", "hollow", "loose", "thin", "bare", "blank", "blind",
                  "dark", "raw", "dry", "flat", "grey", "worn", "stiff", "faint"],
    },
}

# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build-graph", action="store_true",
                        help="Query Datamuse and save phrase_graph.json (run once)")
    parser.add_argument("count", nargs="?", type=int, default=5,
                        help="Chains per difficulty (default 5)")
    args = parser.parse_args()

    if args.build_graph:
        print(f"Building phrase graph for {len(VOCAB)} vocabulary words…")
        graph = build_graph()
        save_graph(graph)
        return

    graph = load_graph()
    total_edges = sum(len(v) for v in graph.values())
    print(f"Loaded graph: {len(graph)} nodes, {total_edges} edges")

    output: dict[str, list] = {}
    for diff, cfg in DIFFICULTY_CONFIG.items():
        print(f"\nGenerating {args.count} {diff} chains…")
        output[diff] = generate(
            graph, diff, args.count,
            seeds=[s for s in cfg["seeds"] if s in graph],
            min_score=cfg["min_score"],
        )

    out_path = Path(__file__).parent / "generated_chains.json"
    out_path.write_text(json.dumps(output, indent=2))
    total = sum(len(v) for v in output.values())
    print(f"\nSaved {total} chains → {out_path}")
    print("Fill in explanations, then merge into reservoir.json")


if __name__ == "__main__":
    main()
