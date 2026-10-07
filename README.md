# Mario Kart Party

Application web (Rails 8, Hotwire, PostgreSQL) pour jouer à **« la course des traîtres »** : un jeu de société joué sur téléphone, en parallèle de parties de Mario Kart 8 Deluxe. Les joueurs se répartissent en pilotes, juges et maître du jeu, cochent des objectifs secrets pendant les courses et cumulent des points.

Les règles complètes sont dans [rules.md](rules.md) et le catalogue de départ (tâches, complications, actions spéciales) dans le dossier [Rules Collections](Rules%20Collections).

> C'est un POC : les valeurs de points sont provisoires et l'équilibrage reste à faire.

## Sommaire

1. [Ce qu'il faut avant de commencer](#1-ce-quil-faut-avant-de-commencer)
2. [Installer et démarrer l'application](#2-installer-et-démarrer-lapplication)
3. [Jouer depuis plusieurs téléphones](#3-jouer-depuis-plusieurs-téléphones)
4. [Dérouler une partie pas à pas](#4-dérouler-une-partie-pas-à-pas)
5. [Arrêter, relancer, tout remettre à zéro](#5-arrêter-relancer-tout-remettre-à-zéro)
6. [En cas de problème](#6-en-cas-de-problème)
7. [Pour les développeurs](#7-pour-les-développeurs)

## 1. Ce qu'il faut avant de commencer

### Matériel
- Un ordinateur qui héberge l'application (Windows 10/11, macOS ou Linux), avec environ 4 Go de mémoire libre.
- Entre **4 et 9 joueurs**, chacun avec un téléphone (ou un navigateur récent).
- Les téléphones et l'ordinateur doivent être sur **le même réseau Wi-Fi**.
- Une console Nintendo Switch avec Mario Kart 8 Deluxe : l'application gère le jeu de société, pas les courses elles-mêmes.

### Logiciels à installer sur l'ordinateur
Une seule chose est nécessaire : **Docker**. Il n'y a rien d'autre à installer (ni Ruby, ni PostgreSQL, ni Node).

1. Télécharger **Docker Desktop** : <https://www.docker.com/products/docker-desktop/>
2. L'installer. Sous Windows, accepter l'option **WSL 2** proposée par l'installeur, puis redémarrer l'ordinateur si on vous le demande.
3. Lancer Docker Desktop et attendre que l'icône en bas à gauche passe au vert (« Engine running »).
4. Vérifier l'installation dans un terminal (PowerShell sous Windows) :

   ```powershell
   docker --version
   docker compose version
   ```

   Les deux commandes doivent afficher un numéro de version.

*(Optionnel)* **Git** (<https://git-scm.com/downloads>) n'est utile que si vous voulez récupérer le code par `git clone` ou contribuer au projet.

## 2. Installer et démarrer l'application

1. Récupérer le projet (dossier `Mario Kart Party`) : par `git clone`, ou en copiant le dossier sur l'ordinateur.
2. Ouvrir un terminal **dans ce dossier**. Sous Windows, dans l'explorateur de fichiers : clic droit dans le dossier, puis *« Ouvrir dans le Terminal »*. Sinon :

   ```powershell
   cd "C:\chemin\vers\Mario Kart Party"
   ```

3. Démarrer l'application :

   ```powershell
   docker compose up --build
   ```

   - Le **premier démarrage est long** (plusieurs minutes) : Docker télécharge et construit tout ce qu'il faut.
   - La base de données est créée toute seule, et le catalogue de départ (tâches, complications, actions spéciales) est chargé automatiquement.
   - C'est prêt quand le terminal affiche une ligne du type `Listening on http://0.0.0.0:3000`.

4. Ouvrir <http://localhost:3000> dans le navigateur de l'ordinateur : la page d'accueil s'affiche (« Créer une partie » et « Rejoindre une partie »).

Les démarrages suivants sont plus rapides : `docker compose up` suffit.

## 3. Jouer depuis plusieurs téléphones

Les joueurs ouvrent l'application avec l'adresse de l'ordinateur sur le réseau local.

1. Trouver l'adresse IP de l'ordinateur :
   - **Windows** : `ipconfig`, puis chercher la ligne « Adresse IPv4 » de la carte Wi-Fi (par exemple `192.168.1.25`).
   - **macOS / Linux** : `ifconfig` ou `ip addr`.
2. Sur chaque téléphone, connecté au même Wi-Fi, ouvrir `http://192.168.1.25:3000` (remplacer par votre adresse).
3. *(Conseillé)* Ajouter l'application à l'écran d'accueil du téléphone (menu du navigateur, « Ajouter à l'écran d'accueil ») pour l'ouvrir comme une vraie application.

Si le téléphone n'arrive pas à se connecter, le **pare-feu Windows** bloque sans doute le port 3000 : autorisez-le pour « Docker Desktop » (ou créez une règle entrante pour le port TCP 3000).

## 4. Dérouler une partie pas à pas

### 4.1 Créer la partie (l'hôte)
1. Dans « Créer une partie », saisir son **pseudo**.
2. Choisir si le rôle de **maître du jeu (MJ)** tourne après chaque coupe (coché par défaut : chaque joueur est MJ à tour de rôle).
3. Valider : un **code de partie à 5 caractères** s'affiche en grand. L'hôte reste administrateur pendant toute la partie.

### 4.2 Rejoindre la partie (les autres joueurs)
1. Dans « Rejoindre une partie », saisir le **code** et son **pseudo** (unique dans la partie).
2. La liste des joueurs se met à jour en direct chez tout le monde.
3. Si un téléphone se déconnecte, il suffit de rouvrir l'application et de saisir le même code et le même pseudo pour reprendre sa place.

### 4.3 Lancer la partie (l'hôte)
1. Il faut **entre 4 et 9 joueurs**.
2. L'hôte choisit le **nombre de coupes** (2 par défaut, 12 au maximum). L'application indique le multiple à choisir pour que chacun pilote exactement autant de fois : 2 pour un nombre pair de joueurs, autant que de joueurs pour un nombre impair.
3. Il appuie sur **« Lancer la partie »**. Plus personne ne peut rejoindre (sauf pour remplacer un abandon, voir 4.8).

### 4.4 Préparer une coupe
Une **coupe = 4 courses**. En haut de l'écran, un bandeau rappelle son rôle :

| Rôle | Ce qu'il fait |
| --- | --- |
| **Pilote** | Joue la course sur la Switch, tente d'accomplir ses objectifs. |
| **Juge** | Accompagne un pilote (le duo), choisit son personnage et **coche en direct** ses objectifs réussis. |
| **Maître du jeu** | Lance les courses, saisit les résultats, valide les tâches, tranche les litiges. Avec un nombre pair de joueurs il est aussi juge ; avec un nombre impair il ne joue pas. |

Avant la première course :
1. Chaque **juge choisit le personnage Mario Kart de son pilote** dans la liste (deux duos ne peuvent pas avoir le même).
2. Le **MJ peut ajuster le tirage automatique** des rôles en échangeant deux joueurs (« Ajuster les rôles »).
3. Quand tous les personnages sont choisis, le MJ appuie sur **« Lancer la coupe »**. L'application tire alors, pour chaque duo, une **tâche fil rouge** et une **action spéciale**.

### 4.5 Jouer une course
Chaque course commence avec une **complication** tirée au hasard, identique pour tous (par exemple « Podium inversé » ou « Pas d'objets offensifs »). Certaines sont secrètes : seuls le MJ et les duos concernés les voient.

Chaque duo voit, **dans son cadre « Mon duo »** (et nulle part ailleurs) :
- sa **tâche fil rouge** (une condition vérifiée à chaque course de la coupe),
- sa **tâche secrète** de la course (le sabotage ou la trahison du moment),
- son **action spéciale** (elle devient publique dès qu'elle est réalisée et validée).

Le déroulement d'une course :
1. Le **MJ** appuie sur **« Lancer la course »**, puis tout le monde joue sur la Switch.
2. Pendant la course, chaque **juge** coche (« Marquer comme réussie ») les objectifs que son pilote accomplit.
3. À l'arrivée, le **MJ** saisit la **place de chaque pilote**, peut **refuser** certaines tâches cochées, et, pour les complications « manuelles », **annuler les points de position** d'un fautif. Il valide avec **« Valider la course »**.
4. Les points sont calculés tout de suite, le classement se met à jour sur tous les téléphones, et la course suivante est préparée. Après la 4ᵉ course, la coupe suivante est préparée avec de nouveaux rôles.

> Le MJ ne voit pas le contenu des tâches secrètes cochées : il voit seulement qu'une tâche a été cochée.

### 4.6 Contester une décision
Si le MJ refuse une tâche que le juge avait cochée, le duo concerné peut **« Contester la décision »** (section *Contestations*). Alors :
- la tâche contestée devient visible de tous ;
- le **MJ tranche** (« Valider la tâche » ou « Maintenir le refus »), **ou lance un vote** ;
- au vote, tous les joueurs présents sauf le duo concerné et le MJ votent ; la **majorité simple** décide, et en cas d'égalité **le MJ tranche**.

Si la tâche est finalement validée, les points sont corrigés automatiquement.

### 4.7 Points et classement
- Le **classement est individuel** et cumulé sur toute la partie. Le juge ne marque aucun point.
- Les pilotes gagnent des points de **position** (modifiés par la complication) et pour chaque **tâche validée**.
- En cas d'égalité : le plus d'**actions spéciales** réalisées, puis le plus de **tâches secrètes** réussies, puis le **meilleur classement de coupe**.
- À la fin de la dernière coupe, le message « La partie est terminée » s'affiche avec le classement final.

### 4.8 Quand un joueur abandonne
Le MJ (ou l'hôte) ouvre **« Gérer les joueurs »** en bas de page et appuie sur **« X abandonne »**.
- Le joueur **garde ses points** et reste au classement : il peut encore gagner.
- Un **siège libre** est annoncé avec le code de la partie : une **nouvelle personne** peut rejoindre avec ce code et un pseudo, et reprend la place de l'abandonnant (dans la coupe en cours et les suivantes).
- Si le joueur revient avant que quelqu'un prenne sa place, le MJ appuie sur **« X est de retour »**.

## 5. Arrêter, relancer, tout remettre à zéro

| Action | Commande |
| --- | --- |
| Arrêter l'application | `Ctrl + C` dans le terminal, puis `docker compose down` |
| La relancer | `docker compose up` |
| La relancer en arrière-plan | `docker compose up -d` (puis `docker compose logs -f web` pour suivre les journaux) |
| **Effacer toutes les parties** et repartir de zéro | `docker compose down -v` |
| Reconstruire après une mise à jour du code | `docker compose up --build` |

## 6. En cas de problème

| Symptôme | Cause probable et solution |
| --- | --- |
| `docker : commande introuvable` | Docker Desktop n'est pas installé ou pas lancé. |
| Le terminal indique « Cannot connect to the Docker daemon » | Lancer Docker Desktop et attendre qu'il soit prêt. |
| `port is already allocated` (port 3000) | Un autre programme utilise le port 3000 : le fermer, ou changer `"3000:3000"` dans [compose.yaml](compose.yaml). |
| Le navigateur affiche `ERR_EMPTY_RESPONSE` ou ne répond pas | Attendre la ligne `Listening on http://0.0.0.0:3000` dans le terminal, puis recharger la page. |
| Les téléphones ne se connectent pas | Vérifier le même Wi-Fi, l'adresse IP, et le pare-feu (voir partie 3). |
| « Code de partie inconnu » | Vérifier le code (5 caractères, sans I, O, 0 ni 1). |
| « Le pseudo est déjà utilisé(e) » | Ce pseudo est déjà pris dans la partie : en choisir un autre, ou utiliser le téléphone d'origine pour se reconnecter. |
| La page ne se met plus à jour | La recharger. Les mises à jour en direct nécessitent que le téléphone reste connecté au Wi-Fi. |
| Une partie est bloquée ou à jeter | `docker compose down -v` efface toutes les données. |

## 7. Pour les développeurs

### Lancer les tests
Tout passe par Docker, sans rien installer :

| Action | Commande |
| --- | --- |
| Tests unitaires et d'intégration | `docker compose run --rm web bin/rails test` |
| Tests système (Chrome headless, plusieurs téléphones simulés) | `docker compose run --rm web bin/rails test:system` |
| **Tout vérifier** (style, audits de sécurité, Brakeman, tests, couverture) | `docker compose run --rm web bin/ci` |
| Installer une gem | modifier le `Gemfile`, puis `docker compose run --rm web bundle install` |

### Filet anti-régression
- `bin/ci` se lance automatiquement avant chaque `git push` grâce au hook [.githooks/pre-push](.githooks/pre-push). Après un `git clone`, activer le hook une fois : `git config core.hooksPath .githooks`.
- Couverture minimale de **90 %** sur `app/models` et `app/services` (vérifiée par `bin/ci`).
- `test/golden/` rejoue des **parties complètes de 4 à 9 joueurs** avec des graines fixes et compare le résultat aux fichiers figés de `test/golden/data/`. Une différence signale un changement de règle ou une régression. Après un changement de règle **voulu** :

  ```powershell
  docker compose run --rm -e UPDATE_GOLDEN=1 web bin/rails test test/golden
  ```

  puis relire le diff de `test/golden/data/` avant de le valider.
- Tout changement de `rules.md` doit s'accompagner du test correspondant.
- Le hasard passe par un `Random` injecté : utiliser `seeded_random` et `with_seeds` ([test/support/seeded_random.rb](test/support/seeded_random.rb)) pour des tirages reproductibles.

### Modifier le catalogue de jeu
Les tâches fil rouge, tâches secrètes, actions spéciales et complications sont décrites dans `db/catalog/*.yml`. Après une modification :
1. Redémarrer l'application (le catalogue est rechargé au démarrage).
2. Mettre à jour le tableau correspondant dans `Rules Collections/` : un test compare les deux et échoue s'ils divergent.
3. Une nouvelle complication demande aussi sa règle de calcul dans `ComplicationResolver`.

### Organisation du code
| Dossier | Contenu |
| --- | --- |
| `app/models` | Parties, joueurs, coupes, duos, courses, tâches cochées, contestations, votes, points |
| `app/services` | Règles métier pures : répartition des rôles, calcul des points, classement, tirages, remplacement |
| `app/controllers`, `app/views` | Écrans mobile-first, rendus pour chaque joueur (les secrets ne sont jamais envoyés aux autres) |
| `db/catalog` | Catalogue de départ en YAML |
| `test/` | Tests unitaires, d'intégration, système, et parties figées (`test/golden`) |

### Environnements
- `Dockerfile.dev` : développement et tests (Chromium inclus). `Dockerfile` : production.
- La base de données est configurée par `DATABASE_HOST`, `DATABASE_USER` et `DATABASE_PASSWORD` (voir [compose.yaml](compose.yaml)).
- Les mises à jour en direct passent par Turbo Streams : les diffusions ne contiennent jamais de contenu, seulement l'ordre de recharger la page.
