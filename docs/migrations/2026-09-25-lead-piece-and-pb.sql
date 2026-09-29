-- ---------------------------------------------------------------
-- Lead piece and new-PB flag (docs/design/v2-decisions.md #10, #12)
-- Run once per Supabase project, in the SQL editor, staging FIRST,
-- after 2026-09-24-review-session.sql. One transaction.
--   * segments.is_lead — the piece that leads the post on the feed
--     (most intense: fastest average split, never warm-up/cool-down;
--     the Main piece for a test). At most one per session.
--   * sessions.is_new_pb — the session's test result beat the rower's
--     previous best; the feed highlights these posts.
-- ---------------------------------------------------------------
begin;

alter table segments add column is_lead boolean not null default false;
create unique index segments_one_lead_per_session on segments (session_id) where is_lead;

alter table sessions add column is_new_pb boolean not null default false;

-- Existing sessions: apply the same rule to pick their lead piece.
with ranked as (
  select id,
         row_number() over (
           partition by session_id
           order by
             (label in ('warmup', 'cooldown') or split_ms is null or split_ms <= 0),
             split_ms,
             position
         ) as rn
  from segments
)
update segments s set is_lead = true
from ranked r
where s.id = r.id and r.rn = 1;

commit;
