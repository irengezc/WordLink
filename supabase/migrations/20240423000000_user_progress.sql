-- ============================================================
-- Migration: user_progress table + get_chain RPC function
-- ============================================================

-- 1. Create user_progress table
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.user_progress (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    chain_id     UUID        NOT NULL REFERENCES public.chains(id) ON DELETE CASCADE,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    level        INTEGER     NOT NULL,
    CONSTRAINT user_progress_user_chain_unique UNIQUE (user_id, chain_id)
);

-- 2. Enable Row Level Security
-- ------------------------------------------------------------
ALTER TABLE public.user_progress ENABLE ROW LEVEL SECURITY;

-- 3. RLS policies: users can only read/write their own rows
-- ------------------------------------------------------------
CREATE POLICY "users_select_own_progress"
    ON public.user_progress
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "users_insert_own_progress"
    ON public.user_progress
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- 4. get_chain(p_user_id, p_difficulty)
--    Picks a random unseen chain, records progress, returns the full chain row.
--    SECURITY DEFINER bypasses RLS for the INSERT while the caller's JWT
--    still governs all direct table access.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_chain(
    p_user_id    UUID,
    p_difficulty TEXT
)
RETURNS SETOF public.chains
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_chain_id UUID;
    v_level    INTEGER;
BEGIN
    v_level := CASE p_difficulty
        WHEN 'easy'   THEN 1
        WHEN 'medium' THEN 2
        WHEN 'hard'   THEN 3
        ELSE 1
    END;

    SELECT c.id INTO v_chain_id
    FROM   public.chains c
    WHERE  c.difficulty = p_difficulty
      AND  NOT EXISTS (
               SELECT 1 FROM public.user_progress up
               WHERE up.user_id = p_user_id AND up.chain_id = c.id
           )
    ORDER BY RANDOM()
    LIMIT 1;

    IF v_chain_id IS NULL THEN
        RETURN;
    END IF;

    INSERT INTO public.user_progress (user_id, chain_id, level)
    VALUES (p_user_id, v_chain_id, v_level)
    ON CONFLICT (user_id, chain_id) DO NOTHING;

    RETURN QUERY SELECT * FROM public.chains WHERE id = v_chain_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_chain(UUID, TEXT) TO anon, authenticated;
