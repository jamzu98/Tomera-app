# sync/

Placeholder for the Phase 4 sync layer (Supabase auth + Postgres, evaluating
PowerSync vs. a custom push/pull). Intentionally empty until then — see §5 of
the project spec for the sync-readiness rules the rest of the codebase already
follows (UUID PKs, soft deletes, `updated_at`/`is_dirty` bookkeeping,
`owner_id` columns, UTC epoch-ms timestamps).
