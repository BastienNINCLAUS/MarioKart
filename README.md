# Mario Kart Party

POC d'une application web (Rails 8, Hotwire, PostgreSQL) pour jouer à la "course des traîtres" sur Mario Kart. Les règles sont dans [rules.md](rules.md) et les collections dans `Rules Collections/`.

Tout se lance via Docker (aucun Ruby requis sur la machine).

## Commandes

| Action | Commande |
| --- | --- |
| Démarrer l'application (http://localhost:3000) | `docker compose up` |
| Tests unitaires et d'intégration | `docker compose run --rm web bin/rails test` |
| Tests système (Chrome headless) | `docker compose run --rm web bin/rails test:system` |
| Tout vérifier (RuboCop, audits, Brakeman, tests, seuils de couverture) | `docker compose run --rm web bin/ci` |
| Installer une gem | modifier le `Gemfile`, puis `docker compose run --rm web bundle install` |
| Régénérer les parties figées après un changement de règle voulu | `docker compose run --rm -e UPDATE_GOLDEN=1 web bin/rails test test/golden`, puis relire le diff de `test/golden/data/` |

## Anti-régression

- `bin/ci` est lancé automatiquement avant chaque `git push` par le hook [.githooks/pre-push](.githooks/pre-push). Après un clone : `git config core.hooksPath .githooks`.
- Couverture minimale de 90 % sur `app/models` et `app/services` (appliquée par `bin/ci` via `COVERAGE_CHECK=1`).
- Tout changement de `rules.md` doit s'accompagner du test correspondant.
- `test/golden/` rejoue des parties complètes de 4 à 9 joueurs avec des graines fixes et compare le résultat aux fichiers figés de `test/golden/data/` : une différence signale un changement de règle ou une régression.
- Le hasard passe par un `Random` injecté ; utiliser `seeded_random` et `with_seeds` ([test/support/seeded_random.rb](test/support/seeded_random.rb)) pour des tirages reproductibles.

## Environnements

- `Dockerfile.dev` : développement et tests (Chromium inclus). `Dockerfile` : production.
- Base de données configurée par `DATABASE_HOST`, `DATABASE_USER`, `DATABASE_PASSWORD` (voir [compose.yaml](compose.yaml)).
