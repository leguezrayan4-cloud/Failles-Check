# Section IA (Claude) — mise en service

La clé de l'API Claude **ne doit jamais être écrite dans l'application ni dans
le dépôt public**. Les requêtes passent par une fonction Supabase qui détient
la clé, vérifie l'utilisateur et compte les messages (300 / mois / personne).

## 1. Table de quota (SQL Editor)

```sql
create table if not exists public.ai_usage (
  user_id    uuid not null references auth.users(id) on delete cascade,
  period     text not null,              -- 'AAAA-MM' (UTC)
  used       integer not null default 0,
  updated_at timestamptz default now(),
  primary key (user_id, period)
);

alter table public.ai_usage enable row level security;

-- Chaque utilisateur peut consulter son propre compteur ; l'écriture est
-- réservée à la fonction (service_role), donc aucune politique d'écriture.
create policy "ai_usage_read_own"
  on public.ai_usage for select
  using (auth.uid() = user_id);

grant select on public.ai_usage to authenticated;
```

## 2. Secret et déploiement de la fonction

```bash
npm i -g supabase          # une seule fois
supabase login
supabase link --project-ref shxsxgezfsjhorknnsaq

# Clé Anthropic : jamais dans l'app, jamais dans Git
supabase secrets set CLAUDE_API_KEY=sk-ant-...

supabase functions deploy ai-chat
```

La fonction est dans `supabase/functions/ai-chat/index.ts`.
`SUPABASE_URL` et `SUPABASE_SERVICE_ROLE_KEY` sont fournis automatiquement par
Supabase à l'exécution : ne les mettez nulle part vous-même.

## 3. Modèle utilisé

`claude-haiku-5-5` (le moins coûteux de la gamme), `max_tokens` 700.
Pour changer de modèle, modifiez la constante `MODEL` dans la fonction — et
seulement sur demande explicite.

## 4. Fonctionnement dans l'application

- Onglet **IA** (au milieu de la barre du bas).
- Chaque message envoyé compte : traduction demandée depuis une fiche **et**
  discussion libre.
- Le compteur s'affiche (« N messages restants ce mois-ci ») et se réinitialise
  le 1er du mois suivant.
- Quota épuisé : la saisie est désactivée et la date de réinitialisation est
  affichée ; le reste de l'application continue de fonctionner.
- Hors ligne : la saisie est désactivée avec un message clair.
- Les traductions obtenues sont conservées sur l'appareil et réutilisées : la
  même faille ne repart pas au serveur.

## 5. Vérification

```bash
curl -i -X POST \
  "https://shxsxgezfsjhorknnsaq.supabase.co/functions/v1/ai-chat" \
  -H "apikey: <clé publique>" \
  -H "Authorization: Bearer <jeton utilisateur>" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","content":"Bonjour"}]}'
```

Réponse attendue : `{"reply":"...","remaining":299,"resets_at":"..."}`.
Sans jeton valide : `401`. Au-delà de 300 : `429`.
