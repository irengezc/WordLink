import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const { difficulty } = await req.json();
  if (!["easy", "medium", "hard"].includes(difficulty)) {
    return new Response(JSON.stringify({ error: "Invalid difficulty" }), { status: 400, headers: corsHeaders });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data: chains, error } = await supabase
    .from("chains")
    .select("id, chain, explanations")
    .eq("difficulty", difficulty);

  if (error || !chains || chains.length === 0) {
    return new Response(JSON.stringify({ error: "No chains available" }), { status: 500, headers: corsHeaders });
  }

  const picked = chains[Math.floor(Math.random() * chains.length)];

  const { data: session, error: sessionError } = await supabase
    .from("game_sessions")
    .insert({ chain_id: picked.id, difficulty })
    .select("id")
    .single();

  if (sessionError || !session) {
    return new Response(JSON.stringify({ error: "Failed to create session" }), { status: 500, headers: corsHeaders });
  }

  return new Response(
    JSON.stringify({
      session_id: session.id,
      chain: picked.chain,
      explanations: picked.explanations,
    }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );
});
