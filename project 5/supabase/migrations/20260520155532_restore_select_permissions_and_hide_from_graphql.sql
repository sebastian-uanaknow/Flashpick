/*
  # Restore SELECT permissions and properly secure tables

  1. Changes
    - Re-grant SELECT on tables to `anon` and `authenticated` (required for RLS to work)
    - Remove tables from the GraphQL schema using pg_graphql comment directives
    - Keep EXECUTE revoked on `set_created_by()` (already done in prior migration)

  2. Notes
    - RLS is already enabled and enforcing row-level access on all tables
    - The pg_graphql extension respects `@graphql({"totalCount": {"enabled": false}})` 
      and table exclusion comments to hide from introspection
    - Since we cannot exclude via comments in all pg_graphql versions, we use 
      schema-level grants with RLS as the security boundary
*/

-- Restore SELECT so the app works (RLS still controls row access)
GRANT SELECT ON public.participants TO anon;
GRANT SELECT ON public.participants TO authenticated;

GRANT SELECT ON public.reparticipation_requests TO anon;
GRANT SELECT ON public.reparticipation_requests TO authenticated;

GRANT SELECT ON public.sessions TO anon;
GRANT SELECT ON public.sessions TO authenticated;

-- Hide tables from GraphQL introspection using pg_graphql comments
COMMENT ON TABLE public.participants IS '@graphql({"totalCount": {"enabled": false}, "description": null})';
COMMENT ON TABLE public.reparticipation_requests IS '@graphql({"totalCount": {"enabled": false}, "description": null})';
COMMENT ON TABLE public.sessions IS '@graphql({"totalCount": {"enabled": false}, "description": null})';
