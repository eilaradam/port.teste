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
insert into public.videos (marca, link, nicho, titulo, destaque, ordem, formato, visivel)
select m, 'https://youtube.com/shorts/' || codigo, n, coalesce(tit,''), coalesce(des,''), ord, 'vídeo 9:16', true
from (values
  ('Noma','TbRE2_mezCg','beleza',null,null,1),
  ('L''Oréal','6kvtFKsPQPw','beleza','skincare noturno',null,2),
  ('Inglot','0g1pFDhxi-4','beleza',null,null,3),
  ('Rituaria','Yt_UjtmiMgg','beleza',null,null,4),
  ('Rituaria','CzO13_qS6Fs','beleza',null,null,5),
  ('Musquee','ctKWcVRF35k','beleza',null,null,6),
  ('Quintal','U_T_I-vcM7k','beleza',null,null,7),
  ('Quintal','aTe89tMdv28','beleza',null,null,8),
  ('Quintal','UCgbmlmT618','beleza',null,null,9),
  ('Amobeleza','V5gvw_l08go','beleza',null,null,10),
  ('Belleton','_d2dByXfvIw','beleza',null,null,11),
  ('Rarissima','dj9LD5x8MWI','beleza',null,null,12),
  ('Box Magenta','XwhHAl2LJ6k','beleza',null,null,13),
  ('Box Magenta','cDRldAKYyKU','beleza',null,null,14),
  ('Cand Óculos','JPz1wMt_R4I','beleza',null,null,15),
  ('Bem Me Fiz','P3UrVHbwI9g','beleza',null,null,16),
  ('Botox','YOmm3Zi87PE','beleza',null,null,17),
  ('Coza','nbq1HzdlPJE','casa',null,null,18),
  ('DT3','Imt3HZDlCXU','casa',null,null,19),
  ('DT3','JwblS_1IReM','casa',null,null,20),
  ('DT3','RPNeR2ANyrM','casa',null,null,21),
  ('Coza','1Fm5v3bSdKM','casa',null,null,22),
  ('Coala','plSEfBiygVw','casa',null,null,23),
  ('Coala','tClA-xjxP68','casa',null,null,24),
  ('Mez Móveis','R-y96AP_NLo','casa',null,null,25),
  ('Mez Móveis','mEc4A2oJ0_w','casa',null,null,26),
  ('Vinagreen','8T_dTUk5oX4','casa',null,null,27),
  ('Offertus','ucf6vv64SNY','casa',null,null,28),
  ('Velds','TZK3XeajRyI','casa',null,null,29),
  ('Velds','i9dHLO0VlFk','casa',null,null,30),
  ('Lumai','2y9Xe6Q5eMc','casa',null,null,31),
  ('Lumai','0Mkvi_n-bFU','casa',null,null,32),
  ('Ateliê','0FhBNV71z9A','gastronomia',null,null,33),
  ('Ateliê','XmjA7cpCPfQ','gastronomia',null,null,34),
  ('Rap10','orhbzi_XYiA','gastronomia',null,null,35),
  ('Rap10','It7GiFzsOe0','gastronomia',null,null,36),
  ('Copacol','Kq93tU1dYuA','gastronomia',null,null,37),
  ('Tropical','QgCK-EJKTm0','drinks',null,null,38),
  ('Cafeza','R-PC_tGXdFk','drinks',null,null,39),
  ('Tropical','bUf0ItCQdUU','drinks',null,null,40),
  ('Tropical','vFmYLAliwIk','drinks',null,null,41),
  ('Smoo Sorvete','AXzcHi_Qq_Y','drinks',null,null,42),
  ('Squadz','vbQW-1VEjPk','saude',null,null,43),
  ('Pharmapele','_6sCm4K8DRE','saude','creatina',null,44),
  ('Pharmapele','Eul1uuQhU7g','saude',null,null,45),
  ('Pharmapele','K31BzOy3qt0','saude','emagrecimento',null,46),
  ('Voy','ZVNvzvdz4Ow','saude','emagrecimento',null,47),
  ('InfinitePay','5wf8Fv2CTa4','financas',null,'100M views',48),
  ('Méliuz','wesTfq67X9o','financas',null,'30M views',49),
  ('Méliuz','GPcPWfWmA3A','financas','app',null,50),
  ('BV Financeiro','2NMavMHi4jM','financas',null,null,51),
  ('BV Financeiro','Q_n4uwkxiDo','financas',null,null,52),
  ('Vero','8QRM5LPK5M8','tech',null,null,53),
  ('Focus','GvLjL_Ru19U','tech',null,null,54),
  ('Logitech','sspAuh3TFqw','tech',null,null,55),
  ('Logitech','xyaWdRi9pK4','tech',null,null,56),
  ('Reclame Aqui','DxiroerLBGw','tech',null,null,57),
  ('Gamma','nZQoMA114MA','tech',null,null,58),
  ('Lust','nV1oWxv_J_4','moda','outfit do dia',null,59),
  ('Midas Time','wZgUdGFouNA','moda',null,null,60),
  ('Midas Time','t2aysMm2INg','moda',null,null,61),
  ('Midas Time','QE-bUfK8z14','moda',null,null,62),
  ('Rarissima','_YF_bwGgC0Y','moda',null,null,63),
  ('Rarissima','Nhq12rZkpa8','moda',null,null,64),
  ('OKA House','7TzuVW8847A','viagem',null,null,65),
  ('OKA House','DzIWctdbjgg','viagem',null,null,66),
  ('Airbnb','s5iwpfzgxbI','viagem',null,null,67),
  ('Airbnb','wUxGOQ3QwFw','viagem',null,null,68),
  ('Decolar','Y8nN7CMb73U','viagem','app',null,69)
) as v(m, codigo, n, tit, des, ord)
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
--  PARTE 7 · A TABELA DE TRANSCRIÇÕES
--
--  Os conteúdos que você guarda para estudar: o link do vídeo,
--  o roteiro escrito e as suas anotações.
--
--  É material só seu. Não tem nenhuma brecha para quem não fez
--  login: ninguém de fora lê, escreve ou apaga nada daqui.
-- ============================================================
create table if not exists public.transcricoes (
  id           bigint generated always as identity primary key,
  link         text not null default '',
  plataforma   text not null default '',
  titulo       text not null default '',
  transcricao  text not null default '',
  obs          text not null default '',
  favorita     boolean not null default false,
  criado_em    timestamptz not null default now()
);

alter table public.transcricoes enable row level security;

drop policy if exists "dona faz tudo em transcricoes" on public.transcricoes;
create policy "dona faz tudo em transcricoes" on public.transcricoes
  for all to authenticated
  using (public.sou_a_dona()) with check (public.sou_a_dona());


-- ============================================================
--  PARTE 8 · CONFERINDO SE A TRANCA FUNCIONOU
--
--  Rode a consulta abaixo depois do Run. Ela lista as sete
--  tabelas e diz se o RLS está ligado. As sete precisam
--  aparecer com rls_ligado = true.
-- ============================================================
select tablename as tabela, rowsecurity as rls_ligado
from pg_tables
where schemaname = 'public'
  and tablename in ('videos','marcas','calendario','campanhas','marcados','visitas','transcricoes')
order by tablename;
