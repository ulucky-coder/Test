-- Atelier Brand Kit Schema
-- Consumers: src/pipeline/runner.ts, apps/portal/*, workflows/n8n/10..12
-- RLS: enabled per table; admin (service-role) bypasses; clients see only their own rows.

create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

-- ============================================================
-- Enums
-- ============================================================

do $$ begin
  create type phase_kind as enum (
    'intake','strategy','research','concepts','logo_system','brand_system',
    'site_design','site_build','qa','guidelines','deploy','handoff'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type phase_status as enum ('pending','in_progress','ready_for_review','approved','revise','blocked');
exception when duplicate_object then null; end $$;

do $$ begin
  create type budget_tier as enum ('standard','premium','flagship');
exception when duplicate_object then null; end $$;

do $$ begin
  create type review_verdict as enum ('approve','revise','reject');
exception when duplicate_object then null; end $$;

do $$ begin
  create type asset_kind as enum (
    'brief','moodboard','concept','logo','variant','favicon','token',
    'site_preview','screenshot','report','guidelines_pdf','social','handoff_zip','other'
  );
exception when duplicate_object then null; end $$;

-- ============================================================
-- Core tables
-- ============================================================

create table if not exists public.clients (
  id           uuid primary key default uuid_generate_v4(),
  slug         text not null unique,
  name         text not null,
  industry     text,
  stage        text,
  budget_tier  budget_tier not null default 'standard',
  owner_user_id uuid,
  status       text not null default 'active',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  metadata     jsonb not null default '{}'::jsonb
);

create index if not exists clients_slug_idx on public.clients (slug);
create index if not exists clients_owner_idx on public.clients (owner_user_id);

create table if not exists public.briefs (
  id          uuid primary key default uuid_generate_v4(),
  client_id   uuid not null references public.clients(id) on delete cascade,
  version     int  not null default 1,
  payload     jsonb not null,
  approved    boolean not null default false,
  created_by  uuid,
  created_at  timestamptz not null default now(),
  unique (client_id, version)
);

create index if not exists briefs_client_idx on public.briefs (client_id);

create table if not exists public.phases (
  id           uuid primary key default uuid_generate_v4(),
  client_id    uuid not null references public.clients(id) on delete cascade,
  kind         phase_kind not null,
  status       phase_status not null default 'pending',
  iteration    int  not null default 0,
  reviewer     uuid,
  approved_at  timestamptz,
  started_at   timestamptz,
  context      jsonb not null default '{}'::jsonb,
  unique (client_id, kind)
);

create index if not exists phases_client_status_idx on public.phases (client_id, status);

create table if not exists public.moodboards (
  id          uuid primary key default uuid_generate_v4(),
  client_id   uuid not null references public.clients(id) on delete cascade,
  slot        int  not null check (slot between 1 and 3),
  name        text not null,
  manifesto   text,
  palette     jsonb not null default '[]'::jsonb,
  type        jsonb not null default '{}'::jsonb,
  motion      jsonb not null default '{}'::jsonb,
  preview_url text,
  selected    boolean not null default false,
  created_at  timestamptz not null default now(),
  unique (client_id, slot)
);

create table if not exists public.concepts (
  id          uuid primary key default uuid_generate_v4(),
  client_id   uuid not null references public.clients(id) on delete cascade,
  slot        int  not null,
  strategy    text not null,           -- 'monogram' | 'abstract_symbol' | 'wordmark'
  svg_url     text not null,
  rationale   text,
  scores      jsonb not null default '{}'::jsonb,
  selected    boolean not null default false,
  created_at  timestamptz not null default now()
);

create index if not exists concepts_client_idx on public.concepts (client_id);

create table if not exists public.tokens (
  id          uuid primary key default uuid_generate_v4(),
  client_id   uuid not null references public.clients(id) on delete cascade,
  version     int  not null default 1,
  payload     jsonb not null,
  css_url     text,
  ts_url      text,
  contrast_report jsonb,
  created_at  timestamptz not null default now(),
  unique (client_id, version)
);

create table if not exists public.assets (
  id          uuid primary key default uuid_generate_v4(),
  client_id   uuid not null references public.clients(id) on delete cascade,
  kind        asset_kind not null,
  bucket      text not null,
  path        text not null,
  mime        text,
  size_bytes  bigint,
  checksum    text,
  phase_id    uuid references public.phases(id) on delete set null,
  metadata    jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);

create index if not exists assets_client_kind_idx on public.assets (client_id, kind);
create index if not exists assets_phase_idx on public.assets (phase_id);

create table if not exists public.reviews (
  id           uuid primary key default uuid_generate_v4(),
  client_id    uuid not null references public.clients(id) on delete cascade,
  phase_id     uuid not null references public.phases(id) on delete cascade,
  reviewer     uuid,
  reviewer_role text not null default 'client',
  verdict      review_verdict not null,
  comments     jsonb not null default '[]'::jsonb,
  rubric       jsonb,
  created_at   timestamptz not null default now()
);

create index if not exists reviews_phase_idx on public.reviews (phase_id);

create table if not exists public.reports (
  id          uuid primary key default uuid_generate_v4(),
  client_id   uuid not null references public.clients(id) on delete cascade,
  kind        text not null,  -- 'lighthouse' | 'axe' | 'visual_regression' | 'design_review' | 'deploy'
  route       text,
  scores      jsonb,
  payload     jsonb,
  created_at  timestamptz not null default now()
);

create index if not exists reports_client_kind_idx on public.reports (client_id, kind);

create table if not exists public.deploys (
  id           uuid primary key default uuid_generate_v4(),
  client_id    uuid not null references public.clients(id) on delete cascade,
  environment  text not null check (environment in ('preview','staging','production')),
  url          text not null,
  provider     text not null,   -- 'vercel' | 'netlify' | 'docker' | 'supabase'
  commit_sha   text,
  version      text,
  released_at  timestamptz not null default now(),
  released_by  uuid,
  status       text not null default 'live'
);

-- ============================================================
-- updated_at triggers
-- ============================================================

create or replace function public.set_updated_at() returns trigger as $$
begin new.updated_at := now(); return new; end;
$$ language plpgsql;

drop trigger if exists trg_clients_updated_at on public.clients;
create trigger trg_clients_updated_at before update on public.clients
  for each row execute function public.set_updated_at();

-- ============================================================
-- Phase advance guard: a phase cannot flip to 'approved' unless its prerequisite is approved.
-- ============================================================

create or replace function public.enforce_phase_order() returns trigger as $$
declare
  prior_kind phase_kind;
  prior_status phase_status;
begin
  if new.status <> 'approved' then return new; end if;

  prior_kind := case new.kind
    when 'strategy'     then 'intake'::phase_kind
    when 'research'     then 'strategy'::phase_kind
    when 'concepts'     then 'research'::phase_kind
    when 'logo_system'  then 'concepts'::phase_kind
    when 'brand_system' then 'logo_system'::phase_kind
    when 'site_design'  then 'brand_system'::phase_kind
    when 'site_build'   then 'site_design'::phase_kind
    when 'qa'           then 'site_build'::phase_kind
    when 'guidelines'   then 'qa'::phase_kind
    when 'deploy'       then 'guidelines'::phase_kind
    when 'handoff'      then 'deploy'::phase_kind
    else null
  end;

  if prior_kind is null then return new; end if;

  select status into prior_status from public.phases
    where client_id = new.client_id and kind = prior_kind;

  if prior_status is distinct from 'approved' then
    raise exception 'phase % cannot be approved while % is %', new.kind, prior_kind, coalesce(prior_status::text, 'missing');
  end if;

  new.approved_at := coalesce(new.approved_at, now());
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_phases_order on public.phases;
create trigger trg_phases_order before update on public.phases
  for each row when (new.status = 'approved' and old.status is distinct from 'approved')
  execute function public.enforce_phase_order();

-- ============================================================
-- RLS
-- ============================================================

alter table public.clients    enable row level security;
alter table public.briefs     enable row level security;
alter table public.phases     enable row level security;
alter table public.moodboards enable row level security;
alter table public.concepts   enable row level security;
alter table public.tokens     enable row level security;
alter table public.assets     enable row level security;
alter table public.reviews    enable row level security;
alter table public.reports    enable row level security;
alter table public.deploys    enable row level security;

-- Clients: owner can select/update; service role bypasses.
drop policy if exists clients_select_own on public.clients;
create policy clients_select_own on public.clients
  for select using (auth.uid() = owner_user_id);

drop policy if exists clients_update_own on public.clients;
create policy clients_update_own on public.clients
  for update using (auth.uid() = owner_user_id);

-- Child tables: row visible if parent client's owner matches.
create or replace function public.is_client_owner(cid uuid) returns boolean as $$
  select exists (
    select 1 from public.clients c where c.id = cid and c.owner_user_id = auth.uid()
  );
$$ language sql stable security definer;

drop policy if exists briefs_select_own on public.briefs;
create policy briefs_select_own on public.briefs
  for select using (public.is_client_owner(client_id));

drop policy if exists phases_select_own on public.phases;
create policy phases_select_own on public.phases
  for select using (public.is_client_owner(client_id));

drop policy if exists phases_update_own on public.phases;
create policy phases_update_own on public.phases
  for update using (public.is_client_owner(client_id));

drop policy if exists moodboards_select_own on public.moodboards;
create policy moodboards_select_own on public.moodboards
  for select using (public.is_client_owner(client_id));

drop policy if exists concepts_select_own on public.concepts;
create policy concepts_select_own on public.concepts
  for select using (public.is_client_owner(client_id));

drop policy if exists tokens_select_own on public.tokens;
create policy tokens_select_own on public.tokens
  for select using (public.is_client_owner(client_id));

drop policy if exists assets_select_own on public.assets;
create policy assets_select_own on public.assets
  for select using (public.is_client_owner(client_id));

drop policy if exists reviews_select_own on public.reviews;
create policy reviews_select_own on public.reviews
  for select using (public.is_client_owner(client_id));

drop policy if exists reviews_insert_own on public.reviews;
create policy reviews_insert_own on public.reviews
  for insert with check (public.is_client_owner(client_id));

drop policy if exists reports_select_own on public.reports;
create policy reports_select_own on public.reports
  for select using (public.is_client_owner(client_id));

drop policy if exists deploys_select_own on public.deploys;
create policy deploys_select_own on public.deploys
  for select using (public.is_client_owner(client_id));

-- ============================================================
-- RPC: atomic phase advance
-- ============================================================

create or replace function public.advance_phase(p_client_id uuid, p_kind phase_kind, p_reviewer uuid)
returns public.phases
language plpgsql
security definer
as $$
declare updated public.phases;
begin
  update public.phases
    set status = 'approved',
        reviewer = p_reviewer,
        approved_at = now()
    where client_id = p_client_id and kind = p_kind
  returning * into updated;

  if not found then raise exception 'phase not found for client % kind %', p_client_id, p_kind; end if;
  return updated;
end;
$$;

-- ============================================================
-- Seed: bootstrap all phases for a new client
-- ============================================================

create or replace function public.bootstrap_phases(p_client_id uuid) returns void as $$
declare k phase_kind;
begin
  for k in select unnest(enum_range(null::phase_kind)) loop
    insert into public.phases(client_id, kind, status)
      values (p_client_id, k, 'pending')
      on conflict (client_id, kind) do nothing;
  end loop;
end;
$$ language plpgsql;
