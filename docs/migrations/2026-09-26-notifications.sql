-- Push notifications (v3 Settings > Notifications, decision 19 in docs/design/v2-decisions.md).
-- Run once in the Supabase SQL editor, staging first. Safe to run again.
-- After running it, create the database webhook described in docs/testing/notifications.md.

-- One row per rower. A missing row means the defaults below.
create table if not exists notification_settings (
  user_id             uuid primary key references profiles on delete cascade,
  comments            boolean not null default true,
  personal_bests      boolean not null default true,
  club_activity       boolean not null default false,
  quiet_hours_enabled boolean not null default true,
  quiet_start         time not null default '22:00',
  quiet_end           time not null default '06:30',
  time_zone           text not null default 'Europe/London'
);
alter table notification_settings enable row level security;
drop policy if exists own_row on notification_settings;
create policy own_row on notification_settings for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- One row per phone. No policies: only the functions below and the server read it.
create table if not exists device_tokens (
  token      text primary key,
  user_id    uuid not null references profiles on delete cascade,
  bundle_id  text not null,
  apns_env   text check (apns_env in ('sandbox', 'production')),
  updated_at timestamptz not null default now()
);
create index if not exists device_tokens_user_id_idx on device_tokens (user_id);
alter table device_tokens enable row level security;

-- The outbox. Triggers add rows; the send-push Edge Function delivers each one once.
create table if not exists notifications (
  id           uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references profiles on delete cascade,
  actor_id     uuid not null references profiles on delete cascade,
  kind         text not null check (kind in ('comment', 'reply', 'pb', 'club_post')),
  session_id   uuid not null references sessions on delete cascade,
  comment_id   uuid references comments on delete cascade,
  created_at   timestamptz not null default now(),
  sent_at      timestamptz
);
create index if not exists notifications_recipient_idx on notifications (recipient_id, created_at desc);
create index if not exists notifications_session_idx on notifications (session_id);
alter table notifications enable row level security;
drop policy if exists read_own on notifications;
create policy read_own on notifications for select to authenticated
  using (recipient_id = auth.uid());

-- A phone signs in: its token now belongs to this rower, whoever had it before.
create or replace function register_device_token(p_token text, p_bundle_id text)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  insert into device_tokens (token, user_id, bundle_id)
  values (p_token, auth.uid(), p_bundle_id)
  on conflict (token) do update
    set user_id = excluded.user_id,
        bundle_id = excluded.bundle_id,
        updated_at = now();
end $$;

-- A phone signs out: stop sending to it.
create or replace function unregister_device_token(p_token text)
returns void
language sql security definer set search_path = public as $$
  delete from device_tokens where token = p_token and user_id = auth.uid();
$$;

revoke all on function register_device_token(text, text) from public, anon;
revoke all on function unregister_device_token(text) from public, anon;
grant execute on function register_device_token(text, text) to authenticated;
grant execute on function unregister_device_token(text) to authenticated;

-- Whether a recipient may be told about a session. The same rules the feed applies:
-- no block either way, private accounts only to approved followers, and the
-- post's own audience (following / club / everyone = either).
create or replace function may_notify(recipient uuid, actor uuid, sid uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from sessions s
    join profiles author on author.id = s.user_id
    left join profiles viewer on viewer.id = recipient
    where s.id = sid
      and not exists (
        select 1 from blocks b
        where (b.blocker_id = recipient and b.blocked_id in (actor, s.user_id))
           or (b.blocked_id = recipient and b.blocker_id in (actor, s.user_id))
      )
      and (
        s.user_id = recipient
        or (
          (not author.is_private or exists (
            select 1 from follows f
            where f.follower_id = recipient and f.followee_id = s.user_id and f.status = 'accepted'))
          and (
            (s.visibility in ('following', 'everyone') and exists (
              select 1 from follows f
              where f.follower_id = recipient and f.followee_id = s.user_id and f.status = 'accepted'))
            or (s.visibility in ('club', 'everyone')
                and author.club_id is not null and viewer.club_id = author.club_id)
          )
        )
      )
  );
$$;
revoke all on function may_notify(uuid, uuid, uuid) from public, anon, authenticated;

-- New comment: tell the post's owner, and everyone else who has commented on it.
create or replace function comments_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  owner uuid;
begin
  begin
    select s.user_id into owner from sessions s where s.id = new.session_id;
    if owner is null then
      return new;
    end if;
    insert into notifications (recipient_id, actor_id, kind, session_id, comment_id)
    select r.recipient, new.user_id, r.kind, new.session_id, new.id
    from (
      select owner as recipient, 'comment'::text as kind
      where owner <> new.user_id
      union
      select distinct c.user_id, 'reply'::text
      from comments c
      where c.session_id = new.session_id
        and c.id <> new.id
        and c.user_id <> new.user_id
        and c.user_id <> owner
    ) r
    left join notification_settings ns on ns.user_id = r.recipient
    where coalesce(ns.comments, true)
      and may_notify(r.recipient, new.user_id, new.session_id);
  exception when others then
    -- A notification problem must never stop a comment being posted.
    raise warning 'comments_notify: %', sqlerrm;
  end;
  return new;
end $$;

drop trigger if exists comments_after_insert_notify on comments;
create trigger comments_after_insert_notify
  after insert on comments
  for each row execute function comments_notify();

-- New post. Fires on the post's first piece, not on the session row: the app saves
-- the pieces straight after the session, so by now the lead piece's numbers exist
-- for the alert text. Personal bests go to the rower and their followers; club
-- activity to clubmates (anyone already getting the PB alert is skipped).
create or replace function sessions_notify()
returns trigger
language plpgsql security definer set search_path = public as $$
declare
  s sessions%rowtype;
  author_club uuid;
begin
  begin
    select * into s from sessions where id = new.session_id;
    if not found
       or s.posted_at < now() - interval '1 hour'
       or exists (select 1 from notifications n
                  where n.session_id = s.id and n.kind in ('pb', 'club_post')) then
      return new;
    end if;

    if s.is_new_pb then
      insert into notifications (recipient_id, actor_id, kind, session_id)
      select r.id, s.user_id, 'pb', s.id
      from (
        select s.user_id as id
        union
        select f.follower_id from follows f
        where f.followee_id = s.user_id and f.status = 'accepted'
      ) r
      left join notification_settings ns on ns.user_id = r.id
      where coalesce(ns.personal_bests, true)
        and may_notify(r.id, s.user_id, s.id);
    end if;

    select p.club_id into author_club from profiles p where p.id = s.user_id;
    if author_club is not null then
      insert into notifications (recipient_id, actor_id, kind, session_id)
      select p.id, s.user_id, 'club_post', s.id
      from profiles p
      left join notification_settings ns on ns.user_id = p.id
      where p.club_id = author_club
        and p.id <> s.user_id
        and coalesce(ns.club_activity, false)
        and may_notify(p.id, s.user_id, s.id)
        and not exists (select 1 from notifications n
                        where n.session_id = s.id and n.recipient_id = p.id and n.kind = 'pb');
    end if;
  exception when others then
    -- A notification problem must never stop a session being posted.
    raise warning 'sessions_notify: %', sqlerrm;
  end;
  return new;
end $$;

drop trigger if exists segments_after_insert_notify on segments;
create trigger segments_after_insert_notify
  after insert on segments
  for each row when (new.position = 0)
  execute function sessions_notify();
