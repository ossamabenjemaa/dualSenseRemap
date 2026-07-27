# Guide utilisateur — DualSense Remap

Bienvenue ! Ce guide couvre tout : la prise en main, chaque page de
l'application, le clavier virtuel touche par touche, l'intégration
Hammerspoon, et des recettes prêtes à l'emploi.

Sommaire :

1. [Premiers pas](#1-premiers-pas)
2. [Tour de l'interface](#2-tour-de-linterface)
3. [Le clavier virtuel en détail](#3-le-clavier-virtuel-en-détail)
4. [Recettes](#4-recettes)
5. [Toutes les tables de raccourcis](#5-toutes-les-tables-de-raccourcis)

---

## 1. Premiers pas

### 1.1 Installer et lancer

```bash
git clone https://github.com/ossamabenjemaa/dualSenseRemap.git
cd dualSenseRemap
make app && make install
```

Première ouverture : clic droit sur « DualSense Remap.app » → **Ouvrir**
(signature ad hoc — une seule fois). Détails : [BUILD.md](BUILD.md).

### 1.2 L'assistant de bienvenue

Au premier lancement, un assistant en quatre étapes s'affiche :

1. **Bienvenue** — présentation rapide.
2. **Connectez votre manette** — en USB-C (immédiat) ou en Bluetooth :
   maintenez **Create + PS** jusqu'à ce que la barre lumineuse clignote,
   puis associez « DualSense Wireless Controller » dans les Réglages
   Bluetooth de macOS (bouton d'accès direct fourni). L'étape se valide
   d'elle-même dès que la manette est détectée.
3. **Autorisations macOS** — deux lignes avec statut en direct :
   - **Accessibilité** (obligatoire) : permet de simuler clavier, souris et
     défilement ;
   - **Surveillance de l'entrée** (optionnelle) : uniquement pour le bouton
     micro (mute).
   Les pastilles passent au vert dès l'octroi — aucun redémarrage. Voir
   [PERMISSIONS.md](PERMISSIONS.md) en cas de souci.
4. **Hammerspoon (optionnel)** — installation du Spoon en un clic si vous
   utilisez Hammerspoon (voir §2.5).

### 1.3 Premier contact

La manette connectée, le profil **« Défaut »** est actif :

- **stick gauche** → le pointeur bouge ;
- **✕** → clic gauche ; **○** → clic droit ;
- **stick droit** → défilement ;
- **pavé tactile** → trackpad (2 doigts = défilement, tap = clic) ;
- **△** → le clavier virtuel apparaît.

L'interrupteur **« Mappage »** (en haut à droite de la fenêtre, et dans la
barre des menus sous « Mappage actif ») est le coupe-circuit général : en le
désactivant, la manette redevient inerte pour macOS — pratique avant de
lancer un jeu qui gère la manette nativement.

---

## 2. Tour de l'interface

La fenêtre principale s'organise en deux zones : une **barre latérale** à
cinq sections (Manette, Profils, Clavier virtuel, Hammerspoon, Réglages) et
la page courante, surmontée d'un **bandeau permanent** :

- titre de l'app ;
- pastille de connexion — cliquez-la quand la manette est déconnectée pour
  afficher la marche à suivre d'association Bluetooth ;
- jauge de **batterie** (icône + pourcentage, éclair en charge, orange sous
  20 %, rouge sous 10 %) ;
- sélecteur du **profil actif** ;
- interrupteur **Mappage** (coupe-circuit général).

### 2.1 Page « Manette »

La page centrale : votre DualSense rendue à l'écran, avec un point d'accès
(« hotspot ») par contrôle. C'est ici que tout se configure :

- **Écho en direct** : appuyez physiquement sur un bouton — son hotspot
  s'illumine instantanément. Bougez un stick, pressez une gâchette, posez un
  doigt sur le pavé tactile : la page reflète l'état réel de la manette en
  permanence. C'est aussi le moyen le plus rapide de retrouver un contrôle :
  appuyez dessus, regardez ce qui s'allume.
- **Contrôles numériques** (✕ ○ □ △, croix directionnelle, L1/R1, L2/R2,
  L3/R3, Create, Options, PS, micro, clic du pavé) : cliquez le hotspot pour
  choisir l'action liée — raccourci clavier, texte, souris, action système,
  macro, commande shell, ouverture d'app/URL, événement Hammerspoon, ou
  action de l'app (clavier virtuel, profil suivant, ouvrir la fenêtre).
  Le catalogue complet des actions est en [§5.4](#54-catalogue-des-actions).
- **Contrôles analogiques** : chaque stick, chaque gâchette, la surface du
  pavé tactile et le gyroscope se configurent par **mode** plutôt que par
  action :

| Contrôle | Modes disponibles | Réglages |
|---|---|---|
| Stick gauche / droit | Pointeur souris · Défilement · Flèches du clavier · Touches ZQSD · Volume / Luminosité · Désactivé | zone morte (défaut 0,12), sensibilité (pointeur : px/s, défaut 900 ; défilement : lignes/s), courbe de réponse (Linéaire / Accélérée / Agressive), inversion Y |
| L2 / R2 (analogique) | Seuil d'activation | position de déclenchement 0–100 % (défaut 45 %, hystérésis anti-rebond) ; effet de gâchette adaptative : Aucun / Résistance légère / moyenne / forte / Clic (seuil) / Vibration |
| Surface du pavé tactile | Trackpad · Pointeur absolu · Gestes (Spaces) · Désactivé | sensibilité, tap = clic, défilement 2 doigts, défilement naturel |
| Gyroscope | Pointeur (gyro aiming) · Défilement · Désactivé | sensibilité ; bouton d'activation optionnel (le gyro ne pointe que pendant l'appui) |

  En mode **Gestes**, un balayage horizontal du pavé change d'espace
  (bureau ⌃← / ⌃→) et un balayage vertical ouvre Mission Control.
- **Retours** : la couleur de la **barre lumineuse** et l'intensité
  **haptique** appartiennent au profil — elles s'appliquent à la manette à
  chaque activation de profil (avec une brève impulsion de confirmation).
  La carte **« Retour haptique »** (sous le schéma de la manette) permet
  d'activer/désactiver les impulsions du profil et d'en régler l'intensité
  (0–100 %) ; la couleur de la barre lumineuse se choisit sur la carte du
  profil (page Profils).

Note L2/R2 : le déclenchement des actions liées à L2/R2 est piloté par le
**seuil analogique** (réglable), jamais par le contact numérique — vous
choisissez précisément à quelle profondeur de course la gâchette « clique ».

### 2.2 Page « Profils »

Un **profil** est une configuration complète de la manette : les liaisons de
tous les boutons, les modes des sticks/pavé/gyro, les seuils de gâchettes,
la couleur de barre lumineuse et l'intensité haptique.

- **Créer / dupliquer / renommer / supprimer** des profils à volonté (il en
  reste toujours au moins un — le profil par défaut se recrée si nécessaire).
- **Lier des applications** : associez un ou plusieurs identifiants d'apps à
  un profil ; quand l'option « Changer de profil automatiquement » est
  active (Réglages), le profil lié s'active dès que l'app passe au premier
  plan — et le profil de base revient ensuite. Exemple intégré : le profil
  « Multimédia » est lié à Spotify, Apple TV, Musique, IINA et VLC.
- **Changer à la main** : depuis le sélecteur du bandeau, le menu de la
  barre des menus, l'action « Profil suivant » liable à un bouton de la
  manette, ou l'URL `dualsenseremap://profile/next`.
- **Stockage** : JSON lisibles dans
  `~/Library/Application Support/DualSenseRemap/` (`profiles.json` et
  `settings.json`), sauvegardés automatiquement ~0,5 s après chaque
  modification. Copier ce dossier suffit pour sauvegarder ou transférer vos
  profils.

Deux profils sont fournis : **Défaut** (navigation macOS au canapé — table
complète en [§5.1](#51-profil--défaut)) et **Multimédia**
([§5.2](#52-profil--multimédia)).

### 2.3 Page « Clavier virtuel »

Page de configuration et d'aperçu du clavier AZERTY façon PS5 (le clavier
lui-même est un panneau flottant indépendant de la fenêtre — voir §3) :

- aperçu du clavier et de ses pages ;
- rappel des raccourcis manette ;
- réglages : **taille** du panneau (70–140 %), **retour haptique à la
  frappe** (tous deux aussi disponibles dans Réglages) et **envoi d'Entrée
  par OK (R2)** — activé par défaut, à désactiver si Entrée validerait un
  formulaire à contretemps.

Pour l'invoquer : **△** dans le profil par défaut, le menu de la barre des
menus (« Clavier virtuel »), l'action « Clavier virtuel » liable à n'importe
quel bouton, ou l'URL `dualsenseremap://keyboard/toggle`.

### 2.4 Page « Hammerspoon »

État de l'intégration [Hammerspoon](https://www.hammerspoon.org) et
installation du Spoon :

- **Statut** : « Installé » (vert) quand Hammerspoon.app est présent,
  « Non détecté » sinon (avec lien vers hammerspoon.org ;
  `brew install --cask hammerspoon`).
- **Installer le Spoon** : copie `DualSenseRemap.spoon` dans
  `~/.hammerspoon/Spoons/` et affiche les trois lignes à avoir dans
  `~/.hammerspoon/init.lua` :

  ```lua
  require("hs.ipc")
  hs.loadSpoon("DualSenseRemap")
  spoon.DualSenseRemap:start()
  ```

- **Utilisation** : liez l'action « Hammerspoon : NOM » à n'importe quel
  bouton — l'app envoie `hammerspoon://dsr?event=NOM` (sans jamais donner le
  focus à Hammerspoon). Les actions intégrées du Spoon sont listées en
  [§5.5](#55-actions-hammerspoon-du-spoon) ; ajoutez les vôtres via
  `spoon.DualSenseRemap.userHooks` :

  ```lua
  -- dans ~/.hammerspoon/init.lua, après :start()
  spoon.DualSenseRemap.userHooks["monAction"] = function(params)
    hs.alert.show("Bonjour depuis la manette !")
  end
  ```

  Un bouton lié à l'événement `monAction` déclenche alors ce Lua.
- **Sens inverse** : Hammerspoon peut piloter l'app —
  `spoon.DualSenseRemap:bindHotkeys({ toggleKeyboard = {{"cmd","alt"}, "k"} })`
  ouvre/ferme le clavier virtuel via `dualsenseremap://keyboard/toggle`.
- Sécurité : le Spoon ne fait qu'indexer une table d'actions autorisées —
  aucun Lua arbitraire ne transite par l'URL. Vos `userHooks` s'exécutent
  avec vos privilèges : n'y mettez que du code de confiance.

### 2.5 Page « Réglages »

Cartes, de haut en bas :

- **Général** — « Ouvrir DualSense Remap à la connexion » (élément de
  session macOS) ; « Afficher l'icône dans la barre des menus » ; « Changer
  de profil automatiquement selon l'application ».
- **Clavier virtuel** — taille du panneau (70–140 %) ; retour haptique à la
  frappe (petite vibration de la manette à chaque touche).
- **Autorisations** — statuts en direct d'Accessibilité (requise) et de
  Surveillance de l'entrée (optionnelle), avec boutons « Autoriser… » et
  « Réglages… » (lien direct vers le bon panneau de Réglages Système).
- **Hammerspoon** — statut + « Installer le Spoon » (identique à la page
  Hammerspoon).
- **À propos** — version, lien vers le code source.

### 2.6 La barre des menus

L'icône manette (🎮) vit dans la barre des menus (désactivable dans
Réglages). Son menu :

- ligne d'état : nom de la manette + batterie (« DualSense — 82 % ») ou
  « Manette non connectée » ;
- **Mappage actif** — le coupe-circuit général ;
- **Profils** — sous-menu de sélection du profil actif ;
- **Clavier virtuel** — afficher / masquer ;
- **Ouvrir DualSense Remap** — ramène la fenêtre principale ;
- **Quitter** (⌘Q).

Fermer la fenêtre principale ne quitte pas l'app : le moteur continue en
arrière-plan, piloté depuis la barre des menus.

---

## 3. Le clavier virtuel en détail

Un clavier AZERTY inspiré du clavier de la PS5, dans un panneau flottant en
bas de l'écran. Sa propriété essentielle : **il ne prend jamais le focus**.
L'application au premier plan garde son champ de saisie actif, et chaque
touche du clavier virtuel y est injectée directement (indépendamment de la
disposition clavier configurée dans macOS — les accents sortent justes même
sur un Mac en QWERTY).

Pendant que le clavier est visible, il est **modal pour la manette** : tous
les boutons lui sont réservés (les mappages du profil sont suspendus et
reprennent à la fermeture).

### 3.1 Raccourcis manette

| Manette | Effet |
|---|---|
| Croix dir. ↑ ↓ ← → | Déplacer le focus d'une touche (maintien : répétition ~0,35 s puis 12 pas/s) |
| Stick gauche | Identique à la croix (zone morte + hystérésis anti-tremblement) |
| ✕ (croix) | Appuyer la touche focalisée ; maintien = répétition automatique sur ⌫, espace, ◀ et ▶ |
| ○ (rond) | Fermer le clavier |
| △ (triangle) | **Espace**, quel que soit le focus |
| □ (carré) | **Effacer** (retour arrière), quel que soit le focus |
| L2 | **Maj** — appui bref : majuscule pour 1 lettre ; double appui (< 0,35 s) : verrouillage majuscules ; maintien : majuscule tant que la gâchette est tenue |
| L1 / R1 | Déplacer le **curseur de texte** ← / → dans l'app cible |
| R3 | Basculer vers/depuis la page **accents** |
| R2 | **OK** — envoie **Entrée** (⏎) puis ferme le clavier *(envoi d'Entrée désactivable, voir §2.3)* |

La touche ⇧ à l'écran suit le même cycle que L2 (appui : 1 lettre → appui :
verrouillage → appui : désactivé). La majuscule « pour une lettre » se
désactive d'elle-même après la lettre tapée ou au changement de page.

Navigation : le focus boucle horizontalement dans une rangée ; verticalement,
il choisit la touche dont le centre est le plus proche (avec « mémoire de
colonne » : ↓↓ puis ↑↑ revient sur la touche de départ). Les touches `ABC`,
`@#:` et `à` changent de page ; `1/2` ↔ `2/2` feuillette les symboles. Les
touches `•••` et 🎮 (rappel du raccourci L3+R3 de la PS5) sont décoratives
dans cette version.

### 3.2 Page lettres (AZERTY)

| | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **R1** | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 0 | @ |
| **R2** | a | z | e | r | t | y | u | i | o | p | # |
| **R3** | q | s | d | f | g | h | j | k | l | m | / |
| **R4** | w | x | c | v | b | n | ' | - | _ | ? | ! |

Avec Maj, les lettres passent en capitales ; chiffres et signes ne changent
pas.

Rangée fonctions : `⇧ (L2)` · `ABC` · `@#:` · `à (R3)` · `Espace (△)` ·
`⌫ (□)`. Rangée du bas : `◀ (L1)` · `▶ (R1)` · `•••` · `🎮 (L3+R3)` ·
`OK (R2)` — les pastilles indiquent le raccourci manette de chaque touche,
comme sur PS5.

### 3.3 Pages symboles

**Page 1/2 :**

| | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **R1** | € | $ | £ | ¥ | % | & | * | ( | ) | [ | ] |
| **R2** | @ | # | : | ; | " | ' | ` | ^ | ~ | \| | \\ |
| **R3** | + | - | × | ÷ | = | < | > | { | } | ° | § |
| **R4** | ! | ? | / | _ | , | . | … | « | » | ¿ | 2/2 |

**Page 2/2 :**

| | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **R1** | ¹ | ² | ³ | ¼ | ½ | ¾ | ± | µ | ‰ | ¢ | ¤ |
| **R2** | ‘ | ’ | “ | ” | ‚ | „ | ‹ | › | – | — | • |
| **R3** | © | ® | ™ | † | ‡ | ¶ | ≈ | ≠ | ≤ | ≥ | ∞ |
| **R4** | · | ¨ | ´ | ¸ | ª | º | ¦ | ¬ | ⁄ | ‾ | 1/2 |

La touche `1/2` / `2/2` (ou un nouvel appui sur `@#:`) feuillette les deux
pages. Maj est sans effet sur les symboles.

### 3.4 Page accents (R3)

Tout le français, minuscules **et** majuscules directement visibles — aucun
aller-retour Maj nécessaire :

| | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **R1** | à | â | ä | é | è | ê | ë | î | ï | ô | ö |
| **R2** | ù | û | ü | ç | œ | æ | ÿ | « | » | ’ | € |
| **R3** | À | Â | Ä | É | È | Ê | Ë | Î | Ï | Ô | Ö |
| **R4** | Ù | Û | Ü | Ç | Œ | Æ | Ÿ | ‘ | ” | “ | ° |

**R3** bascule vers la page accents depuis n'importe quelle page, et un
second appui revient à la page précédente.

### 3.5 Limites connues

- Les **champs de mot de passe** (saisie sécurisée macOS) peuvent ignorer le
  texte injecté — c'est une protection du système.
- La touche **OK (R2)** envoie Entrée puis ferme le clavier. Si Entrée
  validerait un formulaire à contretemps, désactivez « OK (R2) envoie Entrée
  avant de fermer » dans la page « Clavier virtuel » — OK se contentera alors
  de fermer le clavier.
- Le retour haptique à la frappe suit l'intensité haptique du profil actif
  (et l'interrupteur dédié dans Réglages).

---

## 4. Recettes

### 4.1 Multimédia au canapé (profil fourni)

Le profil **« Multimédia »** est déjà lié à Spotify, Apple TV, Musique, IINA
et VLC : ouvrez l'une de ces apps, il s'active tout seul (bascule
automatique activée par défaut). Table complète en
[§5.2](#52-profil--multimédia). En bref : ✕ = lecture/pause, □/△ =
piste précédente/suivante, croix ↑↓ = volume, croix ←→ = saut dans la
lecture, ○ = Échap (sortir du plein écran).

### 4.2 Naviguer le web depuis le canapé

Avec le profil « Défaut », sans rien configurer :

1. **Stick gauche** : pointez le lien ; **✕** : cliquez ; la précision près
   du centre est assurée par la courbe accélérée.
2. **Stick droit** ou **deux doigts sur le pavé tactile** : défilement de la
   page.
3. **L1 / R1** : onglet précédent / suivant ; **L2** : revenir à l'app
   précédente (⌘⇥).
4. Champ de recherche : **△** ouvre le clavier virtuel — tapez, puis **R2**
   (OK) pour valider la recherche (Entrée) et refermer le clavier.
5. **□** : Mission Control pour changer de fenêtre ; **R3** : Launchpad.

Astuce : dupliquez « Défaut » en profil « Canapé » et liez-le à Safari pour
personnaliser sans toucher au profil de base.

### 4.3 Présenter Keynote à la manette

Créez un profil « Présentation », liez-le à Keynote
(`com.apple.iWork.Keynote`) et mappez :

| Contrôle | Action | Effet dans Keynote |
|---|---|---|
| R1 | Raccourci → | Diapositive suivante |
| L1 | Raccourci ← | Diapositive précédente |
| △ | Raccourci B | Écran noir (pause) |
| □ | Raccourci W | Écran blanc |
| ○ | Raccourci ⎋ | Quitter la présentation |
| Stick gauche | Pointeur souris | Pointeur pendant la démo |
| R2 | Clic gauche | Lire une vidéo, cliquer un lien |
| Gyroscope | Pointeur (activation : maintenir R2 ou L2) | « Pointeur laser » en inclinant la manette |

Dès que Keynote passe au premier plan, le profil s'active — et se désactive
en revenant au bureau. Pensez à vérifier la batterie dans le bandeau avant
de commencer.

### 4.4 Accessibilité : la manette comme pointeur principal

Pour un usage confortable avec une motricité fine limitée :

- **Stick gauche → Pointeur souris** avec sensibilité réduite (300–500 px/s),
  **zone morte élargie** (0,2–0,3) et courbe **Accélérée** : stable au
  centre, rapide seulement en butée.
- **✕ → Clic gauche** et **R2 → Clic gauche** avec un **seuil bas** (20 %) :
  deux façons de cliquer, dont une gâchette très douce.
- **□ → Glisser (verrouillé)** : un appui prend l'élément, un second le
  relâche — aucun maintien nécessaire pour un glisser-déposer.
- **Gâchettes adaptatives → Clic (seuil)** : le cran physique confirme le
  déclenchement dans le doigt ; montez l'**intensité haptique** du profil
  (page Manette, carte « Retour haptique ») pour une confirmation tactile.
- Croix directionnelle → flèches, **△ → clavier virtuel** pour la saisie de
  texte, **L3 → Spotlight** pour tout lancer sans viser de petites cibles.

### 4.5 Fenêtres et Spaces avec Hammerspoon

Après `make spoon` et les trois lignes d'`init.lua` (§2.4) :

| Contrôle suggéré | Action Hammerspoon | Effet |
|---|---|---|
| Croix ← (profil dédié) | `windowLeft` | Fenêtre sur la moitié gauche |
| Croix → | `windowRight` | Fenêtre sur la moitié droite |
| Croix ↑ | `windowMax` | Fenêtre maximisée |
| Croix ↓ | `windowCenter` | Fenêtre centrée |
| L1 / R1 | `spaceLeft` / `spaceRight` | Espace précédent / suivant |
| □ | `typeClipboard` | Taper le presse-papiers (utile où ⌘V est bloqué) |

---

## 5. Toutes les tables de raccourcis

### 5.1 Profil « Défaut »

| Contrôle | Action |
|---|---|
| Stick gauche | Pointeur souris (sensibilité 900 px/s, courbe accélérée, zone morte 0,12) |
| Stick droit | Défilement (14 lignes/s, courbe accélérée) |
| Surface pavé tactile | Trackpad (sensibilité 2,4 ; tap = clic ; défilement 2 doigts, naturel) |
| Gyroscope | Désactivé |
| ✕ (croix) | Clic gauche |
| ○ (rond) | Clic droit |
| □ (carré) | Mission Control |
| △ (triangle) | Clavier virtuel |
| Croix dir. ↑ | Flèche ↑ |
| Croix dir. ↓ | Flèche ↓ |
| Croix dir. ← | Flèche ← |
| Croix dir. → | Flèche → |
| L1 | Onglet précédent (⌃⇧⇥) |
| R1 | Onglet suivant (⌃⇥) |
| L2 (seuil 45 %) | Sélecteur d'apps (⌘⇥) |
| R2 (seuil 45 %) | Clic gauche |
| L3 | Spotlight |
| R3 | Launchpad |
| Create | Capture d'écran (zone) |
| Options | Ouvrir DualSense Remap |
| Bouton PS | Launchpad |
| Micro (mute) | Volume muet *(autorisation « Surveillance de l'entrée » requise)* |
| Clic pavé tactile | Clic gauche |

### 5.2 Profil « Multimédia »

Lié à : Spotify (`com.spotify.client`), Apple TV (`com.apple.TV`), Musique
(`com.apple.Music`), IINA (`com.colliderli.iina`), VLC
(`org.videolan.vlc`).

| Contrôle | Action |
|---|---|
| ✕ (croix) | Lecture / Pause |
| ○ (rond) | Échap (⎋) |
| □ (carré) | Piste précédente |
| △ (triangle) | Piste suivante |
| Croix dir. ↑ | Volume + |
| Croix dir. ↓ | Volume − |
| Croix dir. ← | Flèche ← (reculer dans la lecture) |
| Croix dir. → | Flèche → (avancer dans la lecture) |
| L1 | Piste précédente |
| R1 | Piste suivante |
| Micro (mute) | Volume muet |
| Clic pavé tactile | Clic gauche |
| Options | Ouvrir DualSense Remap |
| Bouton PS | Clavier virtuel |
| Sticks / pavé | Comme les valeurs par défaut (pointeur / défilement / trackpad) |

### 5.3 Clavier virtuel

Voir la table complète en [§3.1](#31-raccourcis-manette), et les pages
touche par touche en §3.2–3.4.

### 5.4 Catalogue des actions

Chaque contrôle numérique peut être lié à :

| Catégorie | Actions |
|---|---|
| Clavier | Raccourci clavier (touche + ⌘ ⌥ ⌃ ⇧ fn) · Taper un texte |
| Souris | Clic gauche · Clic droit · Clic molette · Double-clic · Glisser (verrouillé) |
| Système | Launchpad · Mission Control · Fenêtres de l'app · Afficher le bureau · Spotlight · Sélecteur d'apps (⌘⇥) · Lecture/Pause · Piste suivante · Piste précédente · Volume + · Volume − · Volume muet · Luminosité + · Luminosité − · Capture d'écran (zone) · Verrouiller l'écran · Onglet suivant · Onglet précédent · Copier · Coller · Annuler |
| Hammerspoon | N'importe quel événement du Spoon ou `userHook` (§5.5) |
| Apps & commandes | Commande shell · Ouvrir une application · Ouvrir une URL |
| Macros | Séquence de raccourcis, textes et pauses |
| DualSense Remap | Clavier virtuel · Profil suivant · Ouvrir DualSense Remap |
| — | Aucune action |

### 5.5 Actions Hammerspoon du Spoon

URL émise par l'app : `hammerspoon://dsr?event=NOM[&paramètres]`.

| Action | Effet |
|---|---|
| `launchpad` | Ouvrir/fermer Launchpad |
| `missionControl` | Mission Control |
| `showDesktop` | Afficher le bureau |
| `appSwitcher` | Revenir à l'app précédente (⌘⇥) |
| `focusApp` | Lancer/activer une app (`bundle=` id, ou `app=` nom) |
| `windowLeft` / `windowRight` | Fenêtre active sur la moitié gauche / droite |
| `windowMax` | Maximiser la fenêtre active |
| `windowCenter` | Centrer la fenêtre active (moitié de l'écran) |
| `mediaPlayPause` / `mediaNext` / `mediaPrevious` | Contrôles média |
| `spaceLeft` / `spaceRight` | Espace (bureau) précédent / suivant |
| `typeClipboard` | Taper le contenu du presse-papiers |
| `reload` | Recharger la configuration Hammerspoon |
| *(vos noms)* | `spoon.DualSenseRemap.userHooks["nom"]` |

Note : un bouton de la manette lié à un événement Hammerspoon l'envoie **sans
paramètres**. Les actions paramétrées du Spoon (comme `focusApp`, qui exige
`bundle=` ou `app=`) ne font donc rien si elles sont liées directement —
enveloppez-les dans un `userHook` qui fournit les paramètres :

```lua
spoon.DualSenseRemap.userHooks["focusSafari"] = function()
  hs.application.launchOrFocusByBundleID("com.apple.Safari")
end
```

puis liez l'événement `focusSafari` à un bouton.

### 5.6 URL de pilotage de l'app

| URL | Effet |
|---|---|
| `dualsenseremap://keyboard/toggle` | Afficher/masquer le clavier virtuel |
| `dualsenseremap://keyboard/show` | Afficher le clavier virtuel |
| `dualsenseremap://keyboard/hide` | Masquer le clavier virtuel |
| `dualsenseremap://profile/next` | Activer le profil suivant |

Utilisables depuis Hammerspoon, un script shell (`open "dualsenseremap://…"`),
Raccourcis, etc.

---

*Un problème non couvert ici ? Consultez le [dépannage du README](../README.md#dépannage)
et [PERMISSIONS.md](PERMISSIONS.md).*
