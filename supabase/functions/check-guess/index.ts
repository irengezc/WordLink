import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const { session_id, index, guess } = await req.json();

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data: session, error } = await supabase
    .from("game_sessions")
    .select("id, current_index, expires_at, chains(chain, explanations)")
    .eq("id", session_id)
    .single();

  if (error || !session) {
    return new Response(JSON.stringify({ error: "Session not found" }), { status: 404, headers: corsHeaders });
  }

  if (new Date(session.expires_at) < new Date()) {
    return new Response(JSON.stringify({ error: "Session expired" }), { status: 410, headers: corsHeaders });
  }

  const chain: string[] = (session.chains as any).chain;
  const explanations: string[] = (session.chains as any).explanations;
  const targetWord = chain[index + 1];

  if (!targetWord) {
    return new Response(JSON.stringify({ error: "Invalid index" }), { status: 400, headers: corsHeaders });
  }

  const correct = guess.toUpperCase().trim() === targetWord.toUpperCase();

  if (!correct) {
    return new Response(
      JSON.stringify({ correct: false }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const isFinal = index + 1 >= chain.length - 1;
  const nextWord = !isFinal ? chain[index + 2] : null;

  await supabase
    .from("game_sessions")
    .update({ current_index: index + 1 })
    .eq("id", session_id);

  return new Response(
    JSON.stringify({
      correct: true,
      word: targetWord,
      explanation: explanations[index] ?? "",
      is_final: isFinal,
      next_word: nextWord ?? null,
    }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});
