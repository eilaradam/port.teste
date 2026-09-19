/* ============================================================
   LIGAÇÃO COM O BANCO DE DADOS (Supabase)

   Este é o único arquivo onde ficam o endereço do projeto e a
   chave pública. Todas as páginas do site usam ele.

   A chave abaixo é a PUBLICÁVEL (publishable / anon). Ela pode
   ficar aqui, à vista, porque sozinha não abre nada: quem manda
   é a tranca do banco (RLS), configurada no arquivo banco.sql.

   NUNCA coloque aqui a chave secreta (service_role). Se um dia
   você colar uma chave que começa com "sb_secret" ou que o
   Supabase chamar de "service_role", apague na hora.
   ============================================================ */
window.BANCO = {
  url: 'https://mmrltahvkygveymciicb.supabase.co',
  chave: 'sb_publishable_LLNmJE9EdU0rnd_aNlszTg_7utZgTg0',

  /* o e-mail que entra no admin, o mesmo que está no banco.sql */
  dona: 'laradam.ugc@gmail.com'
};

/* Cria a conexão. A biblioteca do Supabase chega pelo CDN e se
   apresenta como window.supabase, por isso a conexão vira sb. */
window.conectarBanco = function(){
  if (!window.supabase || !window.supabase.createClient){
    return null; /* o CDN não carregou, quem chamou decide o que fazer */
  }
  if (!window.sb){
    window.sb = window.supabase.createClient(window.BANCO.url, window.BANCO.chave);
  }
  return window.sb;
};
