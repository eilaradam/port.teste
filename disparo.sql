-- ============================================================
--  DISPARO DE E-MAIL PARA AS MARCAS
--
--  ONDE COLAR ISTO:
--  1. Abra https://supabase.com e entre no seu projeto
--  2. No menu da esquerda, clique em "SQL Editor"
--  3. Clique em "New query"
--  4. Cole este arquivo inteiro e clique em "Run"
--
--  Pode rodar de novo quantas vezes quiser. Nada aqui apaga
--  tabela, nem coluna, nem dado seu.
-- ============================================================


-- ============================================================
--  PARTE 1 · DUAS COLUNAS NOVAS NA TABELA QUE JÁ EXISTE
--
--  A tabela marcas continua a mesma. Só ganha dois campos.
-- ============================================================

-- Guarda quais marcas você marcou na caixinha da aba Marcas.
-- Fica salvo no banco, então você marca hoje e dispara amanhã.
alter table public.marcas
  add column if not exists selecionada boolean not null default false;

-- A data do último disparo que essa marca recebeu.
-- Fica vazio até você mandar o primeiro e-mail para ela.
alter table public.marcas
  add column if not exists enviado_em date;


-- ============================================================
--  PARTE 2 · O CADERNO DE REGISTRO DOS ENVIOS
--
--  Uma linha por destinatário, sempre. É isso que te salva
--  quando um disparo morre no meio: dá para ver exatamente
--  quem recebeu e quem ficou faltando.
-- ============================================================
create table if not exists public.email_envios (
  id         bigint generated always as identity primary key,
  email      text not null default '',
  assunto    text not null default '',
  status     text not null default 'ok',
  erro       text not null default '',
  resend_id  text not null default '',
  criado_em  timestamptz not null default now(),
  constraint status_envio check (status in ('ok','erro'))
);

-- deixa a busca por e-mail e a lista por data rápidas
create index if not exists email_envios_email_idx on public.email_envios (email);
create index if not exists email_envios_data_idx  on public.email_envios (criado_em desc);


-- ============================================================
--  PARTE 3 · A LISTA DE QUEM PEDIU PARA NÃO RECEBER MAIS
--
--  Quem responder SAIR entra aqui. O carteiro confere esta
--  lista antes de cada envio e pula quem estiver nela, hoje
--  e em todos os disparos daqui para a frente.
-- ============================================================
create table if not exists public.email_optout (
  id         bigint generated always as identity primary key,
  email      text not null unique,
  criado_em  timestamptz not null default now()
);


-- ============================================================
--  PARTE 4 · A TRANCA NAS DUAS TABELAS NOVAS
--
--  Mesma regra do resto do painel: só você, logada, lê e
--  escreve. Quem não fez login não enxerga nada, nem uma linha.
--
--  A função sou_a_dona já foi criada pelo banco.sql e é a
--  mesma usada nas outras tabelas.
-- ============================================================
alter table public.email_envios enable row level security;
alter table public.email_optout enable row level security;

drop policy if exists "dona faz tudo em email_envios" on public.email_envios;
create policy "dona faz tudo em email_envios" on public.email_envios
  for all to authenticated
  using (public.sou_a_dona()) with check (public.sou_a_dona());

drop policy if exists "dona faz tudo em email_optout" on public.email_optout;
create policy "dona faz tudo em email_optout" on public.email_optout
  for all to authenticated
  using (public.sou_a_dona()) with check (public.sou_a_dona());


-- ============================================================
--  PARTE 5 · CONFERINDO
--
--  Rode e veja: as duas tabelas novas precisam aparecer com
--  rls_ligado = true.
-- ============================================================
select tablename as tabela, rowsecurity as rls_ligado
from pg_tables
where schemaname = 'public'
  and tablename in ('email_envios','email_optout')
order by tablename;
