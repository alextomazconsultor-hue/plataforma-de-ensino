# Plataforma Método 3Ps — Aulas via Supabase

Esta versão mantém:
- acesso por e-mail
- progresso no Supabase
- última aula no Supabase
- Supabase escondido do aluno

Novo ajuste:
- módulos e aulas agora podem vir do Supabase.
- `js/data.js` ficou apenas como fallback.
- Depois que você publicar esta versão, poderá trocar links de vídeo direto na tabela `lessons`, sem republicar.

## Passo 1 — Rodar SQL
No Supabase:
SQL Editor > New query > cole o conteúdo de `supabase_aulas.sql` > Run.

Isso cria:
- course_modules
- lessons

E já insere módulos/aulas iniciais.

## Passo 2 — Publicar esta versão
Publique este ZIP/pasta no Netlify ou outro host.

## Passo 3 — Trocar vídeo sem republicar
No Supabase:
Table Editor > lessons > escolha a aula > edite `video_url`.

Use link embed do YouTube:
https://www.youtube.com/embed/CODIGO_DO_VIDEO

Exemplo:
link normal: https://www.youtube.com/watch?v=ABC123
link embed:  https://www.youtube.com/embed/ABC123

## Atenção
Se o Supabase falhar ou as tabelas estiverem vazias, a plataforma usa o `js/data.js` como fallback.
