/*
  # Clean up and properly address security concerns

  1. Changes
    - Remove ineffective graphql comments from tables
    - Ensure `set_created_by()` is not directly callable (already revoked)
    - Verify the function revocation is in place

  2. Security Notes
    - Tables `participants`, `reparticipation_requests`, and `sessions` are 
      intentionally accessible to `anon` and `authenticated` via RLS policies
    - GraphQL visibility is a consequence of necessary SELECT grants; 
      RLS enforces actual data access security
    - The `set_created_by()` function EXECUTE has been revoked from both roles
      so it cannot be called directly via RPC
*/

-- Remove the ineffective comments
COMMENT ON TABLE public.participants IS NULL;
COMMENT ON TABLE public.reparticipation_requests IS NULL;
COMMENT ON TABLE public.sessions IS NULL;

-- Ensure the function cannot be called via RPC (idempotent)
REVOKE EXECUTE ON FUNCTION public.set_created_by() FROM anon;
REVOKE EXECUTE ON FUNCTION public.set_created_by() FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.set_created_by() FROM public;
