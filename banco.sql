-- ============================================================
--  BANCO DE DADOS DO ADMIN DA LARA DAMASCENO
--
--  ONDE COLAR ISTO AQUI:
--  1. Entre em https://supabase.com e abra o seu projeto
--  2. No menu da esquerda, clique em "SQL Editor"
--  3. Clique em "New query"
--  4. Cole este arquivo inteiro, do começo ao fim
--  5. Clique no botão "Run" (ou aperte Ctrl+Enter)
--  6. Deve aparecer "Success. No rows returned"
--
--  Pode rodar de novo quantas vezes quiser: o arquivo foi
--  escrito para não duplicar nada e não apagar nada seu.
-- ============================================================


-- ============================================================
--  PARTE 1 · AS TABELAS
--  Cada tabela é uma "planilha" dentro do banco.
-- ============================================================

-- Os vídeos que aparecem no portfólio.
-- visivel = false some do site sem apagar do banco (o olhinho do admin).
create table if not exists public.videos (
  id         bigint generated always as identity primary key,
  titulo     text    not null default '',
  link       text    not null default '',
  nicho      text    not null default '',
  formato    text    not null default '',
  marca      text    not null default '',
  destaque   text    not null default '',
  ordem      integer not null default 0,
  visivel    boolean not null default true,
  criado_em  timestamptz not null default now()
);

-- A sua base de contatos de empresa.
-- situacao só aceita estas quatro palavras, para não virar bagunça.
create table if not exists public.marcas (
  id              bigint generated always as identity primary key,
  nome            text not null default '',
  instagram       text not null default '',
  email           text not null default '',
  telefone        text not null default '',
  situacao        text not null default 'lead',
  obs             text not null default '',
  ultimo_contato  date,
  criado_em       timestamptz not null default now(),
  constraint situacao_valida check (situacao in ('lead','conversando','cliente','parada'))
);

-- A sua agenda: o que gravar, editar e postar em cada dia.
create table if not exists public.calendario (
  id         bigint generated always as identity primary key,
  titulo     text not null default '',
  marca      text not null default '',
  tipo       text not null default 'gravar',
  data       date not null default current_date,
  status     text not null default 'a fazer',
  criado_em  timestamptz not null default now(),
  constraint tipo_valido   check (tipo   in ('gravar','editar','postar')),
  constraint status_valido check (status in ('a fazer','feito'))
);

-- Os trabalhos fechados, com valor, prazo e pagamento.
create table if not exists public.campanhas (
  id         bigint generated always as identity primary key,
  campanha   text not null default '',
  cliente    text not null default '',
  tipo       text not null default 'Conteúdo',
  status     text not null default 'Briefing',
  qtd        integer not null default 1,
  valor      numeric(12,2) not null default 0,
  prazo      date,
  pagamento  text not null default 'pendente',
  ativa      boolean not null default true,
  favorita   boolean not null default false,
  criado_em  timestamptz not null default now(),
  constraint tipo_campanha check (tipo in ('Conteúdo','Publicidade')),
  constraint status_campanha check (status in
    ('Briefing','Roteiro','Aprovação Roteiro','Gravação','Edição','Aprovado','Entregue')),
  constraint pagamento_valido check (pagamento in ('pendente','pago'))
);

-- O que você já marcou no checklist do portfólio.
-- A chave é um texto tipo "capa-0", que diz qual item foi marcado.
create table if not exists public.marcados (
  chave      text primary key,
  marcado    boolean not null default true,
  criado_em  timestamptz not null default now()
);

-- Uma linha por visita no portfólio. Sem nome, sem e-mail,
-- sem cookie: só a data, a página e de onde a pessoa veio.
create table if not exists public.visitas (
  id         bigint generated always as identity primary key,
  data       date not null default current_date,
  pagina     text not null default '',
  origem     text not null default 'direto',
  criado_em  timestamptz not null default now()
);

-- Índices, só para as listas continuarem rápidas quando crescerem.
create index if not exists videos_ordem_idx   on public.videos (ordem);
create index if not exists visitas_data_idx   on public.visitas (data);
create index if not exists campanhas_prazo_idx on public.campanhas (prazo);
create index if not exists calendario_data_idx on public.calendario (data);


-- ============================================================
--  PARTE 2 · QUEM É A DONA
--
--  Esta função responde sim ou não para a pergunta:
--  "quem está pedindo estes dados é a Lara?"
--  Ela olha o e-mail de quem fez login.
--
--  SE VOCÊ TROCAR DE E-MAIL um dia, mude só a linha de baixo
--  e rode este arquivo de novo.
-- ============================================================
create or replace function public.sou_a_dona()
returns boolean
language sql
stable
set search_path = public
as $funcao$
  select coalesce(lower(auth.jwt() ->> 'email') = lower('laradam.ugc@gmail.com'), false);
$funcao$;


-- ============================================================
--  PARTE 3 · A TRANCA (RLS)
--
--  Ligar o RLS é como trancar a porta de cada tabela.
--  Depois disso, NINGUÉM entra, a não ser quem tiver uma
--  permissão escrita na Parte 4.
-- ============================================================
alter table public.videos     enable row level security;
alter table public.marcas     enable row level security;
alter table public.calendario enable row level security;
alter table public.campanhas  enable row level security;
alter table public.marcados   enable row level security;
alter table public.visitas    enable row level security;


-- ============================================================
--  PARTE 4 · AS PERMISSÕES
--
--  Regra geral: a dona logada faz tudo, em todas as tabelas.
--  Quem não fez login não lê nada. As exceções estão no fim,
--  cada uma explicada.
-- ============================================================

-- ---- a dona faz tudo ----
drop policy if exists "dona faz tudo em videos" on public.videos;
create policy "dona faz tudo em videos" on public.videos
  for all to authenticated
  using (public.sou_a_dona()) with check (public.sou_a_dona());

drop policy if exists "dona faz tudo em marcas" on public.marcas;
create policy "dona faz tudo em marcas" on public.marcas
  for all to authenticated
  using (public.sou_a_dona()) with check (public.sou_a_dona());

drop policy if exists "dona faz tudo em calendario" on public.calendario;
create policy "dona faz tudo em calendario" on public.calendario
  for all to authenticated
  using (public.sou_a_dona()) with check (public.sou_a_dona());

drop policy if exists "dona faz tudo em campanhas" on public.campanhas;
create policy "dona faz tudo em campanhas" on public.campanhas
  for all to authenticated
  using (public.sou_a_dona()) with check (public.sou_a_dona());

drop policy if exists "dona faz tudo em marcados" on public.marcados;
create policy "dona faz tudo em marcados" on public.marcados
  for all to authenticated
  using (public.sou_a_dona()) with check (public.sou_a_dona());

drop policy if exists "dona faz tudo em visitas" on public.visitas;
create policy "dona faz tudo em visitas" on public.visitas
  for all to authenticated
  using (public.sou_a_dona()) with check (public.sou_a_dona());


-- ---- EXCEÇÃO 1 · o formulário do site cadastra lead ----
-- Qualquer visitante pode CRIAR uma linha em marcas, e só se ela
-- entrar como "lead". Ele não consegue ler, nem mudar, nem apagar
-- nada: a sua base de contatos continua invisível para fora.
drop policy if exists "site cadastra lead" on public.marcas;
create policy "site cadastra lead" on public.marcas
  for insert to anon, authenticated
  with check (situacao = 'lead');

-- ---- EXCEÇÃO 2 · o site registra a visita ----
-- Qualquer visitante pode CRIAR uma linha em visitas. Ler o
-- relatório, só você.
drop policy if exists "site registra visita" on public.visitas;
create policy "site registra visita" on public.visitas
  for insert to anon, authenticated
  with check (true);

-- ---- EXCEÇÃO 3 · o portfólio mostra os vídeos ----
-- ATENÇÃO, LARA: esta é a única permissão de LEITURA para quem
-- não fez login, e ela existe por um motivo prático. Você pediu
-- que o portfólio leia os vídeos daqui, e quem abre o seu
-- portfólio não está logado. Sem esta linha, o site abriria sem
-- nenhum vídeo.
--
-- O que ela libera é só a lista de vídeos que JÁ ESTÁ pública no
-- seu site, e só os que estão com o olhinho aberto (visivel).
-- O que está escondido, e todo o resto (marcas, campanhas,
-- calendário, checklist, visitas), continua trancado.
--
-- Se um dia você preferir o site lendo de arquivo fixo de novo,
-- é só rodar: drop policy "portfolio mostra videos" on public.videos;
drop policy if exists "portfolio mostra videos" on public.videos;
create policy "portfolio mostra videos" on public.videos
  for select to anon
  using (visivel = true);


-- ============================================================
--  PARTE 5 · OS DADOS QUE JÁ SÃO SEUS
--
--  Os 69 vídeos que já estão no seu portfólio entram aqui, na
--  mesma ordem em que você me mandou. Não é dado inventado, é o
--  seu portfólio de hoje, para o admin já abrir cheio.
--
--  Só entra se a tabela estiver vazia, então rodar de novo não
--  duplica e não apaga nada que você editar depois.
-- ============================================================
insert into public.videos (titulo, link, nicho, formato, marca, destaque, ordem, visivel)
select * from (values
  ('', 'https://youtube.com/shorts/TbRE2_mezCg', 'beleza', 'vídeo 9:16', 'Noma', '', 1, true),
  ('skincare noturno', 'https://youtube.com/shorts/6kvtFKsPQPw', 'beleza', 'vídeo 9:16', 'L''Oréal', '', 2, true),
  ('', 'https://youtube.com/shorts/0g1pFDhxi-4', 'beleza', 'vídeo 9:16', 'Inglot', '', 3, true),
  ('', 'https://youtube.com/shorts/Yt_UjtmiMgg', 'beleza', 'vídeo 9:16', 'Rituaria', '', 4, true),
  ('', 'https://youtube.com/shorts/CzO13_qS6Fs', 'beleza', 'vídeo 9:16', 'Rituaria', '', 5, true),
  ('', 'https://youtube.com/shorts/ctKWcVRF35k', 'beleza', 'vídeo 9:16', 'Musquee', '', 6, true),
  ('', 'https://youtube.com/shorts/U_T_I-vcM7k', 'beleza', 'vídeo 9:16', 'Quintal', '', 7, true),
  ('', 'https://youtube.com/shorts/aTe89tMdv28', 'beleza', 'vídeo 9:16', 'Quintal', '', 8, true),
  ('', 'https://youtube.com/shorts/UCgbmlmT618', 'beleza', 'vídeo 9:16', 'Quintal', '', 9, true),
  ('', 'https://youtube.com/shorts/V5gvw_l08go', 'beleza', 'vídeo 9:16', 'Amobeleza', '', 10, true),
  ('', 'https://youtube.com/shorts/_d2dByXfvIw', 'beleza', 'vídeo 9:16', 'Belleton', '', 11, true),
  ('', 'https://youtube.com/shorts/dj9LD5x8MWI', 'beleza', 'vídeo 9:16', 'Rarissima', '', 12, true),
  ('', 'https://youtube.com/shorts/XwhHAl2LJ6k', 'beleza', 'vídeo 9:16', 'Box Magenta', '', 13, true),
  ('', 'https://youtube.com/shorts/cDRldAKYyKU', 'beleza', 'vídeo 9:16', 'Box Magenta', '', 14, true),
  ('', 'https://youtube.com/shorts/JPz1wMt_R4I', 'beleza', 'vídeo 9:16', 'Cand Óculos', '', 15, true),
  ('', 'https://youtube.com/shorts/P3UrVHbwI9g', 'beleza', 'vídeo 9:16', 'Bem Me Fiz', '', 16, true),
  ('', 'https://youtube.com/shorts/YOmm3Zi87PE', 'beleza', 'vídeo 9:16', 'Botox', '', 17, true),
  ('', 'https://youtube.com/shorts/nbq1HzdlPJE', 'casa', 'vídeo 9:16', 'Coza', '', 18, true),
  ('', 'https://youtube.com/shorts/Imt3HZDlCXU', 'casa', 'vídeo 9:16', 'DT3', '', 19, true),
  ('', 'https://youtube.com/shorts/JwblS_1IReM', 'casa', 'vídeo 9:16', 'DT3', '', 20, true),
  ('', 'https://youtube.com/shorts/RPNeR2ANyrM', 'casa', 'vídeo 9:16', 'DT3', '', 21, true),
  ('', 'https://youtube.com/shorts/1Fm5v3bSdKM', 'casa', 'vídeo 9:16', 'Coza', '', 22, true),
  ('', 'https://youtube.com/shorts/plSEfBiygVw', 'casa', 'vídeo 9:16', 'Coala', '', 23, true),
  ('', 'https://youtube.com/shorts/tClA-xjxP68', 'casa', 'vídeo 9:16', 'Coala', '', 24, true),
  ('', 'https://youtube.com/shorts/R-y96AP_NLo', 'casa', 'vídeo 9:16', 'Mez Móveis', '', 25, true),
  ('', 'https://youtube.com/shorts/mEc4A2oJ0_w', 'casa', 'vídeo 9:16', 'Mez Móveis', '', 26, true),
  ('', 'https://youtube.com/shorts/8T_dTUk5oX4', 'casa', 'vídeo 9:16', 'Vinagreen', '', 27, true),
  ('', 'https://youtube.com/shorts/ucf6vv64SNY', 'casa', 'vídeo 9:16', 'Offertus', '', 28, true),
  ('', 'https://youtube.com/shorts/TZK3XeajRyI', 'casa', 'vídeo 9:16', 'Velds', '', 29, true),
  ('', 'https://youtube.com/shorts/i9dHLO0VlFk', 'casa', 'vídeo 9:16', 'Velds', '', 30, true),
  ('', 'https://youtube.com/shorts/2y9Xe6Q5eMc', 'casa', 'vídeo 9:16', 'Lumai', '', 31, true),
  ('', 'https://youtube.com/shorts/0Mkvi_n-bFU', 'casa', 'vídeo 9:16', 'Lumai', '', 32, true),
  ('', 'https://youtube.com/shorts/0FhBNV71z9A', 'gastronomia', 'vídeo 9:16', 'Ateliê', '', 33, true),
  ('', 'https://youtube.com/shorts/XmjA7cpCPfQ', 'gastronomia', 'vídeo 9:16', 'Ateliê', '', 34, true),
  ('', 'https://youtube.com/shorts/orhbzi_XYiA', 'gastronomia', 'vídeo 9:16', 'Rap10', '', 35, true),
  ('', 'https://youtube.com/shorts/It7GiFzsOe0', 'gastronomia', 'vídeo 9:16', 'Rap10', '', 36, true),
  ('', 'https://youtube.com/shorts/Kq93tU1dYuA', 'gastronomia', 'vídeo 9:16', 'Copacol', '', 37, true),
  ('', 'https://youtube.com/shorts/QgCK-EJKTm0', 'drinks', 'vídeo 9:16', 'Tropical', '', 38, true),
  ('', 'https://youtube.com/shorts/R-PC_tGXdFk', 'drinks', 'vídeo 9:16', 'Cafeza', '', 39, true),
  ('', 'https://youtube.com/shorts/bUf0ItCQdUU', 'drinks', 'vídeo 9:16', 'Tropical', '', 40, true),
  ('', 'https://youtube.com/shorts/vFmYLAliwIk', 'drinks', 'vídeo 9:16', 'Tropical', '', 41, true),
  ('', 'https://youtube.com/shorts/AXzcHi_Qq_Y', 'drinks', 'vídeo 9:16', 'Smoo Sorvete', '', 42, true),
  ('', 'https://youtube.com/shorts/vbQW-1VEjPk', 'saude', 'vídeo 9:16', 'Squadz', '', 43, true),
  ('creatina', 'https://youtube.com/shorts/_6sCm4K8DRE', 'saude', 'vídeo 9:16', 'Pharmapele', '', 44, true),
  ('', 'https://youtube.com/shorts/Eul1uuQhU7g', 'saude', 'vídeo 9:16', 'Pharmapele', '', 45, true),
  ('emagrecimento', 'https://youtube.com/shorts/K31BzOy3qt0', 'saude', 'vídeo 9:16', 'Pharmapele', '', 46, true),
  ('emagrecimento', 'https://youtube.com/shorts/ZVNvzvdz4Ow', 'saude', 'vídeo 9:16', 'Voy', '', 47, true),
  ('', 'https://youtube.com/shorts/5wf8Fv2CTa4', 'financas', 'vídeo 9:16', 'InfinitePay', '100M views', 48, true),
  ('', 'https://youtube.com/shorts/wesTfq67X9o', 'financas', 'vídeo 9:16', 'Méliuz', '30M views', 49, true),
  ('app', 'https://youtube.com/shorts/GPcPWfWmA3A', 'financas', 'vídeo 9:16', 'Méliuz', '', 50, true),
  ('', 'https://youtube.com/shorts/2NMavMHi4jM', 'financas', 'vídeo 9:16', 'BV Financeiro', '', 51, true),
  ('', 'https://youtube.com/shorts/Q_n4uwkxiDo', 'financas', 'vídeo 9:16', 'BV Financeiro', '', 52, true),
  ('', 'https://youtube.com/shorts/8QRM5LPK5M8', 'tech', 'vídeo 9:16', 'Vero', '', 53, true),
  ('', 'https://youtube.com/shorts/GvLjL_Ru19U', 'tech', 'vídeo 9:16', 'Focus', '', 54, true),
  ('', 'https://youtube.com/shorts/sspAuh3TFqw', 'tech', 'vídeo 9:16', 'Logitech', '', 55, true),
  ('', 'https://youtube.com/shorts/xyaWdRi9pK4', 'tech', 'vídeo 9:16', 'Logitech', '', 56, true),
  ('', 'https://youtube.com/shorts/DxiroerLBGw', 'tech', 'vídeo 9:16', 'Reclame Aqui', '', 57, true),
  ('', 'https://youtube.com/shorts/nZQoMA114MA', 'tech', 'vídeo 9:16', 'Gamma', '', 58, true),
  ('outfit do dia', 'https://youtube.com/shorts/nV1oWxv_J_4', 'moda', 'vídeo 9:16', 'Lust', '', 59, true),
  ('', 'https://youtube.com/shorts/wZgUdGFouNA', 'moda', 'vídeo 9:16', 'Midas Time', '', 60, true),
  ('', 'https://youtube.com/shorts/t2aysMm2INg', 'moda', 'vídeo 9:16', 'Midas Time', '', 61, true),
  ('', 'https://youtube.com/shorts/QE-bUfK8z14', 'moda', 'vídeo 9:16', 'Midas Time', '', 62, true),
  ('', 'https://youtube.com/shorts/_YF_bwGgC0Y', 'moda', 'vídeo 9:16', 'Rarissima', '', 63, true),
  ('', 'https://youtube.com/shorts/Nhq12rZkpa8', 'moda', 'vídeo 9:16', 'Rarissima', '', 64, true),
  ('', 'https://youtube.com/shorts/7TzuVW8847A', 'viagem', 'vídeo 9:16', 'OKA House', '', 65, true),
  ('', 'https://youtube.com/shorts/DzIWctdbjgg', 'viagem', 'vídeo 9:16', 'OKA House', '', 66, true),
  ('', 'https://youtube.com/shorts/s5iwpfzgxbI', 'viagem', 'vídeo 9:16', 'Airbnb', '', 67, true),
  ('', 'https://youtube.com/shorts/wUxGOQ3QwFw', 'viagem', 'vídeo 9:16', 'Airbnb', '', 68, true),
  ('app', 'https://youtube.com/shorts/Y8nN7CMb73U', 'viagem', 'vídeo 9:16', 'Decolar', '', 69, true)
) as novos(titulo, link, nicho, formato, marca, destaque, ordem, visivel)
where not exists (select 1 from public.videos);


-- ============================================================
--  PARTE 6 · UMA LINHA DE EXEMPLO EM CADA LISTA
--
--  Só para você ver o formato. Pode apagar pelo admin assim que
--  entender. Visitas e checklist começam vazios de propósito,
--  para os números começarem em zero de verdade.
-- ============================================================
insert into public.marcas (nome, instagram, email, telefone, situacao, obs)
select 'EXEMPLO: apague esta linha', '@exemplo', 'exemplo@email.com',
       '', 'lead', 'Linha de exemplo, só para mostrar o formato.'
where not exists (select 1 from public.marcas);

insert into public.calendario (titulo, marca, tipo, data, status)
select 'EXEMPLO: apague esta linha', 'Marca de exemplo', 'gravar', current_date, 'a fazer'
where not exists (select 1 from public.calendario);

insert into public.campanhas (campanha, cliente, tipo, status, qtd, valor, prazo, pagamento, ativa, favorita)
select 'EXEMPLO: apague esta linha', 'Cliente de exemplo', 'Conteúdo', 'Briefing',
       1, 0, current_date + 7, 'pendente', true, false
where not exists (select 1 from public.campanhas);


-- ============================================================
--  PARTE 7 · CONFERINDO SE A TRANCA FUNCIONOU
--
--  Rode a consulta abaixo depois do Run. Ela lista as seis
--  tabelas e diz se o RLS está ligado. As seis precisam
--  aparecer com rls_ligado = true.
-- ============================================================
select tablename as tabela, rowsecurity as rls_ligado
from pg_tables
where schemaname = 'public'
  and tablename in ('videos','marcas','calendario','campanhas','marcados','visitas')
order by tablename;
