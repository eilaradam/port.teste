// ============================================================
//  O CARTEIRO · função enviar-emails
//
//  ONDE ESTE CÓDIGO VAI MORAR (não é no seu site):
//  1. Abra https://supabase.com e entre no seu projeto
//  2. Menu da esquerda, clique em "Edge Functions"
//  3. Clique em "Deploy a new function", depois em "Via Editor"
//  4. No nome da função escreva exatamente:  enviar-emails
//  5. Apague o exemplo que vier escrito e cole este arquivo inteiro
//  6. Clique em "Deploy function"
//
//  A CHAVE DO RESEND NÃO ENTRA AQUI DENTRO.
//  Ela fica guardada como segredo, em Edge Functions > Secrets,
//  com o nome RESEND_API_KEY. Este código só pede o segredo ao
//  Supabase na hora de usar, e ele nunca aparece no seu site.
//
//  Segredos que esta função usa:
//    RESEND_API_KEY   obrigatório, você cola no painel do Supabase
//    RESEND_FROM      opcional, o remetente. Enquanto você não tiver
//                     domínio verificado, deixe sem preencher.
//    EMAIL_RESPOSTA   opcional, para onde vai a resposta da marca.
// ============================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// quem pode mandar e-mail por aqui, e só ela
const DONA = 'laradam.ugc@gmail.com';

// para onde a marca responde quando clicar em responder
const EMAIL_RESPOSTA = Deno.env.get('EMAIL_RESPOSTA') || DONA;

// enquanto não houver domínio verificado, o Resend só deixa este
// remetente, e só entrega para o e-mail da própria conta
const REMETENTE = Deno.env.get('RESEND_FROM') || 'Lara Damasceno <onboarding@resend.dev>';

const LIMITE_POR_CHAMADA = 250;
const ESPERA_ENTRE_ENVIOS = 200; // milissegundos, mais ou menos 5 por segundo

const CABECALHOS_CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function responder(corpo: unknown, status = 200) {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { ...CABECALHOS_CORS, 'Content-Type': 'application/json' },
  });
}

function dormir(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// troca {{nome}} pelo primeiro nome e {{marca}} pelo nome completo
function personalizar(texto: string, nomeDaMarca: string) {
  const completo = String(nomeDaMarca || '').trim();
  const primeiro = completo.split(/\s+/)[0] || completo;
  return String(texto || '')
    .replaceAll('{{nome}}', primeiro)
    .replaceAll('{{marca}}', completo);
}

Deno.serve(async (req) => {
  // o navegador pergunta antes se pode chamar. Esta é a resposta.
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CABECALHOS_CORS });
  }
  if (req.method !== 'POST') {
    return responder({ erro: 'Só aceito POST.' }, 405);
  }

  const urlSupabase = Deno.env.get('SUPABASE_URL')!;
  const chavePublica = Deno.env.get('SUPABASE_ANON_KEY')!;
  const chaveInterna = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const chaveResend = Deno.env.get('RESEND_API_KEY');

  // ---------- 1. porteiro: só a dona logada entra ----------
  const autorizacao = req.headers.get('Authorization') || '';
  const token = autorizacao.replace('Bearer ', '').trim();
  if (!token) {
    return responder({ erro: 'Faça login no painel antes de disparar.' }, 401);
  }

  const conferente = createClient(urlSupabase, chavePublica, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: quem, error: erroQuem } = await conferente.auth.getUser(token);
  const email = quem?.user?.email?.toLowerCase() || '';
  if (erroQuem || email !== DONA.toLowerCase()) {
    return responder({ erro: 'Este disparo é só da Lara.' }, 403);
  }

  if (!chaveResend) {
    return responder({
      erro: 'A chave do Resend ainda não foi colada no Supabase. ' +
            'Vá em Edge Functions, Secrets, e crie o segredo RESEND_API_KEY.',
      faltaChave: true,
    }, 400);
  }

  // ---------- 2. o que veio do painel ----------
  let corpo: any = {};
  try {
    corpo = await req.json();
  } catch {
    return responder({ erro: 'Não entendi o que o painel mandou.' }, 400);
  }

  const assunto: string = String(corpo.assunto || '').trim();
  const html: string = String(corpo.html || '');
  const destinatarios: Array<{ email: string; nome: string }> = Array.isArray(corpo.destinatarios)
    ? corpo.destinatarios
    : [];

  if (!assunto) return responder({ erro: 'Faltou o assunto.' }, 400);
  if (!html) return responder({ erro: 'Faltou o texto do e-mail.' }, 400);
  if (!destinatarios.length) return responder({ erro: 'A lista de destinatários veio vazia.' }, 400);
  if (destinatarios.length > LIMITE_POR_CHAMADA) {
    return responder({
      erro: `São no máximo ${LIMITE_POR_CHAMADA} destinatários por vez. ` +
            `Vieram ${destinatarios.length}.`,
    }, 400);
  }

  // ---------- 3. quem pediu para não receber mais ----------
  const banco = createClient(urlSupabase, chaveInterna);
  const fora = new Set<string>();
  try {
    const { data } = await banco.from('email_optout').select('email');
    (data || []).forEach((linha: any) => fora.add(String(linha.email || '').toLowerCase().trim()));
  } catch {
    // se a tabela ainda não existir, seguimos sem lista de descadastro
  }

  // ---------- 4. o disparo, um por vez ----------
  let enviados = 0;
  let falhas = 0;
  let pulados = 0;
  let cotaAcabou = false;
  let faltaram = 0;

  for (let i = 0; i < destinatarios.length; i++) {
    const pessoa = destinatarios[i];
    const paraEmail = String(pessoa?.email || '').toLowerCase().trim();
    const nomeMarca = String(pessoa?.nome || '').trim();

    if (!paraEmail || fora.has(paraEmail)) {
      pulados++;
      continue;
    }

    const assuntoFinal = personalizar(assunto, nomeMarca);
    const htmlFinal = personalizar(html, nomeMarca);

    try {
      const resposta = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${chaveResend}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: REMETENTE,
          to: [paraEmail],
          subject: assuntoFinal,
          html: htmlFinal,
          reply_to: EMAIL_RESPOSTA,
          headers: {
            'List-Unsubscribe': `<mailto:${EMAIL_RESPOSTA}?subject=SAIR>`,
            'List-Unsubscribe-Post': 'List-Unsubscribe=One-Click',
          },
        }),
      });

      const resultado = await resposta.json().catch(() => ({}));

      if (resposta.ok && resultado?.id) {
        enviados++;
        await banco.from('email_envios').insert({
          email: paraEmail,
          assunto: assuntoFinal,
          status: 'ok',
          erro: '',
          resend_id: String(resultado.id),
        });
      } else {
        const nomeErro = String(resultado?.name || '');
        const textoErro = String(resultado?.message || resultado?.error || 'erro sem descrição');

        // cota diária estourada: para na hora, não adianta insistir
        if (
          nomeErro === 'daily_quota_exceeded' ||
          textoErro.toLowerCase().includes('daily quota') ||
          textoErro.toLowerCase().includes('daily_quota_exceeded')
        ) {
          cotaAcabou = true;
          faltaram = destinatarios.length - i;
          await banco.from('email_envios').insert({
            email: paraEmail,
            assunto: assuntoFinal,
            status: 'erro',
            erro: 'cota diária do Resend acabou',
            resend_id: '',
          });
          break;
        }

        falhas++;
        await banco.from('email_envios').insert({
          email: paraEmail,
          assunto: assuntoFinal,
          status: 'erro',
          erro: textoErro.slice(0, 400),
          resend_id: '',
        });
      }
    } catch (e) {
      falhas++;
      await banco.from('email_envios').insert({
        email: paraEmail,
        assunto: assuntoFinal,
        status: 'erro',
        erro: String(e).slice(0, 400),
        resend_id: '',
      });
    }

    // ritmo seguro do Resend: mais ou menos 5 por segundo
    if (i < destinatarios.length - 1) {
      await dormir(ESPERA_ENTRE_ENVIOS);
    }
  }

  return responder({
    enviados,
    falhas,
    pulados,
    cotaAcabou,
    faltaram,
    remetente: REMETENTE,
  });
});
