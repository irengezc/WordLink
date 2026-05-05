#!/usr/bin/env node

/**
 * generate-chains.js
 *
 * Generates Wordlink word chains via Claude and inserts them into Supabase.
 *
 * Usage:
 *   ANTHROPIC_API_KEY=... SUPABASE_SERVICE_ROLE_KEY=... node generate-chains.js <easy|medium|hard>
 */

import Anthropic from '@anthropic-ai/sdk';
import { createClient } from '@supabase/supabase-js';

// ── Config ────────────────────────────────────────────────────────────────────

const SUPABASE_URL    = 'https://azsrjwfieyldeertdlws.supabase.co';
const CHAINS_PER_RUN  = 10;

const difficulty = process.argv[2];
if (!['easy', 'medium', 'hard'].includes(difficulty)) {
  console.error('Usage: node generate-chains.js <easy|medium|hard>');
  process.exit(1);
}

if (!process.env.ANTHROPIC_API_KEY) {
  console.error('Missing ANTHROPIC_API_KEY environment variable');
  process.exit(1);
}
if (!process.env.SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Missing SUPABASE_SERVICE_ROLE_KEY environment variable');
  process.exit(1);
}

const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
const supabase  = createClient(SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

// ── Difficulty prompt fragment ────────────────────────────────────────────────

const difficultyGuide = {
  easy:   'Use common, everyday words that most English speakers know (e.g. FIRE, WATER, HAND).',
  medium: 'Use less common but widely recognised words and idioms (e.g. SILVER, ANCHOR, PITCH).',
  hard:   'Use advanced vocabulary, rare idioms, and abstract conceptual links (e.g. CRUX, LODE, STAR).',
};

// ── Fetch existing chain arrays from Supabase ─────────────────────────────────

async function fetchExistingChainKeys() {
  const { data, error } = await supabase
    .from('chains')
    .select('chain')
    .eq('difficulty', difficulty);

  if (error) throw new Error(`Supabase fetch failed: ${error.message}`);

  // Store each chain as a canonical JSON string for O(1) duplicate lookup
  return new Set(data.map(row => JSON.stringify(row.chain)));
}

// ── Call Claude to generate chains ────────────────────────────────────────────

async function generateChains() {
  const prompt = `\
You are generating word chains for a puzzle game called Wordlink.

Generate exactly ${CHAINS_PER_RUN} chains at **${difficulty}** difficulty.

## Rules
1. Each chain has exactly 9 uppercase English words.
2. Adjacent words must connect via a common English compound word or well-known two-word phrase.
   • Example: FIRE → TRUCK → DRIVER  (FIRE TRUCK, TRUCK DRIVER)
3. Every word must be a standalone dictionary word.
   • NEVER split a compound word: e.g. do NOT use RELATION + SHIP because RELATIONSHIP is one word.
4. Difficulty guide: ${difficultyGuide[difficulty]}
5. No two chains in your response may be identical.

## Output format
Return ONLY a valid JSON array — no prose, no markdown fences. Each element:
{
  "chain": ["WORD1","WORD2","WORD3","WORD4","WORD5","WORD6","WORD7","WORD8","WORD9"],
  "explanations": [
    "WORD1 WORD2: one-sentence explanation of how they form a compound word or phrase",
    "WORD2 WORD3: ...",
    "WORD3 WORD4: ...",
    "WORD4 WORD5: ...",
    "WORD5 WORD6: ...",
    "WORD6 WORD7: ...",
    "WORD7 WORD8: ...",
    "WORD8 WORD9: ..."
  ]
}`;

  process.stdout.write('🤖 Generating');
  const ticker = setInterval(() => process.stdout.write('.'), 1500);

  const response = await anthropic.messages.create({
    model:      'claude-opus-4-6',
    max_tokens: 8000,
    messages:   [{ role: 'user', content: prompt }],
  });

  clearInterval(ticker);
  console.log(' done\n');

  // Extract text blocks only (skip thinking blocks)
  const fullText = response.content
    .filter(b => b.type === 'text')
    .map(b => b.text)
    .join('');

  // Strip markdown code fences if Claude wrapped the JSON
  const stripped = fullText
    .replace(/^```(?:json)?\s*/m, '')
    .replace(/\s*```\s*$/m, '')
    .trim();

  // Extract the JSON array
  const match = stripped.match(/\[[\s\S]*\]/);
  if (!match) {
    console.error('Content blocks:', response.content.map(b => ({ type: b.type, len: b.text?.length ?? b.thinking?.length ?? 0 })));
    console.error('Full text:\n', fullText);
    throw new Error('No JSON array found in Claude response');
  }

  return JSON.parse(match[0]);
}

// ── Validate a single chain object ───────────────────────────────────────────

function validate(item) {
  if (!item || typeof item !== 'object')                               return 'not an object';
  if (!Array.isArray(item.chain) || item.chain.length !== 9)          return 'chain must be 9 words';
  if (!item.chain.every(w => typeof w === 'string' && /^[A-Z]+$/.test(w)))
                                                                       return 'all words must be uppercase letters';
  if (!Array.isArray(item.explanations) || item.explanations.length !== 8)
                                                                       return 'explanations must be 8 strings';
  if (!item.explanations.every(e => typeof e === 'string' && e.length > 0))
                                                                       return 'each explanation must be a non-empty string';
  return null; // valid
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log(`\n🔗 Wordlink chain generator — difficulty: ${difficulty}\n`);

  // 1. Load existing chains for duplicate detection
  console.log('📦 Loading existing chains from Supabase…');
  const existingKeys = await fetchExistingChainKeys();
  console.log(`   Found ${existingKeys.size} existing ${difficulty} chain(s)\n`);

  // 2. Ask Claude to generate new chains
  const generated = await generateChains();
  console.log(`📋 Claude returned ${generated.length} chain(s)\n`);

  // 3. Validate, deduplicate, and insert
  let inserted         = 0;
  let skippedDuplicate = 0;
  let skippedInvalid   = 0;

  for (const item of generated) {
    const err = validate(item);
    if (err) {
      console.log(`⚠️  Invalid (${err}): ${JSON.stringify(item?.chain)}`);
      skippedInvalid++;
      continue;
    }

    const key = JSON.stringify(item.chain);
    if (existingKeys.has(key)) {
      console.log(`⏭️  Duplicate: ${item.chain.join(' → ')}`);
      skippedDuplicate++;
      continue;
    }

    const { error } = await supabase.from('chains').insert({
      chain:        item.chain,
      explanations: item.explanations,
      difficulty,
    });

    if (error) {
      console.error(`❌ Insert failed for [${item.chain.join(' → ')}]: ${error.message}`);
    } else {
      console.log(`✅ Inserted: ${item.chain.join(' → ')}`);
      existingKeys.add(key); // prevent re-insertion within the same run
      inserted++;
    }
  }

  // 4. Summary
  console.log(`
📊 Summary
   ✅ Inserted:  ${inserted}
   ⏭️  Duplicate: ${skippedDuplicate}
   ⚠️  Invalid:   ${skippedInvalid}
`);
}

main().catch(err => {
  console.error('\n💥 Fatal error:', err.message);
  process.exit(1);
});
