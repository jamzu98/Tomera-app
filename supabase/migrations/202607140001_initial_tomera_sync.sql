create sequence if not exists public.sync_version_seq;

create table public.workspaces (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at bigint not null, updated_at bigint not null, deleted_at bigint,
  name text not null, color bigint not null, icon text not null,
  enabled_modules text not null, sort_order bigint not null default 0,
  default_hourly_rate_cents bigint, unique (id, owner_id)
);
create table public.contacts (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at bigint not null, updated_at bigint not null, deleted_at bigint,
  name text not null, email text, phone text, organization text, notes_text text,
  default_hourly_rate_cents bigint, unique (id, owner_id)
);
create table public.workspace_contacts (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at bigint not null, updated_at bigint not null, deleted_at bigint,
  workspace_id uuid not null, contact_id uuid not null, role_label text,
  hourly_rate_cents bigint, unique (id, owner_id),
  foreign key (workspace_id, owner_id) references public.workspaces(id, owner_id) deferrable initially deferred,
  foreign key (contact_id, owner_id) references public.contacts(id, owner_id) deferrable initially deferred
);
create table public.projects (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at bigint not null, updated_at bigint not null, deleted_at bigint,
  workspace_id uuid not null, name text not null, description text, color bigint,
  contact_id uuid, archived boolean not null default false, hourly_rate_cents bigint,
  unique (id, owner_id),
  foreign key (workspace_id, owner_id) references public.workspaces(id, owner_id) deferrable initially deferred,
  foreign key (contact_id, owner_id) references public.contacts(id, owner_id) deferrable initially deferred
);
create table public.event_series (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at bigint not null, updated_at bigint not null, deleted_at bigint,
  workspace_id uuid not null, title text not null, description text, location text,
  local_starts_at text not null, duration_ms bigint not null, timezone_id text not null,
  all_day boolean not null default false, project_id uuid, reminder_offset_minutes bigint,
  rule_json text not null, ends_before_local text, unique (id, owner_id),
  foreign key (workspace_id, owner_id) references public.workspaces(id, owner_id) deferrable initially deferred,
  foreign key (project_id, owner_id) references public.projects(id, owner_id) deferrable initially deferred
);
create table public.event_series_contacts (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at bigint not null, updated_at bigint not null, deleted_at bigint,
  series_id uuid not null, contact_id uuid not null, unique (id, owner_id),
  foreign key (series_id, owner_id) references public.event_series(id, owner_id) deferrable initially deferred,
  foreign key (contact_id, owner_id) references public.contacts(id, owner_id) deferrable initially deferred
);
create table public.events (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at bigint not null, updated_at bigint not null, deleted_at bigint,
  workspace_id uuid not null, title text not null, description text, location text,
  starts_at bigint not null, ends_at bigint not null, all_day boolean not null default false,
  rrule text, project_id uuid, series_id uuid, occurrence_key text,
  original_starts_at bigint, recurrence_exception boolean default false,
  recurrence_suppressed boolean default false, unique (id, owner_id),
  foreign key (workspace_id, owner_id) references public.workspaces(id, owner_id) deferrable initially deferred,
  foreign key (project_id, owner_id) references public.projects(id, owner_id) deferrable initially deferred,
  foreign key (series_id, owner_id) references public.event_series(id, owner_id) deferrable initially deferred
);
create table public.event_contacts (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at bigint not null, updated_at bigint not null, deleted_at bigint,
  event_id uuid not null, contact_id uuid not null, unique (id, owner_id),
  foreign key (event_id, owner_id) references public.events(id, owner_id) deferrable initially deferred,
  foreign key (contact_id, owner_id) references public.contacts(id, owner_id) deferrable initially deferred
);
create table public.task_series (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at bigint not null, updated_at bigint not null, deleted_at bigint,
  workspace_id uuid not null, title text not null, description text,
  priority text not null default 'normal', first_due_local text not null,
  timezone_id text not null, contact_id uuid, project_id uuid,
  reminder_offset_minutes bigint, rule_json text not null,
  repeat_anchor text not null default 'schedule', unique (id, owner_id),
  foreign key (workspace_id, owner_id) references public.workspaces(id, owner_id) deferrable initially deferred,
  foreign key (contact_id, owner_id) references public.contacts(id, owner_id) deferrable initially deferred,
  foreign key (project_id, owner_id) references public.projects(id, owner_id) deferrable initially deferred
);
create table public.tasks (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at bigint not null, updated_at bigint not null, deleted_at bigint,
  workspace_id uuid not null, title text not null, description text,
  status text not null default 'open', due_at bigint, reminder_at bigint,
  event_id uuid, contact_id uuid, priority text not null default 'normal', project_id uuid,
  completed_at bigint, task_series_id uuid, task_occurrence_number bigint,
  predecessor_task_id uuid, recurrence_scheduled_local text, unique (id, owner_id),
  foreign key (workspace_id, owner_id) references public.workspaces(id, owner_id) deferrable initially deferred,
  foreign key (event_id, owner_id) references public.events(id, owner_id) deferrable initially deferred,
  foreign key (contact_id, owner_id) references public.contacts(id, owner_id) deferrable initially deferred,
  foreign key (project_id, owner_id) references public.projects(id, owner_id) deferrable initially deferred,
  foreign key (task_series_id, owner_id) references public.task_series(id, owner_id) deferrable initially deferred,
  foreign key (predecessor_task_id, owner_id) references public.tasks(id, owner_id) deferrable initially deferred
);
create table public.notes (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at bigint not null, updated_at bigint not null, deleted_at bigint,
  workspace_id uuid, title text not null, body text not null,
  parent_type text, parent_id uuid, unique (id, owner_id),
  foreign key (workspace_id, owner_id) references public.workspaces(id, owner_id) deferrable initially deferred
);
create table public.note_links (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at bigint not null, updated_at bigint not null, deleted_at bigint,
  note_id uuid not null, target_type text not null, target_id uuid not null,
  unique (id, owner_id),
  foreign key (note_id, owner_id) references public.notes(id, owner_id) deferrable initially deferred
);
create table public.timer_sessions (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at bigint not null, updated_at bigint not null, deleted_at bigint,
  workspace_id uuid not null, contact_id uuid, project_id uuid, description text,
  started_at bigint not null, stopped_at bigint, unique (id, owner_id),
  foreign key (workspace_id, owner_id) references public.workspaces(id, owner_id) deferrable initially deferred,
  foreign key (contact_id, owner_id) references public.contacts(id, owner_id) deferrable initially deferred,
  foreign key (project_id, owner_id) references public.projects(id, owner_id) deferrable initially deferred
);
create table public.billable_items (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at bigint not null, updated_at bigint not null, deleted_at bigint,
  workspace_id uuid not null, contact_id uuid, event_id uuid, task_id uuid,
  timer_session_id uuid, type text not null, title text not null, description text,
  rate_cents bigint, duration_minutes bigint, amount_cents bigint,
  currency text not null default 'EUR', status text not null default 'unbilled',
  project_id uuid, unique (id, owner_id),
  foreign key (workspace_id, owner_id) references public.workspaces(id, owner_id) deferrable initially deferred,
  foreign key (contact_id, owner_id) references public.contacts(id, owner_id) deferrable initially deferred,
  foreign key (event_id, owner_id) references public.events(id, owner_id) deferrable initially deferred,
  foreign key (task_id, owner_id) references public.tasks(id, owner_id) deferrable initially deferred,
  foreign key (timer_session_id, owner_id) references public.timer_sessions(id, owner_id) deferrable initially deferred,
  foreign key (project_id, owner_id) references public.projects(id, owner_id) deferrable initially deferred
);
create table public.reminders (
  id uuid primary key, owner_id uuid not null references auth.users(id) on delete cascade,
  created_at bigint not null, updated_at bigint not null, deleted_at bigint,
  parent_type text not null, parent_id uuid not null, fire_at bigint not null,
  delivered boolean not null default false, unique (id, owner_id)
);

create table public.sync_changes (
  owner_id uuid not null references auth.users(id) on delete cascade,
  table_name text not null,
  row_id uuid not null,
  version bigint not null,
  row_data jsonb not null,
  primary key (owner_id, table_name, row_id)
);
create index sync_changes_owner_version on public.sync_changes(owner_id, version);

create or replace function public.capture_sync_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.sync_changes(owner_id, table_name, row_id, version, row_data)
  values (new.owner_id, tg_table_name, new.id, nextval('public.sync_version_seq'), to_jsonb(new))
  on conflict (owner_id, table_name, row_id) do update
    set version = excluded.version, row_data = excluded.row_data;
  return new;
end;
$$;

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'workspaces','contacts','workspace_contacts','projects','event_series',
    'event_series_contacts','events','event_contacts','task_series','tasks',
    'notes','note_links','timer_sessions','billable_items','reminders'
  ] loop
    execute format(
      'create trigger capture_sync_change after insert or update on public.%I '
      'for each row execute function public.capture_sync_change()', table_name
    );
  end loop;
end;
$$;

do $$
declare table_name text;
begin
  foreach table_name in array array[
    'workspaces','contacts','workspace_contacts','projects','event_series',
    'event_series_contacts','events','event_contacts','task_series','tasks',
    'notes','note_links','timer_sessions','billable_items','reminders','sync_changes'
  ] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('revoke all on public.%I from anon', table_name);
    execute format('revoke delete on public.%I from authenticated', table_name);
    execute format(
      'create policy owner_select on public.%I for select to authenticated '
      'using ((select auth.uid()) = owner_id)', table_name
    );
    if table_name <> 'sync_changes' then
      execute format(
        'create policy owner_insert on public.%I for insert to authenticated '
        'with check ((select auth.uid()) = owner_id)', table_name
      );
      execute format(
        'create policy owner_update on public.%I for update to authenticated '
        'using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id)',
        table_name
      );
    end if;
  end loop;
end;
$$;
grant select, insert, update on public.workspaces, public.contacts,
  public.workspace_contacts, public.projects, public.event_series,
  public.event_series_contacts, public.events, public.event_contacts,
  public.task_series, public.tasks, public.notes, public.note_links,
  public.timer_sessions, public.billable_items, public.reminders to authenticated;
grant select on public.sync_changes to authenticated;

create or replace function public.sync_has_data()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select exists(
    select 1 from public.sync_changes where owner_id = (select auth.uid())
  );
$$;

create or replace function public.sync_pull(
  p_after_version bigint,
  p_limit integer default 500
)
returns table(version bigint, table_name text, row_id uuid, row_data jsonb)
language sql
stable
security invoker
set search_path = ''
as $$
  select c.version, c.table_name, c.row_id, c.row_data
  from public.sync_changes c
  where c.owner_id = (select auth.uid()) and c.version > p_after_version
  order by c.version
  limit least(greatest(p_limit, 1), 1000);
$$;

create or replace function public.sync_push(p_table text, p_rows jsonb)
returns table(id uuid, accepted boolean, version bigint, row_data jsonb)
language plpgsql
security definer
set search_path = ''
as $$
declare
  allowed constant text[] := array[
    'workspaces','contacts','workspace_contacts','projects','event_series',
    'event_series_contacts','events','event_contacts','task_series','tasks',
    'notes','note_links','timer_sessions','billable_items','reminders'
  ];
  uid uuid := auth.uid();
  item jsonb;
  column_names text;
  update_names text;
  changed integer;
begin
  if uid is null then raise exception 'Authentication required'; end if;
  if not (p_table = any(allowed)) then raise exception 'Unsupported sync table'; end if;
  if jsonb_typeof(p_rows) <> 'array' then raise exception 'Rows must be an array'; end if;

  select string_agg(format('%I', a.attname), ', ' order by a.attnum),
         string_agg(format('%1$I = excluded.%1$I', a.attname), ', ' order by a.attnum)
           filter (where a.attname <> 'id')
  into column_names, update_names
  from pg_catalog.pg_attribute a
  join pg_catalog.pg_class c on c.oid = a.attrelid
  join pg_catalog.pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = p_table
    and a.attnum > 0 and not a.attisdropped;

  for item in select value from jsonb_array_elements(p_rows) loop
    item := item || jsonb_build_object('owner_id', uid);
    execute format(
      'insert into public.%1$I (%2$s) '
      'select %2$s from jsonb_populate_record(null::public.%1$I, $1) '
      'on conflict (id) do update set %3$s '
      'where public.%1$I.owner_id = $2 '
      'and excluded.updated_at > public.%1$I.updated_at',
      p_table, column_names, update_names
    ) using item, uid;
    get diagnostics changed = row_count;
    accepted := changed > 0;
    id := (item->>'id')::uuid;
    execute format('select to_jsonb(t) from public.%I t where id = $1 and owner_id = $2', p_table)
      into row_data using id, uid;
    if row_data is null then raise exception 'Row ownership conflict'; end if;
    select c.version into version from public.sync_changes c
      where c.owner_id = uid and c.table_name = p_table and c.row_id = id;
    return next;
  end loop;
end;
$$;

revoke all on function public.sync_has_data() from public;
revoke all on function public.sync_pull(bigint, integer) from public;
revoke all on function public.sync_push(text, jsonb) from public;
grant execute on function public.sync_has_data() to authenticated;
grant execute on function public.sync_pull(bigint, integer) to authenticated;
grant execute on function public.sync_push(text, jsonb) to authenticated;

alter publication supabase_realtime add table public.sync_changes;
