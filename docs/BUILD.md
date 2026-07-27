# Compiler DualSense Remap

Ce document décrit toutes les façons de compiler et lancer l'application.
La voie canonique est **SwiftPM + `make app`** — aucun projet Xcode n'est
nécessaire.

## Prérequis

| Outil | Version | Installation |
|---|---|---|
| macOS | 13 (Ventura) minimum | — |
| Swift toolchain | 5.9+ | `xcode-select --install` (Command Line Tools) ou Xcode 15+ |
| XcodeGen *(optionnel)* | dernière | `brew install xcodegen` |

Vérification rapide :

```bash
swift --version    # doit afficher Swift 5.9 ou plus récent
```

## 1. Voie canonique — SwiftPM + bundle `.app`

```bash
git clone https://github.com/ossamabenjemaa/dualSenseRemap.git
cd dualSenseRemap
make app
```

`make app` exécute `Scripts/bundle.sh`, qui :

1. compile en release : `swift build -c release` ;
2. assemble `dist/DualSense Remap.app` :
   - `Contents/MacOS/DualSenseRemap` — le binaire de `.build/release/` ;
   - `Contents/Info.plist` — copié depuis `Resources/Info.plist` ;
   - `Contents/PkgInfo` — `APPL????` ;
   - `Contents/Resources/DualSenseRemap.spoon` — le Spoon Hammerspoon
     embarqué (utilisé par le bouton « Installer le Spoon » de l'app) ;
3. signe le bundle **ad hoc** : `codesign --force --deep --sign -`.

Pourquoi un bundle `.app` et pas un binaire nu ? macOS attribue les
autorisations TCC (Accessibilité, Surveillance de l'entrée) à l'identité de
l'application. Un binaire lancé depuis le Terminal verrait les autorisations
attribuées… au Terminal. Voir [PERMISSIONS.md](PERMISSIONS.md).

Installation dans `/Applications` :

```bash
make install     # ditto "dist/DualSense Remap.app" /Applications/
```

Autres cibles Make (`make help` pour la liste) :

| Cible | Effet |
|---|---|
| `make build` | Compilation debug (`swift build`) |
| `make release` | Compilation release seule (sans bundle) |
| `make app` | Bundle complet `dist/DualSense Remap.app` |
| `make run` | `swift run` (développement, voir §3) |
| `make install` | `make app` + copie dans `/Applications` |
| `make spoon` | Installe le Spoon dans `~/.hammerspoon/Spoons/` |
| `make clean` | Supprime `.build/` et `dist/` |

## 2. Alternative — XcodeGen

Pour travailler dans Xcode (débogueur, Instruments…) :

```bash
brew install xcodegen
xcodegen generate
open DualSenseRemap.xcodeproj
```

`project.yml` décrit une cible application `DualSenseRemap` (macOS 13.0,
`PRODUCT_BUNDLE_IDENTIFIER=com.dualsenseremap.app`, signature automatique)
qui référence le même `Resources/Info.plist` que le bundle SwiftPM
(via `INFOPLIST_FILE` — XcodeGen ne le régénère jamais).

Compilation en ligne de commande via le projet généré :

```bash
xcodebuild -project DualSenseRemap.xcodeproj \
           -scheme DualSenseRemap \
           -configuration Release build
```

Avantage notable : si vous disposez d'un certificat « Apple Development »,
Xcode signe l'app avec une identité **stable**, et les autorisations TCC
survivent aux recompilations (contrairement à la signature ad hoc).

## 3. Développement rapide — `swift run`

```bash
swift run        # ou: make run
```

Pratique pour itérer sur l'UI, avec deux limites :

- le processus est attribué au **Terminal** pour les autorisations TCC :
  l'injection clavier/souris ne fonctionnera que si le Terminal lui-même a
  l'autorisation Accessibilité ;
- pas de `Info.plist` embarqué, donc pas de schéma d'URL `dualsenseremap://`
  ni d'identité d'app propre.

Pour tester le comportement réel (autorisations, URL scheme, barre des
menus), utilisez toujours `make app`.

## 4. Intégration continue

Le workflow GitHub Actions [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)
(« Build ») s'exécute sur chaque push (toutes branches) et manuellement
(`workflow_dispatch`), sur un runner `macos-15` :

1. `swift --version`
2. `swift build -c release` (journal conservé dans `build.log`)
3. `make app`
4. compression `ditto -c -k` puis publication de l'artefact
   **DualSense-Remap.app** (zip du bundle).

Pour récupérer une build sans compiler : onglet **Actions** du dépôt →
choisir un run vert → section **Artifacts** → télécharger
`DualSense-Remap.app`, dézipper, puis clic droit → « Ouvrir » (signature
ad hoc, voir README).

## Dépannage de compilation

- **`error: cannot find 'swift'`** — installez les Command Line Tools :
  `xcode-select --install`.
- **Anciennes toolchains** — le manifeste demande `swift-tools-version:5.9` ;
  Xcode 15 ou plus récent est requis.
- **Binaire introuvable dans `bundle.sh`** — vérifiez que
  `swift build -c release` a réussi ; le binaire attendu est
  `.build/release/DualSenseRemap`.
