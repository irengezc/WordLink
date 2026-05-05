#!/usr/bin/env python3
"""
Delete broken chains from Supabase, handling the game_sessions foreign key.

Steps:
  1. Fetch all chains from Supabase
  2. Identify broken ones (compound words / known bad pairs)
  3. Delete game_sessions rows that reference those chain IDs
  4. Delete the broken chains
"""

import json
import re
import sys
from pathlib import Path

import requests

# ── Config ────────────────────────────────────────────────────────────────────

SUPABASE_URL = "https://azsrjwfieyldeertdlws.supabase.co"
SERVICE_KEY  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF6c3Jqd2ZpZXlsZGVlcnRkbHdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjA3Mzk1OCwiZXhwIjoyMDkxNjQ5OTU4fQ.oQEVMBN1DrIkdF9XG_xXkesFe5GDzwxmwLdwS2AAEtA"

HEADERS = {
    "apikey":        SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type":  "application/json",
    "Prefer":        "return=representation",
}

# ── Broken-chain detection (same logic as clean_reservoir.py) ─────────────────

DICT_WORDS = {
    w.strip().lower()
    for w in Path("/usr/share/dict/words").read_text().splitlines()
    if w.strip().isalpha()
}

EXTRA_BAD = {
    ("shop", "ping"),    ("less", "on"),      ("pack", "age"),
    ("move", "ment"),    ("ment", "wide"),     ("shift", "er"),
    ("er", "board"),     ("maker", "shift"),   ("eyed", "witness"),
    ("beat", "nick"),    ("changer", "over"),  ("keeper", "sake"),
    ("clad", "secret"),  ("foxed", "hole"),    ("holder", "on"),
    ("shocked", "awe"),  ("backer", "board"),  ("minded", "set"),
    ("lining", "up"),    ("plan", "net"),      ("luck", "key"),
}

def is_broken(chain: list[str]) -> tuple[bool, str]:
    for i in range(len(chain) - 1):
        w1, w2 = chain[i].lower(), chain[i + 1].lower()
        if (w1, w2) in EXTRA_BAD:
            return True, f"{w1}+{w2} (known bad pair)"
        if (w1 + w2) in DICT_WORDS:
            return True, f"{w1}+{w2} → '{w1+w2}' (compound)"
    return False, ""

# ── Supabase helpers ──────────────────────────────────────────────────────────

def sb_get(path: str, params: dict = None):
    r = requests.get(f"{SUPABASE_URL}/rest/v1/{path}", headers=HEADERS, params=params)
    r.raise_for_status()
    return r.json()

def sb_delete(path: str, params: dict = None):
    r = requests.delete(f"{SUPABASE_URL}/rest/v1/{path}", headers=HEADERS, params=params)
    return r

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    # 1. Fetch all chains
    print("Fetching all chains from Supabase…")
    chains = sb_get("chains", {"select": "id,chain,difficulty", "limit": "1000"})
    print(f"  Total rows: {len(chains)}")

    # 2. Find broken ones
    broken_ids = []
    for row in chains:
        chain_list = row["chain"] if isinstance(row["chain"], list) else json.loads(row["chain"])
        broken, reason = is_broken(chain_list)
        if broken:
            broken_ids.append(row["id"])
            print(f"  ✗ [{row['difficulty']}] {' → '.join(chain_list)}")
            print(f"      reason: {reason}")

    if not broken_ids:
        print("\nNo broken chains found — nothing to do.")
        return

    print(f"\nFound {len(broken_ids)} broken chains to delete.")

    # 3. Delete referencing game_sessions
    ids_csv = ",".join(broken_ids)
    print(f"\nDeleting game_sessions that reference these chains…")
    r = sb_delete("game_sessions", {"chain_id": f"in.({ids_csv})"})
    print(f"  game_sessions delete status: {r.status_code}")
    if r.status_code not in (200, 204):
        print(f"  Response: {r.text}")
        sys.exit(1)

    # 4. Delete the broken chains
    print("Deleting broken chains…")
    r = sb_delete("chains", {"id": f"in.({ids_csv})"})
    print(f"  chains delete status: {r.status_code}")
    if r.status_code not in (200, 204):
        print(f"  Response: {r.text}")
        sys.exit(1)

    # 5. Verify
    remaining = sb_get("chains", {"select": "id,difficulty", "limit": "1000"})
    by_diff: dict[str, int] = {}
    for row in remaining:
        by_diff[row["difficulty"]] = by_diff.get(row["difficulty"], 0) + 1
    print(f"\nDone. Remaining chains in Supabase: {len(remaining)}")
    for diff, count in sorted(by_diff.items()):
        print(f"  {diff}: {count}")

if __name__ == "__main__":
    main()
