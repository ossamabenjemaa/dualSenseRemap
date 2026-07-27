# DualSense Remap

> **Transformez votre manette PS5 DualSense en périphérique macOS complet.**

<!-- Badges (placeholders — remplacer <owner>/<repo> après publication) -->
![Build](https://img.shields.io/badge/build-GitHub_Actions-blue)
![Plateforme](https://img.shields.io/badge/macOS-13%2B-black)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Licence](https://img.shields.io/badge/licence-MIT-green)

DualSense Remap est une application macOS native (SwiftUI) qui fait de la
manette Sony PS5 DualSense un véritable périphérique d'entrée pour votre Mac :
pointeur, défilement, clavier, raccourcis système, profils par application —
avec le niveau de finition d'un Logi Options+. Sticks, gâchettes analogiques,
pavé tactile multitouch, gyroscope, barre lumineuse, retour haptique et
batterie : **tout** est exploité.

Depuis le canapé, pilotez Safari, Spotify ou Keynote ; tapez du texte avec un
clavier virtuel AZERTY façon PS5 ; déclenchez vos scripts Hammerspoon d'une
pression sur un bouton. Le tout sans toucher ni clavier ni souris.

---

## Fonctionnalités

- **Remappage complet de TOUS les contrôles** — ✕ ○ □ △, croix
  directionnelle, L1/R1, L2/R2 (numérique *et* seuil analogique réglable),
  L3/R3, Create, Options, bouton PS, bouton micro (mute), clic du pavé
  tactile. Chaque contrôle peut déclencher : raccourci clavier, texte, clic /
  double-clic / glisser verrouillé, action système (Mission Control,
  Spotlight, Launchpad, volume, luminosité, lecture/pause, capture d'écran,
  verrouillage…), macro, commande shell, ouverture d'app ou d'URL, événement
  Hammerspoon, ou action interne (clavier virtuel, profil suivant…).
- **Sticks analogiques configurables** — pointeur souris avec courbes de
  réponse (linéaire / accélérée / agressive), zone morte et sensibilité
  réglables ; défilement pixel par pixel ; flèches du clavier ; touches ZQSD ;
  molette volume / luminosité.
- **Pavé tactile = trackpad** — déplacement du pointeur à 1 doigt, défilement
  à 2 doigts, tap-to-click, défilement naturel ; mode pointeur absolu ; mode
  gestes (balayages pour changer d'espace, Mission Control).
- **Gyroscope** — pointez avec la manette (« gyro aiming ») avec bouton
  d'activation optionnel, ou défilement par inclinaison.
- **Gâchettes adaptatives** — effets de résistance L2/R2 par profil
  (légère, moyenne, forte, clic à seuil, vibration).
- **Barre lumineuse & haptique** — couleur de barre lumineuse par profil,
  impulsions haptiques de confirmation, intensité réglable.
- **Batterie** — niveau et état de charge en direct dans la fenêtre et la
  barre des menus.
- **Profils par application avec bascule automatique** — l'app au premier
  plan active son profil lié (Spotify → profil « Multimédia », etc.),
  persistés en JSON, profil par défaut toujours disponible.
- **Clavier virtuel PS5 AZERTY pilotable à la manette** — panneau flottant
  qui ne vole jamais le focus : le texte part directement dans l'app active.
  4 pages (lettres, symboles ×2, accents français complets), navigation
  croix/stick, raccourcis fidèles à la console (△ espace, □ effacer,
  L2 Maj, R2 OK…).
- **Intégration Hammerspoon bidirectionnelle** — un Spoon fourni
  (`DualSenseRemap.spoon`) reçoit les événements de la manette
  (`hammerspoon://dsr?event=…`) pour piloter fenêtres, Spaces et médias en
  Lua ; et Hammerspoon peut piloter l'app en retour via le schéma
  `dualsenseremap://` (afficher le clavier, changer de profil).
- **Barre des menus** — état de connexion et batterie, interrupteur général
  du mappage, changement de profil et clavier virtuel toujours à un clic.

## Captures

<!-- TODO: capture — page Manette (rendu + hotspots) -->
<!-- TODO: capture — clavier virtuel AZERTY au-dessus de Safari -->
<!-- TODO: capture — menu de la barre des menus -->
<!-- TODO: capture — page Profils -->

*(captures d'écran à venir)*

## Installation

### Prérequis

- macOS 13 (Ventura) ou plus récent
- Les outils en ligne de commande Xcode : `xcode-select --install`
  (ou Xcode complet)

### Compilation

```bash
git clone https://github.com/ossamabenjemaa/dualSenseRemap.git
cd dualSenseRemap
make app          # → dist/DualSense Remap.app
make install      # optionnel : copie dans /Applications
```

### Première ouverture

L'application est signée **ad hoc** (pas de certificat développeur). Au
premier lancement, macOS affiche un avertissement :

1. Dans le Finder, **clic droit** sur `DualSense Remap.app` ;
2. choisissez **« Ouvrir »**, puis confirmez **« Ouvrir »**.

Ce n'est nécessaire qu'une seule fois. Voir [docs/BUILD.md](docs/BUILD.md)
pour les autres modes de compilation (XcodeGen, `swift run`, artefacts CI).

## Autorisations

| Autorisation | Statut | Pourquoi |
|---|---|---|
| **Accessibilité** | **Obligatoire** | C'est elle qui permet de synthétiser clavier, souris et défilement (`CGEvent`). Sans elle, aucun mappage ne peut agir sur macOS. |
| **Surveillance de l'entrée** | Optionnelle | Uniquement pour lire le **bouton micro (mute)**, que le framework GameController n'expose pas (lecture HID directe). Tout le reste fonctionne sans. |

Chemins exacts dans Réglages Système :

- **Réglages Système → Confidentialité et sécurité → Accessibilité** →
  activer « DualSense Remap » ;
- **Réglages Système → Confidentialité et sécurité → Surveillance de
  l'entrée** → activer « DualSense Remap ».

L'assistant de premier lancement vous guide pas à pas et détecte l'octroi en
direct (aucun redémarrage nécessaire). Détails, réinitialisation `tccutil` et
FAQ : [docs/PERMISSIONS.md](docs/PERMISSIONS.md).

## Utilisation rapide — profil « Défaut »

Dès la première connexion, le profil intégré « Défaut » fait de la manette une
télécommande macOS complète :

| Contrôle | Action |
|---|---|
| Stick gauche | Pointeur souris (courbe accélérée) |
| Stick droit | Défilement |
| Surface du pavé tactile | Trackpad (1 doigt = pointeur, 2 doigts = défilement, tap = clic) |
| ✕ (croix) | Clic gauche |
| ○ (rond) | Clic droit |
| □ (carré) | Mission Control |
| △ (triangle) | Clavier virtuel (afficher / masquer) |
| Croix dir. ↑ ↓ ← → | Flèches du clavier ↑ ↓ ← → |
| L1 | Onglet précédent (⌃⇧⇥) |
| R1 | Onglet suivant (⌃⇥) |
| L2 (seuil 45 %) | Sélecteur d'apps (⌘⇥) |
| R2 (seuil 45 %) | Clic gauche |
| L3 (clic stick G) | Spotlight |
| R3 (clic stick D) | Launchpad |
| Create | Capture d'écran (zone) |
| Options | Ouvrir DualSense Remap |
| Bouton PS | Launchpad |
| Micro (mute) | Volume muet *(nécessite « Surveillance de l'entrée »)* |
| Clic pavé tactile | Clic gauche |

Le gyroscope est désactivé par défaut. Un second profil intégré,
« Multimédia », se lie automatiquement à Spotify, Apple TV, Musique, IINA et
VLC (✕ = lecture/pause, □/△ = piste précédente/suivante, croix dir. ↑↓ =
volume…).

## Clavier virtuel

Appuyez sur **△** (profil par défaut) : un clavier AZERTY façon PS5 apparaît
en bas de l'écran, **sans jamais voler le focus** — chaque caractère part
directement dans le champ actif de l'app au premier plan.

| Manette | Effet |
|---|---|
| Croix dir. / stick gauche | Déplacer le focus de touche |
| ✕ | Appuyer la touche (maintien : répétition sur ⌫, espace, ◀ ▶) |
| ○ | Fermer le clavier |
| △ | Espace |
| □ | Effacer (retour arrière) |
| L2 | Maj — appui : 1 lettre ; double appui : verrouillage ; maintien : momentané |
| L1 / R1 | Déplacer le curseur de texte ← / → dans l'app cible |
| R3 | Page accents (à â é è … + majuscules accentuées) |
| R2 | **OK** — ferme le clavier |

Quatre pages : lettres AZERTY + chiffres, symboles (2 pages), accents
français complets. Tableaux détaillés touche par touche dans le
[guide utilisateur](docs/USER_GUIDE_FR.md).

## Hammerspoon

Le Spoon fourni transforme la manette en télécommande
[Hammerspoon](https://www.hammerspoon.org) :

```bash
make spoon    # installe Hammerspoon/DualSenseRemap.spoon dans ~/.hammerspoon/Spoons/
```

Puis dans `~/.hammerspoon/init.lua` :

```lua
require("hs.ipc")
hs.loadSpoon("DualSenseRemap")
spoon.DualSenseRemap:start()
```

L'app envoie des URL `hammerspoon://dsr?event=NOM`. Actions intégrées au
Spoon : `launchpad`, `missionControl`, `showDesktop`, `appSwitcher`,
`focusApp` (paramètre `bundle` ou `app`), `windowLeft`, `windowRight`,
`windowMax`, `windowCenter`, `mediaPlayPause`, `mediaNext`, `mediaPrevious`,
`spaceLeft`, `spaceRight`, `typeClipboard`, `reload` — plus vos propres
crochets Lua via `spoon.DualSenseRemap.userHooks`.

En retour, Hammerspoon (ou n'importe quel script) peut piloter l'app :
`dualsenseremap://keyboard/toggle`, `keyboard/show`, `keyboard/hide`,
`profile/next`.

## Dépannage

**La manette n'est pas détectée**
1. Branchez-la en USB-C — la détection est immédiate ; ou
2. en Bluetooth : Réglages Système → Bluetooth, supprimez l'ancienne entrée
   « DualSense Wireless Controller » ; sur la manette, maintenez **Create +
   PS** jusqu'à ce que la barre lumineuse clignote ; associez à nouveau.
3. L'app lance en continu la recherche de manettes sans fil dès son
   démarrage — laissez-la ouverte pendant l'association.

**Les autorisations ne « prennent » pas**
La signature ad hoc change à chaque recompilation, ce qui peut invalider
l'octroi précédent. Réinitialisez puis ré-accordez :

```bash
tccutil reset Accessibility com.dualsenseremap.app
tccutil reset ListenEvent com.dualsenseremap.app   # Surveillance de l'entrée
```

Puis relancez l'app et ré-accordez dans Réglages Système (au besoin,
supprimez l'entrée avec « − » avant de la recréer). Détails :
[docs/PERMISSIONS.md](docs/PERMISSIONS.md).

**Le clavier virtuel ne tape rien**
Vérifiez que **Accessibilité** est accordée (Réglages Système →
Confidentialité et sécurité → Accessibilité) — la page Réglages de l'app
affiche le statut en direct. Notez aussi que les champs de mot de passe
(saisie sécurisée) peuvent bloquer l'injection de texte.

## Architecture

Vue d'ensemble des modules (Input / Engine / Output / VirtualKeyboard / UI),
contrats publics et flux de données :
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Crédits

- Inspiré par l'expérience utilisateur de **Logi Options+**, et par les
  remappers **ReControl** et **JoyMapper** sur macOS.
- Merci à la communauté (SDL, DS4Windows, Hammerspoon) pour la documentation
  du protocole HID de la DualSense.
- Ce projet est **indépendant et non affilié à Sony Interactive
  Entertainment**. « DualSense » et « PlayStation » sont des marques de Sony
  Interactive Entertainment Inc.
