-- Bodyweight Builder: Supabase setup
-- Run this whole file once in Supabase > SQL Editor. It is safe to run again.
-- It also upgrades tables created by an older version of the app (plain-text PINs, open policies).
--
-- Security model: the browser never reads or writes the tables directly.
-- Row level security is on with no policies, so the public anon key can only call
-- the bw_* functions below. Each function checks a class code, a PIN or a login token.

create extension if not exists pgcrypto with schema extensions;

/* ---------- Tables ---------- */

create table if not exists public.bw_settings (
  id int primary key default 1 check (id = 1),
  teacher_pin_hash text not null,
  failed_attempts int not null default 0,
  locked_until timestamptz
);
-- Initial teacher PIN: change-me-now  (change it from the teacher screen after first login)
insert into public.bw_settings (id, teacher_pin_hash)
values (1, extensions.crypt('change-me-now', extensions.gen_salt('bf')))
on conflict (id) do nothing;

create table if not exists public.bw_classes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null,
  weekly_goal int not null default 3,
  created_at timestamptz not null default now()
);
alter table public.bw_classes add column if not exists weekly_goal int not null default 3;
alter table public.bw_classes add column if not exists created_at timestamptz not null default now();

create table if not exists public.bw_students (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.bw_classes(id) on delete cascade,
  name text not null,
  pin_hash text,
  failed_attempts int not null default 0,
  locked_until timestamptz,
  created_at timestamptz not null default now()
);
alter table public.bw_students add column if not exists pin_hash text;
alter table public.bw_students add column if not exists failed_attempts int not null default 0;
alter table public.bw_students add column if not exists locked_until timestamptz;
alter table public.bw_students add column if not exists created_at timestamptz not null default now();

-- Upgrade: hash any plain-text PINs left by the older app, then drop that column.
do $$ begin
  if exists (select 1 from information_schema.columns
             where table_schema = 'public' and table_name = 'bw_students' and column_name = 'pin') then
    execute 'update public.bw_students set pin_hash = extensions.crypt(pin, extensions.gen_salt(''bf'')) where pin is not null and pin_hash is null';
    execute 'alter table public.bw_students drop column pin';
  end if;
end $$;

create unique index if not exists bw_students_class_name on public.bw_students (class_id, lower(name));

create table if not exists public.bw_sessions (
  id uuid primary key default gen_random_uuid(),
  class_id uuid references public.bw_classes(id) on delete cascade,
  class_name text not null,
  student_id uuid references public.bw_students(id) on delete set null,
  student_name text not null,
  work_sec int not null,
  rest_sec int not null,
  rounds int not null,
  exercises jsonb not null,
  total_reps int not null default 0,
  total_hold_sec int not null default 0,
  duration_sec int not null default 0,
  rpe int not null,
  created_at timestamptz not null default now()
);
create index if not exists bw_sessions_class on public.bw_sessions (class_id, created_at desc);
create index if not exists bw_sessions_student on public.bw_sessions (student_id, created_at desc);

create table if not exists public.bw_tokens (
  token_hash text primary key,
  role text not null check (role in ('teacher', 'student')),
  student_id uuid references public.bw_students(id) on delete cascade,
  expires_at timestamptz not null
);

/* ---------- Lock the tables: no direct access from the browser ---------- */

do $$ declare t text; p record; begin
  foreach t in array array['bw_settings','bw_classes','bw_students','bw_sessions','bw_tokens'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('revoke all on table public.%I from anon, authenticated', t);
    for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
  end loop;
end $$;

/* ---------- Internal helpers (not callable from the browser) ---------- */

create or replace function public.bw__hash(t text) returns text
language sql immutable set search_path = public, extensions as $$
  select encode(extensions.digest(t, 'sha256'), 'hex')
$$;

create or replace function public.bw__new_token(p_role text, p_student uuid, p_ttl interval) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare t text := encode(extensions.gen_random_bytes(32), 'hex');
begin
  delete from bw_tokens where expires_at < now();
  insert into bw_tokens (token_hash, role, student_id, expires_at) values (bw__hash(t), p_role, p_student, now() + p_ttl);
  return t;
end $$;

create or replace function public.bw__teacher(p_token text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not exists (select 1 from bw_tokens k where k.token_hash = bw__hash(coalesce(p_token, ''))
                 and k.role = 'teacher' and k.expires_at > now()) then
    raise exception 'Your teacher session has expired. Please log in again.';
  end if;
end $$;

create or replace function public.bw__student(p_token text) returns uuid
language plpgsql security definer set search_path = public, extensions as $$
declare sid uuid;
begin
  select k.student_id into sid from bw_tokens k
   where k.token_hash = bw__hash(coalesce(p_token, '')) and k.role = 'student' and k.expires_at > now();
  if sid is null then raise exception 'Your session has expired. Please log in again.'; end if;
  return sid;
end $$;

/* ---------- Student functions ---------- */

create or replace function public.bw_list_classes()
returns table (id uuid, name text)
language sql stable security definer set search_path = public as $$
  select c.id, c.name from bw_classes c order by c.name
$$;

create or replace function public.bw_list_students(p_class_id uuid, p_code text)
returns table (id uuid, name text, has_pin boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from bw_classes c where c.id = p_class_id
                 and lower(trim(c.code)) = lower(trim(coalesce(p_code, '')))) then
    raise exception 'That class code is not right. Check with your teacher.';
  end if;
  return query select s.id, s.name, s.pin_hash is not null from bw_students s
                where s.class_id = p_class_id order by s.name;
end $$;

create or replace function public.bw_student_login(p_student_id uuid, p_code text, p_pin text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare s bw_students; c bw_classes;
begin
  select * into s from bw_students where id = p_student_id;
  if not found then return jsonb_build_object('error', 'Name not found. Ask your teacher.'); end if;
  select * into c from bw_classes where id = s.class_id;
  if lower(trim(c.code)) <> lower(trim(coalesce(p_code, ''))) then
    return jsonb_build_object('error', 'That class code is not right. Check with your teacher.');
  end if;
  if coalesce(p_pin, '') !~ '^[0-9]{4}$' then
    return jsonb_build_object('error', 'Your PIN must be 4 digits.');
  end if;
  if s.locked_until > now() then
    return jsonb_build_object('error', 'Too many wrong PINs. Wait 10 minutes or ask your teacher to reset it.');
  end if;
  if s.pin_hash is null then
    update bw_students set pin_hash = crypt(p_pin, gen_salt('bf')), failed_attempts = 0, locked_until = null where id = s.id;
  elsif s.pin_hash <> crypt(p_pin, s.pin_hash) then
    update bw_students
       set failed_attempts = case when failed_attempts >= 4 then 0 else failed_attempts + 1 end,
           locked_until    = case when failed_attempts >= 4 then now() + interval '10 minutes' end
     where id = s.id;
    return jsonb_build_object('error', 'Wrong PIN. Ask your teacher to reset it if you forgot.');
  else
    update bw_students set failed_attempts = 0, locked_until = null where id = s.id;
  end if;
  return jsonb_build_object(
    'token', bw__new_token('student', s.id, interval '30 days'),
    'student', jsonb_build_object('id', s.id, 'name', s.name),
    'cls', jsonb_build_object('id', c.id, 'name', c.name, 'weekly_goal', c.weekly_goal));
end $$;

create or replace function public.bw_student_me(p_token text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare sid uuid := bw__student(p_token); s bw_students; c bw_classes;
begin
  select * into s from bw_students where id = sid;
  select * into c from bw_classes where id = s.class_id;
  return jsonb_build_object(
    'student', jsonb_build_object('id', s.id, 'name', s.name),
    'cls', jsonb_build_object('id', c.id, 'name', c.name, 'weekly_goal', c.weekly_goal));
end $$;

create or replace function public.bw_logout(p_token text) returns void
language sql security definer set search_path = public, extensions as $$
  delete from bw_tokens where token_hash = bw__hash(coalesce(p_token, ''))
$$;

create or replace function public.bw_my_sessions(p_token text)
returns setof bw_sessions
language plpgsql security definer set search_path = public, extensions as $$
declare sid uuid := bw__student(p_token);
begin
  return query select * from bw_sessions where student_id = sid order by created_at desc;
end $$;

create or replace function public.bw_add_session(p_token text, p_s jsonb)
returns bw_sessions
language plpgsql security definer set search_path = public, extensions as $$
declare
  sid uuid := bw__student(p_token);
  s bw_students; c bw_classes; r bw_sessions;
  ex jsonb := p_s -> 'exercises';
  done_at timestamptz := now();
begin
  select * into s from bw_students where id = sid;
  select * into c from bw_classes where id = s.class_id;
  if jsonb_typeof(ex) is distinct from 'array' or jsonb_array_length(ex) not between 1 and 12 then
    raise exception 'This workout is not valid.';
  end if;
  if coalesce((p_s ->> 'rpe')::int, 0) not between 1 and 10
     or coalesce((p_s ->> 'rounds')::int, 0) not between 1 and 3
     or coalesce((p_s ->> 'work_sec')::int, 0) not between 10 and 120
     or coalesce((p_s ->> 'rest_sec')::int, -1) not between 0 and 120 then
    raise exception 'This workout is not valid.';
  end if;
  -- Workouts saved offline are uploaded later with the time they were done (up to 14 days back).
  if p_s ? 'done_at' then
    begin
      done_at := (p_s ->> 'done_at')::timestamptz;
      if done_at > now() or done_at < now() - interval '14 days' then done_at := now(); end if;
    exception when others then done_at := now();
    end;
  end if;
  insert into bw_sessions (class_id, class_name, student_id, student_name, work_sec, rest_sec, rounds,
                           exercises, total_reps, total_hold_sec, duration_sec, rpe, created_at)
  values (c.id, c.name, s.id, s.name,
          (p_s ->> 'work_sec')::int, (p_s ->> 'rest_sec')::int, (p_s ->> 'rounds')::int, ex,
          coalesce((select sum(least(greatest(v::int, 0), 500)) from jsonb_array_elements(ex) e,
                    jsonb_array_elements_text(e -> 'results') v where e ->> 'unit' = 'reps'), 0),
          coalesce((select sum(least(greatest(v::int, 0), 500)) from jsonb_array_elements(ex) e,
                    jsonb_array_elements_text(e -> 'results') v where e ->> 'unit' = 'sec'), 0),
          least(greatest(coalesce((p_s ->> 'duration_sec')::int, 0), 0), 7200),
          (p_s ->> 'rpe')::int, done_at)
  returning * into r;
  return r;
end $$;

/* ---------- Teacher functions ---------- */

create or replace function public.bw_teacher_login(p_pin text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare st bw_settings;
begin
  select * into st from bw_settings where id = 1 for update;
  if st.locked_until > now() then
    return jsonb_build_object('error', 'Too many wrong attempts. Try again in 15 minutes.');
  end if;
  if st.teacher_pin_hash <> crypt(coalesce(p_pin, ''), st.teacher_pin_hash) then
    update bw_settings
       set failed_attempts = case when failed_attempts >= 9 then 0 else failed_attempts + 1 end,
           locked_until    = case when failed_attempts >= 9 then now() + interval '15 minutes' end
     where id = 1;
    return jsonb_build_object('error', 'Wrong teacher PIN.');
  end if;
  update bw_settings set failed_attempts = 0, locked_until = null where id = 1;
  return jsonb_build_object('token', bw__new_token('teacher', null, interval '12 hours'));
end $$;

create or replace function public.bw_t_change_pin(p_token text, p_old text, p_new text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare st bw_settings;
begin
  perform bw__teacher(p_token);
  select * into st from bw_settings where id = 1;
  if st.teacher_pin_hash <> crypt(coalesce(p_old, ''), st.teacher_pin_hash) then
    return jsonb_build_object('error', 'Your current PIN is not right.');
  end if;
  if length(coalesce(p_new, '')) < 6 then
    return jsonb_build_object('error', 'The new PIN must be at least 6 characters.');
  end if;
  update bw_settings set teacher_pin_hash = crypt(p_new, gen_salt('bf')) where id = 1;
  delete from bw_tokens where role = 'teacher' and token_hash <> bw__hash(p_token);
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.bw_t_classes(p_token text)
returns table (id uuid, name text, code text, weekly_goal int, students bigint, workouts bigint)
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  return query
    select c.id, c.name, c.code, c.weekly_goal,
           (select count(*) from bw_students s where s.class_id = c.id),
           (select count(*) from bw_sessions x where x.class_id = c.id)
      from bw_classes c order by c.name;
end $$;

create or replace function public.bw_t_add_class(p_token text, p_name text, p_code text, p_goal int)
returns uuid
language plpgsql security definer set search_path = public, extensions as $$
declare new_id uuid;
begin
  perform bw__teacher(p_token);
  if length(trim(coalesce(p_name, ''))) = 0 or length(trim(coalesce(p_code, ''))) < 3 then
    raise exception 'Enter a class name and a class code of at least 3 characters.';
  end if;
  insert into bw_classes (name, code, weekly_goal)
  values (trim(p_name), trim(p_code), least(greatest(coalesce(p_goal, 3), 1), 7))
  returning bw_classes.id into new_id;
  return new_id;
end $$;

create or replace function public.bw_t_update_class(p_token text, p_id uuid, p_code text, p_goal int)
returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  if length(trim(coalesce(p_code, ''))) < 3 then raise exception 'The class code needs at least 3 characters.'; end if;
  update bw_classes set code = trim(p_code), weekly_goal = least(greatest(coalesce(p_goal, 3), 1), 7) where id = p_id;
end $$;

create or replace function public.bw_t_delete_class(p_token text, p_id uuid) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  delete from bw_classes where id = p_id;
end $$;

create or replace function public.bw_t_students(p_token text, p_class_id uuid)
returns table (id uuid, name text, has_pin boolean)
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  return query select s.id, s.name, s.pin_hash is not null from bw_students s
                where s.class_id = p_class_id order by s.name;
end $$;

create or replace function public.bw_t_add_students(p_token text, p_class_id uuid, p_names text[])
returns int
language plpgsql security definer set search_path = public, extensions as $$
declare n int;
begin
  perform bw__teacher(p_token);
  with ins as (
    insert into bw_students (class_id, name)
    select p_class_id, d.nm from (
      select distinct on (lower(trim(x))) left(trim(x), 80) as nm from unnest(p_names) x where trim(x) <> ''
    ) d
    on conflict do nothing
    returning 1)
  select count(*) into n from ins;
  return n;
end $$;

create or replace function public.bw_t_reset_pin(p_token text, p_student_id uuid) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  update bw_students set pin_hash = null, failed_attempts = 0, locked_until = null where id = p_student_id;
  delete from bw_tokens where student_id = p_student_id;
end $$;

create or replace function public.bw_t_remove_student(p_token text, p_student_id uuid) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  delete from bw_students where id = p_student_id;
end $$;

create or replace function public.bw_t_sessions(p_token text, p_class_id uuid)
returns setof bw_sessions
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  return query select * from bw_sessions where class_id = p_class_id order by created_at desc;
end $$;

/* ---------- Permissions: helpers are private, bw_* functions are public ---------- */

do $$ declare f record; begin
  for f in select p.oid::regprocedure as sig, p.proname from pg_proc p
           join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname like 'bw\_%' loop
    if f.proname like 'bw\_\_%' then
      execute format('revoke all on function %s from public, anon, authenticated', f.sig);
    else
      execute format('grant execute on function %s to anon, authenticated', f.sig);
    end if;
  end loop;
end $$;

-- Make the Supabase API see the new functions straight away.
notify pgrst, 'reload schema';
