const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const complexityMap: Record<string, string> = {
  easy: "very simple common two-word phrases (e.g., COLD WATER, ICE CREAM)",
  medium: "common idioms and collocations (e.g., SOCIAL MEDIA, FIELD TRIP, HIGH SCHOOL)",
  hard: "complex idioms and abstract connections (e.g., COLD FEET, SILVER LINING, NIGHT OWL)",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const { difficulty } = await req.json();
  if (!["easy", "medium", "hard"].includes(difficulty)) {
    return new Response(JSON.stringify({ error: "Invalid difficulty" }), { status: 400, headers: corsHeaders });
  }

  const apiKey = Deno.env.get("DEEPSEEK_API_KEY");
  if (!apiKey) {
    return new Response(JSON.stringify({ error: "Service unavailable" }), { status: 503, headers: corsHeaders });
  }

  const prompt = `Generate a word chain of exactly 9 English words.
Difficulty level: ${difficulty}. Use ${complexityMap[difficulty]}.

STRICT RULES — read carefully:
1. Every word in the chain must be a real, standalone English dictionary word.
2. Each consecutive pair must form a common TWO-WORD PHRASE — two separate words used together as a phrase (e.g. "high school", "bus stop", "sign language", "cold water", "social media").
3. The pair must NOT merge into a single compound word:
   - FORBIDDEN: BLACK + BIRD → "blackbird" (one merged word)
   - FORBIDDEN: WATER + FALL → "waterfall" (one merged word)
   - ALLOWED: COLD + WATER → "cold water" (genuine two-word phrase)
   - ALLOWED: HIGH + SCHOOL → "high school" (genuine two-word phrase)
4. Ask yourself: "Is this phrase normally written as two separate words?" If yes, allowed. If one word, forbidden.

For each of the 8 consecutive pairs, provide a "pairs" entry with the exact words and explanation.
Respond with JSON only:
{"chain": ["WORD1","WORD2","WORD3","WORD4","WORD5","WORD6","WORD7","WORD8","WORD9"], "pairs": [{"w1":"WORD1","w2":"WORD2","explanation":"WORD1 WORD2: one sentence definition."},{"w1":"WORD2","w2":"WORD3","explanation":"WORD2 WORD3: one sentence definition."},{"w1":"WORD3","w2":"WORD4","explanation":"WORD3 WORD4: one sentence definition."},{"w1":"WORD4","w2":"WORD5","explanation":"WORD4 WORD5: one sentence definition."},{"w1":"WORD5","w2":"WORD6","explanation":"WORD5 WORD6: one sentence definition."},{"w1":"WORD6","w2":"WORD7","explanation":"WORD6 WORD7: one sentence definition."},{"w1":"WORD7","w2":"WORD8","explanation":"WORD7 WORD8: one sentence definition."},{"w1":"WORD8","w2":"WORD9","explanation":"WORD8 WORD9: one sentence definition."}]}`;

  const deepseekResponse = await fetch("https://api.deepseek.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "deepseek-chat",
      messages: [{ role: "user", content: prompt }],
      response_format: { type: "json_object" },
    }),
  });

  if (!deepseekResponse.ok) {
    return new Response(JSON.stringify({ error: "Generation failed" }), { status: 502, headers: corsHeaders });
  }

  const deepseekData = await deepseekResponse.json();
  const content = deepseekData?.choices?.[0]?.message?.content;
  if (!content) {
    return new Response(JSON.stringify({ error: "Empty response" }), { status: 502, headers: corsHeaders });
  }

  const chainData = JSON.parse(content);
  const upperChain: string[] = (chainData.chain as string[]).map((w: string) => w.toUpperCase().trim());

  if (upperChain.length < 9 || !Array.isArray(chainData.pairs) || chainData.pairs.length < 8) {
    return new Response(JSON.stringify({ error: "Invalid chain format" }), { status: 502, headers: corsHeaders });
  }

  const explanations: string[] = [];
  for (let i = 0; i < 8; i++) {
    const w1 = upperChain[i];
    const w2 = upperChain[i + 1];
    const match = chainData.pairs.find(
      (p: { w1: string; w2: string; explanation: string }) =>
        p.w1.toUpperCase().trim() === w1 && p.w2.toUpperCase().trim() === w2
    );
    explanations.push(match?.explanation ?? (chainData.pairs[i]?.explanation ?? ""));
  }

  return new Response(
    JSON.stringify({ chain: upperChain, explanations }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});
