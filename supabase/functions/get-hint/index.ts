import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const { session_id, index, revealed_count } = await req.json();

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data: session, error } = await supabase
    .from("game_sessions")
    .select("expires_at, chains(chain)")
    .eq("id", session_id)
    .single();

  if (error || !session) {
    return new Response(JSON.stringify({ error: "Session not found" }), { status: 404, headers: corsHeaders });
  }

  if (new Date(session.expires_at) < new Date()) {
    return new Response(JSON.stringify({ error: "Session expired" }), { status: 410, headers: corsHeaders });
  }

  const chain: string[] = (session.chains as any).chain;
  const targetWord = chain[index + 1];

  if (!targetWord) {
    return new Response(JSON.stringify({ error: "Invalid index" }), { status: 400, headers: corsHeaders });
  }

  const clamped = Math.min(revealed_count, targetWord.length);
  const hint = targetWord.substring(0, clamped);
  const word_length = targetWord.length;

  return new Response(
    JSON.stringify({ hint, word_length }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});
