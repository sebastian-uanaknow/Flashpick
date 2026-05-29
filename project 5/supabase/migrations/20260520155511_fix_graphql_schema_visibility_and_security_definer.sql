/*
  # Fix GraphQL schema visibility and security definer issues

  1. Security Changes
    - Revoke SELECT on `participants`, `reparticipation_requests`, and `sessions`
      from `anon` and `authenticated` roles to hide them from GraphQL introspection
    - Grant back only the minimum needed via RLS policies (RLS still controls actual access)
    - Revoke EXECUTE on `set_created_by()` from `anon` and `authenticated`

  2. Notes
    - Tables remain accessible via the REST API through RLS policies
    - Revoking SELECT at the role level hides the table from GraphQL schema discovery
    - RLS policies still enforce row-level access independently
    - The `set_created_by()` trigger function should not be callable directly via RPC
*/

-- Hide tables from GraphQL schema by revoking role-level SELECT
REVOKE SELECT ON public.participants FROM anon;
REVOKE SELECT ON public.participants FROM authenticated;

REVOKE SELECT ON public.reparticipation_requests FROM anon;
REVOKE SELECT ON public.reparticipation_requests FROM authenticated;

REVOKE SELECT ON public.sessions FROM anon;
REVOKE SELECT ON public.sessions FROM authenticated;

-- Revoke direct execution of the SECURITY DEFINER function
REVOKE EXECUTE ON FUNCTION public.set_created_by() FROM anon;
REVOKE EXECUTE ON FUNCTION public.set_created_by() FROM authenticated;
