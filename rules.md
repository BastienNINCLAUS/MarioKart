# Mario Kart - La course des traîtres : Règles du jeu

> Remplis chaque chapitre. Si un point n'existe pas, écris "N/A". Si tu hésites, écris "À décider".

## 1. Présentation générale
- Concept en une phrase : Il s'agit d'un jeu qui se base sur Mario Kart. On gagne des points en réalisant des actions dans le jeu et en sabotant les autres joueurs.
- Objectif global du jeu : Accumuler le plus de points possible tout en déjouant les plans des autres joueurs.
- Lien avec Mario Kart (jeu vidéo joué en parallèle ? Jeu de société inspiré ?) : Le jeu se joue en parallèle avec Mario Kart, et les résultats des courses influencent le déroulement du jeu de société.
- Durée moyenne d'une partie : Environ 60 à 90 minutes, selon le nombre de joueurs et le rythme des courses.

## 2. Joueurs
- Nombre minimum / maximum de joueurs : 4 à 9 joueurs
- Y a-t-il un maître du jeu / hôte (celui qui crée la partie) ? Joue-t-il aussi ? : Oui, il y a un maître du jeu qui organise la partie et peut également jouer si le nombre de joueur est pair
  - L'hôte (créateur de la partie) reste administrateur permanent pendant toute la partie : lancer, exclure un joueur, corriger. Le rôle de Maître du jeu (MJ) peut, lui, tourner entre les coupes.
  - Lors de la création de la partie, l'hôte peut activer l'option "faire tourner le rôle de MJ après chaque coupe". Pour le POC, la rotation est activée : chaque joueur est MJ à tour de rôle, sans repasser tant que tous ne l'ont pas été.
  - Quand le nombre de joueurs est pair, le MJ est aussi juge, y compris pour les litiges de son propre pilote : accepté.
- Peut-on rejoindre ou quitter une partie en cours ? : Non, une fois la partie commencée, les joueurs ne peuvent pas rejoindre. Un joueur peut quitter, mais cela peut affecter le déroulement du jeu.
- Équipes éventuelles : Pas d'équipe pour le moment

## 3. Matériel et contexte physique
- Faut-il une console Mario Kart (quelle version ?) en plus des téléphones ? : Oui, une console Nintendo Switch avec Mario Kart 8 Deluxe est nécessaire pour jouer en parallèle.
- Matériel physique utilisé (cartes, jetons, dés, etc.) : aucun tout doit être numérique et géré via l'application/site
- Rôle de l'appli dans ce dispositif (remplace quoi ? complète quoi ?) : L'application gère les points, les actions des joueurs, les rôles secrets et les résultats des courses Mario Kart. Elle complète le jeu physique en centralisant toutes les informations et en automatisant certaines règles.

## 4. Rôles
- Liste des rôles (ex : traître, loyal, autres) : Pilote(s), Juge(s), Maitre du jeu (unique)
- Pour chaque rôle : objectif, pouvoirs, informations connues : 
  - Pilote(s) : Objectif : accumuler des points et gagner les courses. Pouvoirs : participer aux courses, réaliser des actions spéciales. Informations connues : son propre rôle et ses points.
  - Juge(s) : Objectif : superviser les actions de son pilote et s'assurer de la réalisation des objectifs. Pouvoirs : valider ou invalider certaines actions. Informations connues : les actions de son pilote. Le juge ne marque aucun point pour le moment (évolution possible dans une version ultérieure, sous certaines conditions).
  - Maitre du jeu (unique) : Objectif : organiser la partie et gérer le déroulement du jeu. Pouvoirs : Arbitrer en cas de conflit, saisir les résultats de course, valider en fin de course les tâches cochées par les juges. Informations connues : tous les rôles et les résultats saisis. Ce qu'il voit des tâches cochées par les juges est à définir plus tard (par défaut, il ne voit pas les tâches secrètes des duos).
- Répartition des rôles selon le nombre de joueurs : 
  - nombre de joueurs pair : (nbr joueur / 2) Pilotes, (nbr joueur / 2) Juges, l'un des juges posséde aussi le rôle de Maitre du jeu
  - nombre de joueurs impair : ((nbr joueur - 1) / 2) Pilotes, ((nbr joueur - 1) / 2) Juges, 1 Maitre du jeu (unique)
- Comment les rôles sont attribués (aléatoire, choix, etc.) : 
  - Au début de la partie, en fonction du nombre de joueurs l'application propose par défaut un cycle réduit (ex : 2 coupes) quand le nombre de joueurs est impair. Le Maitre du jeu à la possibilité d'augmenter le nombre de coupes de la partie.
  - Au début d'une coupe, les rôles sont attribués pour cette coupe spécifique, en respectant l'équité définie par le nombre de coupes total.
  - Le maitre du jeu change entre les coupes à tour de rôle quand la rotation est activée (voir chapitre 2).
  - Les rôles des pilotes et des juges peuvent également changer entre les coupes pour maintenir l'équité et la diversité des expériences de jeu.
  - Équité : chaque joueur est pilote le même nombre de fois (et donc juge le même nombre de fois).
  - Tirage automatique des pilotes et des duos ; le MJ peut ajuster le résultat.
- Qui connaît quel rôle (secret total, traîtres se connaissent, etc.) : Tous le mondes connait tous les rôles pour le moment.
- Les rôles peuvent-ils changer en cours de partie ? Les rôles sont attribués pour chaque coupe, et peuvent donc changer entre les coupes pour maintenir l'équité et la diversité des expériences de jeu.

## 5. Mise en place (début de partie)
- Étapes avant de commencer :
  1. Le maitre du jeu (qui créé la partie) valide le lancement de la partie une fois que tout le monde à rejoint la partie
  2. Le maitre du jeu détermine le nombre de coupes à jouer en fonction du nombre de joueurs.
  3. À la création, l'hôte choisit si le rôle de MJ tourne après chaque coupe.
- Informations secrètes distribuées à chaque joueur : Aucune
- Conditions pour lancer la partie : Le maitre du jeu a validé le lancement de la partie.

## 6. Déroulement d'une partie
- Structure (manches, courses, tours, phases) : Chaque partie est composée de plusieurs coupes, chaque coupe comprenant 4 courses.
- Nombre de manches / courses : Chaque coupe comprend 4 courses.
- Ordre de jeu et durée de chaque phase : 
  1. Au début de chaque coupe les rôles sont distribués.
  2. Les rôles de pilotes sont distribués (tirage automatique, ajustable par le MJ).
  3. Chaque pilotes se voit attribué un juge associé (tirage automatique, ajustable par le MJ).
  4. Le juge renseigne le personnage de mario kart associé a son pilote. Ce personnage sert à identifier visuellement le pilote dans le classement et à l'écran. Il est choisi dans une liste prédéfinie des personnages de Mario Kart 8 Deluxe (avec image si possible).
  5. Les pilotes recoivents une tache fil rouge qui doit être accomplie tout au long des 4 courses de la coupe. Elle n'est uniquement visible par le duo Pilotes/juges. La tâche fil rouge est une condition vérifiée à chaque course (ex : lancer plus de 12 bananes) qui rapporte des points pour chaque course où elle est remplie. Chaque pilote reçoit aussi une action spéciale tirée au hasard pour la coupe, visible par son juge. Elle peut être réalisée une ou plusieurs fois et devient publique dès qu'elle est réalisée au moins une fois.
  6. Avant le lancement d'une course une complication est choisie aléatoirement (la même pour tous les pilotes). Une complication est un handicap global qui modifie les règles ou les points de la course. Types : ciblée (N duos tirés au hasard, ex : Les amoureux), globale (selon la position de chaque duo), contrainte sur le jeu vidéo (ex : pas d'objets offensifs). Tous les duo Pilotes/Juges en prennent connaissance. En fonction de la complication, elle peut être rendu publique ou rester secrète pour les autres joueurs. Son effet est calculé automatiquement quand il repose sur des informations saisies dans l'appli (ex : positions), sinon appliqué manuellement par le MJ. Une taches secrétes individuelles est également distribué à chaque duo Pilotes/Juges.
  7. La course se lance. Les pilotes jouent et les juges notent tout ce qui permet de récupérer des points à son pilotes. (réalisation de la tâche fil rouge, des taches secrétes, des actions spéciales, etc.) Le juge coche les tâches réussies en direct pendant la course.
  8. Le résultat de la course (position de chaque pilote) est saisie par le maitre du jeu, qui valide également en fin de course les tâches cochées par les juges. Le duo peut contester une décision du MJ : le MJ tranche ou lance un vote.
  9. On passe à la course suivante jusqu'à finir la coupe
- Actions possibles à chaque phase (pour chaque joueur) : 
  - Pilote : Jouer la course, accomplir la tâche fil rouge, subir la complication, accomplir son action spéciale.
  - Juge : Noter les actions du pilote
- Actions secrètes vs actions publiques :
  - Actions secrètes : Tâche fil rouge, taches secrétes individuelles, certaines complications, action spéciale tant qu'elle n'a pas été réalisée.
  - Actions publiques : Jouer la course, complications publiques, action spéciale une fois réalisée.

## 7. Lien avec les courses Mario Kart
- Comment le résultat d'une course influence le jeu (positions, objets, victoires) : Le MJ saisit la position de chaque pilote ; la position rapporte des points (valeurs provisoires, à équilibrer plus tard).
- Classement ou points pris en compte : Position de chaque pilote à la fin de chaque course. Valeurs provisoires, équilibrage reporté après le POC.
- L'appli doit-elle saisir les résultats de course ? Qui les saisit ? Oui, le maitre du jeu

## 8. Points, scores et ressources
- Système de points : Les points se cumulent sur toute la partie (pas de classement par coupe). L'équilibrage des points est reporté après le POC ; des valeurs provisoires sont dans le dossier Rules Collections. Le juge ne marque aucun point pour le moment.
- Ressources (pièces, objets, cartes, pouvoirs) : Un seul concept : l'"action spéciale" (pas de pouvoirs/objets/cartes séparés). La façon de l'obtenir reste à décider.
- Gains et pertes (comment, quand) : A définir
- Classement individuel / par équipe : classement individuel

## 9. Votes
- Y a-t-il des votes ? Oui, uniquement si le MJ demande un vote pour trancher un litige.
- Règle de décision : tous les joueurs sauf le duo concerné votent, majorité simple, le MJ tranche en cas d'égalité.

## 10. Pouvoirs spéciaux, objets et événements
- Liste des pouvoirs / objets / cartes (nom, effet, coût, quand utilisable) : Seul le concept d'"action spéciale" est conservé. Un catalogue de départ (tâches fil rouge, complications, tâches secrètes individuelles, actions spéciales) est défini dans le dossier Rules Collections. Certains pouvoir son défini est mis à disposition des joueurs dans un premir temps. Dans un second temps, il sera possible de laisser la main aux joueurs de créer et manager les collections avant de lancer les parties
- Événements aléatoires : Hors POC, ajoutés plus tard (les complications couvrent ce besoin pour le moment). Dans un second temps, il sera possible de laisser la main aux joueurs de créer et manager les collections avant de lancer les parties.
- Limites d'usage : à définir

## 11. Conditions de victoire et de fin
- Victoire : Celui qui a le plus de point à la fin de la partie.
- Égalités : Celui qui a réalisé le plus d'actions spéciales, puis celui qui a réalisé le plus de tâches secrètes, puis celui qui a le meilleur classement de coupe (le plus de 1res places, puis de 2es, etc.). Le classement de coupe est calculé en interne (points gagnés dans la coupe), uniquement pour départager.
- Fin anticipée de partie : Pas de fin anticipée pour le POC.

## 12. Cas particuliers
- Joueur qui se déconnecte ou abandonne : En attente de reconnexion avec le même téléphone et nom de joueur. Pas de délai automatique : le MJ décide manuellement si le joueur est considéré comme ayant abandonné. Un joueur qui abandonne garde ses points et peut encore gagner. Si un pilote ou un juge abandonne en pleine coupe, le MJ peut le remplacer par un autre joueur disponible (ex : le MJ s'il ne joue pas).
- Règles d'arbitrage / litiges : Le maitre du jeu à ce rôle de trancher en cas de litige ou de situation non prévue par les règles. Il peut demander un vote (voir chapitre 9).
- Tricherie et interdits : Toute tentative de tricherie ou de non-respect des règles sera sanctionnée par le maitre du jeu, pouvant aller jusqu'à l'exclusion de la partie.

## 13. Ce que l'appli doit faire
- Fonctionnalités indispensables pour le POC : Page de création et de lancement de partie, distribution des rôles, tirage des tâches, complications et actions spéciales, gestion des tours, suivi des points et des actions spéciales.
- Fonctionnalités souhaitées plus tard : Gestion avancée des collections de pouvoirs / objets / cartes par les joueurs, personnalisation des règles de la partie, statistiques détaillées des joueurs, page de détail des parties et historique des parties précédentes.
- Ce que chaque joueur doit voir sur son téléphone (écran privé) : Ses propres points, sa tâche fil rouge, sa tâche secrète, son action spéciale, la complication en cours, et éventuellement les informations sur les autres joueurs si cela est autorisé par les règles.
- Ce qui doit être visible de tous (écran commun) : Le classement général, les actions spéciales réalisées, les événements aléatoires en cours, et les informations pertinentes pour le déroulement de la partie.
- Notifications / alertes attendues : Alertes pour les actions spéciales réalisées, notifications de début et de fin de tour, messages d'événements aléatoires.
- Informations à garder en secret côté serveur : Tâche fil rouge, tâches secrètes et complications secrètes : visibles uniquement par le duo concerné. Le MJ ne les voit pas par défaut ; ce qu'il voit des tâches cochées lors de sa validation est à définir plus tard.

## 14. Ambiance et interface
- Ton, humour, univers visuel (couleurs, personnages, thème Mario Kart) : Axé sur l'humour et la légèreté, avec des couleurs en corélation avec l'univers de Mario Kart.
- Langues : Français et éventuellement anglais.
- Éléments sonores ou animations souhaités : Musiques et effets sonores inspirés de Mario Kart, animations pour les actions spéciales et les événements aléatoires.

## 15. Exemples et références
- Exemple de partie déroulée pas à pas : A définir
- Schémas, photos, liens utiles : 
  - Lien vers le site officiel de Mario Kart : https://www.mariokart.com/
  - Lien vers le wiki de Mario Kart : https://mariokart.fandom.com/wiki/Mario_Kart_Wiki
- Points flous ou règles encore en discussion : Trancher par le maitre du jeu, il faut noter les points flous et les décisions prises pour référence future.
  - À définir plus tard : ce que voit exactement le MJ des tâches cochées par les juges.
  - À définir plus tard : équilibrage des points (valeurs provisoires dans Rules Collections), façon d'obtenir les actions spéciales au-delà du tirage par coupe, événements aléatoires, fin anticipée de partie.
