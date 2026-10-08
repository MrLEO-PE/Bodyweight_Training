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

-- Year group of each class or form, e.g. 'Year 10' for form 10C.
-- Classes named like '10C', 'Y10' or 'Year 10' get it filled in automatically.
alter table public.bw_classes add column if not exists year_group text;
update public.bw_classes
   set year_group = 'Year ' || substring(trim(name) from '(?i)^(?:year|yr|y)?\s*(\d{1,2})\s*[a-z]{0,3}$')::int
 where year_group is null and trim(name) ~* '^(year|yr|y)?\s*\d{1,2}\s*[a-z]{0,3}$';

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

-- Workout of the week, set by the teacher for a class
create table if not exists public.bw_plans (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.bw_classes(id) on delete cascade,
  title text not null,
  note text not null default '',
  work_sec int not null,
  rest_sec int not null,
  rounds int not null,
  exercises jsonb not null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.bw_plans add column if not exists due_on date;
alter table public.bw_sessions add column if not exists plan_id uuid references public.bw_plans(id) on delete set null;

-- Team challenges shared by one or more classes
create table if not exists public.bw_challenges (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  metric text not null check (metric in ('workouts', 'reps', 'minutes')),
  target int not null check (target > 0),
  class_ids uuid[] not null,
  starts_on date not null,
  ends_on date not null,
  created_at timestamptz not null default now()
);
-- Whole year groups taking part: every class in that year group counts, including ones added later
alter table public.bw_challenges add column if not exists year_groups text[] not null default '{}';

-- Fitness checks: the teacher opens one per class with a label such as 'Start of Term 1'
alter table public.bw_classes add column if not exists test_label text;
create table if not exists public.bw_tests (
  id uuid primary key default gen_random_uuid(),
  class_id uuid references public.bw_classes(id) on delete cascade,
  student_id uuid references public.bw_students(id) on delete set null,
  student_name text not null,
  label text not null,
  results jsonb not null,
  created_at timestamptz not null default now()
);
create index if not exists bw_tests_class on public.bw_tests (class_id, created_at);

-- Teacher's own demo video links, keyed by exercise ('squat-1' ... 'balance-4')
create table if not exists public.bw_demos (
  exercise_key text primary key,
  url text not null
);

/* ---------- Lock the tables: no direct access from the browser ---------- */

do $$ declare t text; p record; begin
  foreach t in array array['bw_settings','bw_classes','bw_students','bw_sessions','bw_tokens',
                           'bw_plans','bw_challenges','bw_tests','bw_demos'] loop
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

drop function if exists public.bw_list_classes();
create or replace function public.bw_list_classes()
returns table (id uuid, name text, year_group text)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, c.year_group from bw_classes c order by c.name
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
  plan uuid;
begin
  select * into s from bw_students where id = sid;
  select * into c from bw_classes where id = s.class_id;
  select pl.id into plan from bw_plans pl where pl.id::text = p_s ->> 'plan_id' and pl.class_id = c.id;
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
                           exercises, total_reps, total_hold_sec, duration_sec, rpe, created_at, plan_id)
  values (c.id, c.name, s.id, s.name,
          (p_s ->> 'work_sec')::int, (p_s ->> 'rest_sec')::int, (p_s ->> 'rounds')::int, ex,
          coalesce((select sum(least(greatest(v::int, 0), 500)) from jsonb_array_elements(ex) e,
                    jsonb_array_elements_text(e -> 'results') v where e ->> 'unit' = 'reps'), 0),
          coalesce((select sum(least(greatest(v::int, 0), 500)) from jsonb_array_elements(ex) e,
                    jsonb_array_elements_text(e -> 'results') v where e ->> 'unit' = 'sec'), 0),
          least(greatest(coalesce((p_s ->> 'duration_sec')::int, 0), 0), 7200),
          (p_s ->> 'rpe')::int, done_at, plan)
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

create or replace function public.bw__year(v text) returns text
language sql immutable as $$
  select nullif(left(regexp_replace(trim(coalesce(v, '')), '\s+', ' ', 'g'), 40), '')
$$;

drop function if exists public.bw_t_classes(text);
create or replace function public.bw_t_classes(p_token text)
returns table (id uuid, name text, code text, weekly_goal int, year_group text, students bigint, workouts bigint)
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  return query
    select c.id, c.name, c.code, c.weekly_goal, c.year_group,
           (select count(*) from bw_students s where s.class_id = c.id),
           (select count(*) from bw_sessions x where x.class_id = c.id)
      from bw_classes c order by c.name;
end $$;

drop function if exists public.bw_t_add_class(text, text, text, int);
create or replace function public.bw_t_add_class(p_token text, p_name text, p_code text, p_goal int, p_year text)
returns uuid
language plpgsql security definer set search_path = public, extensions as $$
declare new_id uuid;
begin
  perform bw__teacher(p_token);
  if length(trim(coalesce(p_name, ''))) = 0 or length(trim(coalesce(p_code, ''))) < 3 then
    raise exception 'Enter a class name and a class code of at least 3 characters.';
  end if;
  insert into bw_classes (name, code, weekly_goal, year_group)
  values (left(trim(p_name), 60), trim(p_code), least(greatest(coalesce(p_goal, 3), 1), 7), bw__year(p_year))
  returning bw_classes.id into new_id;
  return new_id;
end $$;

drop function if exists public.bw_t_update_class(text, uuid, text, int);
create or replace function public.bw_t_update_class(p_token text, p_id uuid, p_name text, p_code text, p_goal int, p_year text)
returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  if length(trim(coalesce(p_name, ''))) = 0 then raise exception 'The class needs a name.'; end if;
  if length(trim(coalesce(p_code, ''))) < 3 then raise exception 'The class code needs at least 3 characters.'; end if;
  update bw_classes
     set name = left(trim(p_name), 60), code = trim(p_code),
         weekly_goal = least(greatest(coalesce(p_goal, 3), 1), 7), year_group = bw__year(p_year)
   where id = p_id;
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

-- Every student in every class, so an import can find students who are already in another class
create or replace function public.bw_t_all_students(p_token text)
returns table (id uuid, name text, class_id uuid)
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  return query select s.id, s.name, s.class_id from bw_students s;
end $$;

-- Move students to another class (for example from 'Year 10' into their form 10C).
-- Their PIN, workouts and fitness checks go with them. A student whose name is already
-- in the target class is left where they are.
create or replace function public.bw_t_move_students(p_token text, p_to uuid, p_ids uuid[]) returns int
language plpgsql security definer set search_path = public, extensions as $$
declare cname text; moved uuid[];
begin
  perform bw__teacher(p_token);
  select k.name into cname from bw_classes k where k.id = p_to;
  if cname is null then raise exception 'Class not found.'; end if;
  with mv as (
    update bw_students s set class_id = p_to
     where s.id = any(coalesce(p_ids, '{}')) and s.class_id <> p_to
       and not exists (select 1 from bw_students t where t.class_id = p_to and lower(t.name) = lower(s.name))
    returning s.id)
  select coalesce(array_agg(mv.id), '{}') into moved from mv;
  update bw_sessions set class_id = p_to, class_name = cname where student_id = any(moved);
  update bw_tests set class_id = p_to where student_id = any(moved);
  return cardinality(moved);
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

/* ---------- Workout of the week, challenges, fitness checks, demo videos ---------- */

create or replace function public.bw__clamp(v jsonb, mx int) returns int
language sql immutable as $$
  select case when jsonb_typeof(v) = 'number' then least(greatest(round((v #>> '{}')::numeric)::int, 0), mx) end
$$;

create or replace function public.bw__plan(p_class_id uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select to_jsonb(p) - 'active' from bw_plans p
   where p.class_id = p_class_id and p.active order by p.created_at desc limit 1
$$;

-- Is a class part of a challenge? Either chosen directly, or its whole year group was chosen.
create or replace function public.bw__in_challenge(ch bw_challenges, k bw_classes) returns boolean
language sql immutable as $$
  select k.id = any(ch.class_ids)
      or lower(k.year_group) in (select lower(y) from unnest(ch.year_groups) y)
$$;

create or replace function public.bw__challenge(ch bw_challenges) returns jsonb
language sql stable security definer set search_path = public as $$
  with per as (
    select k.id, k.name,
           coalesce((select case ch.metric when 'workouts' then count(*)
                                           when 'reps' then sum(x.total_reps)
                                           else sum(x.duration_sec) / 60 end
                       from bw_sessions x
                      where x.class_id = k.id
                        and x.created_at >= ch.starts_on and x.created_at < ch.ends_on + 1), 0) as n
      from bw_classes k where bw__in_challenge(ch, k)
  )
  select jsonb_build_object(
    'id', ch.id, 'title', ch.title, 'metric', ch.metric, 'target', ch.target,
    'starts_on', ch.starts_on, 'ends_on', ch.ends_on,
    'class_ids', to_jsonb(ch.class_ids), 'year_groups', to_jsonb(ch.year_groups),
    'classes', coalesce((select jsonb_agg(per.name order by per.name) from per), '[]'::jsonb),
    'by_class', coalesce((select jsonb_agg(jsonb_build_object('id', per.id, 'name', per.name, 'progress', per.n) order by per.name) from per), '[]'::jsonb),
    'progress', coalesce((select sum(per.n) from per), 0))
$$;

create or replace function public.bw_student_extras(p_token text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare sid uuid := bw__student(p_token); c bw_classes;
begin
  select k.* into c from bw_classes k join bw_students s on s.class_id = k.id where s.id = sid;
  return jsonb_build_object(
    'plan', bw__plan(c.id),
    'test_label', c.test_label,
    'tests', coalesce((select jsonb_agg(to_jsonb(t) - 'student_id' - 'class_id' order by t.created_at)
                         from bw_tests t where t.student_id = sid), '[]'::jsonb),
    'challenges', coalesce((select jsonb_agg(bw__challenge(ch) order by ch.ends_on)
                              from bw_challenges ch
                             where bw__in_challenge(ch, c) and ch.starts_on <= current_date
                               and ch.ends_on >= current_date - 14), '[]'::jsonb));
end $$;

-- Class leaderboard for a student. Points: 1 rep = 1 point, 1 second held = 1 point.
-- 'plan': best score per student on the class's current challenge workout.
-- 'week': all points since Monday.
create or replace function public.bw_class_board(p_token text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare sid uuid := bw__student(p_token); cid uuid; pl uuid; wk timestamptz := date_trunc('week', now());
begin
  select s.class_id into cid from bw_students s where s.id = sid;
  select p.id into pl from bw_plans p where p.class_id = cid and p.active order by p.created_at desc limit 1;
  return jsonb_build_object(
    'class_size', (select count(*) from bw_students s where s.class_id = cid),
    'plan', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'points', x.pts) order by x.pts desc, s.name)
                        from bw_students s
                        join (select student_id, max(total_reps + total_hold_sec) as pts from bw_sessions
                               where pl is not null and plan_id = pl group by student_id) x on x.student_id = s.id
                       where s.class_id = cid), '[]'::jsonb),
    'week', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'points', x.pts, 'workouts', x.n) order by x.pts desc, s.name)
                        from bw_students s
                        join (select student_id, sum(total_reps + total_hold_sec) as pts, count(*) as n from bw_sessions
                               where class_id = cid and created_at >= wk group by student_id) x on x.student_id = s.id
                       where s.class_id = cid), '[]'::jsonb));
end $$;

create or replace function public.bw_add_test(p_token text, p_r jsonb)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare sid uuid := bw__student(p_token); s bw_students; c bw_classes;
begin
  select * into s from bw_students where id = sid;
  select * into c from bw_classes where id = s.class_id;
  if c.test_label is null then
    return jsonb_build_object('error', 'There is no fitness check open right now.');
  end if;
  insert into bw_tests (class_id, student_id, student_name, label, results)
  values (c.id, s.id, s.name, c.test_label, jsonb_build_object(
    'squat', bw__clamp(p_r -> 'squat', 200),
    'pushup', bw__clamp(p_r -> 'pushup', 200),
    'pushup_type', case when p_r ->> 'pushup_type' = 'knee' then 'knee' else 'full' end,
    'plank', bw__clamp(p_r -> 'plank', 600),
    'wallsit', bw__clamp(p_r -> 'wallsit', 600),
    'jacks', bw__clamp(p_r -> 'jacks', 300)));
  return jsonb_build_object('ok', true);
end $$;

create or replace function public.bw_list_demos()
returns table (exercise_key text, url text)
language sql stable security definer set search_path = public as $$
  select d.exercise_key, d.url from bw_demos d
$$;

create or replace function public.bw_t_set_demo(p_token text, p_key text, p_url text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  if coalesce(p_key, '') !~ '^[a-z]+-[1-4]$' then raise exception 'Unknown exercise.'; end if;
  if length(trim(coalesce(p_url, ''))) = 0 then
    delete from bw_demos where exercise_key = p_key;
    return;
  end if;
  if trim(p_url) !~* '^https://' or length(p_url) > 500 then
    raise exception 'The link must start with https://';
  end if;
  insert into bw_demos (exercise_key, url) values (p_key, trim(p_url))
  on conflict (exercise_key) do update set url = excluded.url;
end $$;

create or replace function public.bw_t_set_plan(p_token text, p_class_id uuid, p_plan jsonb) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare ex jsonb := p_plan -> 'exercises';
begin
  perform bw__teacher(p_token);
  if jsonb_typeof(ex) is distinct from 'array' or jsonb_array_length(ex) not between 1 and 12
     or length(trim(coalesce(p_plan ->> 'title', ''))) = 0
     or coalesce((p_plan ->> 'rounds')::int, 0) not between 1 and 3
     or coalesce((p_plan ->> 'work_sec')::int, 0) not between 10 and 120
     or coalesce((p_plan ->> 'rest_sec')::int, -1) not between 0 and 120 then
    raise exception 'This workout is not valid.';
  end if;
  update bw_plans set active = false where class_id = p_class_id and active;
  insert into bw_plans (class_id, title, note, work_sec, rest_sec, rounds, exercises, due_on)
  values (p_class_id, left(trim(p_plan ->> 'title'), 80), left(coalesce(p_plan ->> 'note', ''), 500),
          (p_plan ->> 'work_sec')::int, (p_plan ->> 'rest_sec')::int, (p_plan ->> 'rounds')::int, ex,
          nullif(p_plan ->> 'due_on', '')::date);
end $$;

create or replace function public.bw_t_clear_plan(p_token text, p_class_id uuid) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  update bw_plans set active = false where class_id = p_class_id and active;
end $$;

create or replace function public.bw_t_class_extras(p_token text, p_class_id uuid)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  return jsonb_build_object(
    'plan', bw__plan(p_class_id),
    'test_label', (select k.test_label from bw_classes k where k.id = p_class_id),
    'tests', coalesce((select jsonb_agg(to_jsonb(t) order by t.created_at)
                         from bw_tests t where t.class_id = p_class_id), '[]'::jsonb));
end $$;

create or replace function public.bw_t_set_test_label(p_token text, p_class_id uuid, p_label text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  update bw_classes set test_label = nullif(left(trim(coalesce(p_label, '')), 60), '') where id = p_class_id;
end $$;

create or replace function public.bw_t_challenges(p_token text)
returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  return coalesce((select jsonb_agg(bw__challenge(ch) order by ch.ends_on desc) from bw_challenges ch), '[]'::jsonb);
end $$;

create or replace function public.bw_t_add_challenge(p_token text, p_c jsonb) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare ids uuid[]; yrs text[];
begin
  perform bw__teacher(p_token);
  select coalesce(array_agg(k.id), '{}') into ids from bw_classes k
   where k.id::text in (select jsonb_array_elements_text(coalesce(p_c -> 'class_ids', '[]'::jsonb)));
  select coalesce(array_agg(distinct bw__year(y)), '{}') into yrs
    from jsonb_array_elements_text(coalesce(p_c -> 'year_groups', '[]'::jsonb)) y where bw__year(y) is not null;
  if length(trim(coalesce(p_c ->> 'title', ''))) = 0 then raise exception 'Give the challenge a title.'; end if;
  if cardinality(ids) = 0 and cardinality(yrs) = 0 then raise exception 'Choose at least one year group or class.'; end if;
  if coalesce(p_c ->> 'metric', '') not in ('workouts', 'reps', 'minutes') then raise exception 'Choose what to count.'; end if;
  if coalesce((p_c ->> 'target')::int, 0) < 1 then raise exception 'Set a target above 0.'; end if;
  if (p_c ->> 'starts_on') is null or (p_c ->> 'ends_on') is null
     or (p_c ->> 'ends_on')::date < (p_c ->> 'starts_on')::date then
    raise exception 'The end date must be on or after the start date.';
  end if;
  insert into bw_challenges (title, metric, target, class_ids, year_groups, starts_on, ends_on)
  values (left(trim(p_c ->> 'title'), 100), p_c ->> 'metric', (p_c ->> 'target')::int, ids, yrs,
          (p_c ->> 'starts_on')::date, (p_c ->> 'ends_on')::date);
end $$;

create or replace function public.bw_t_delete_challenge(p_token text, p_id uuid) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform bw__teacher(p_token);
  delete from bw_challenges where id = p_id;
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
