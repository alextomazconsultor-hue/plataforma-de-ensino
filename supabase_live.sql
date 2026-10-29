-- Execute este arquivo no Supabase: SQL Editor > New query > cole > Run.
-- Configuração da live de mentoria exibida no dashboard da plataforma 3Ps.

create table if not exists public.mentorship_live (
  id integer primary key check (id = 1),
  title text not null default 'Como gerar leads qualificados para imóveis no litoral',
  live_date text not null default 'Quinta-feira',
  live_time text not null default '20h (horário de Brasília)',
  video_url text not null default '',
  updated_at timestamptz not null default now(),
  updated_by text
);

alter table public.mentorship_live enable row level security;

drop policy if exists "Authenticated users can read mentorship live" on public.mentorship_live;
create policy "Authenticated users can read mentorship live"
  on public.mentorship_live for select
  to authenticated
  using (true);

drop policy if exists "Only Alex can insert mentorship live" on public.mentorship_live;
create policy "Only Alex can insert mentorship live"
  on public.mentorship_live for insert
  to authenticated
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'alextomazconsultor@gmail.com');

drop policy if exists "Only Alex can update mentorship live" on public.mentorship_live;
create policy "Only Alex can update mentorship live"
  on public.mentorship_live for update
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'alextomazconsultor@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'alextomazconsultor@gmail.com');

insert into public.mentorship_live (id, title, live_date, live_time, video_url)
values (1, 'Como gerar leads qualificados para imóveis no litoral', 'Quinta-feira', '20h (horário de Brasília)', '')
on conflict (id) do nothing;

grant select, insert, update on public.mentorship_live to authenticated;
