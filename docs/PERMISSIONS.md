# Autorisations macOS

DualSense Remap agit sur votre Mac (clics, frappes, défilement) : macOS exige
donc des autorisations explicites, gérées par le système TCC (« Transparency,
Consent and Control »). Cette page explique **quoi accorder, pourquoi, et
comment réparer** quand quelque chose coince.

## Quelle fonctionnalité exige quelle autorisation ?

| Fonctionnalité | Autorisation | API sous-jacente |
|---|---|---|
| Synthèse clavier / souris / défilement (tous les mappages, clavier virtuel, macros) | **Accessibilité** (obligatoire) | `AXIsProcessTrustedWithOptions` + `CGEvent.post` |
| Bouton **micro (mute)** de la manette | **Surveillance de l'entrée** (optionnelle) | `IOHIDManager` (lecture HID directe, vendor `0x054C` / product `0x0CE6`) — `IOHIDCheckAccess` / `IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)` |
| Lecture de la manette (boutons, sticks, pavé tactile, gyro), barre lumineuse, gâchettes adaptatives, haptique, batterie | **Aucune** | Framework GameController |
| Bascule de profil selon l'app au premier plan | Aucune | `NSWorkspace.didActivateApplicationNotification` |
| Intégration Hammerspoon | Aucune côté DualSense Remap (Hammerspoon a besoin de **sa propre** autorisation Accessibilité) | URL `hammerspoon://` |

À retenir : **sans Accessibilité, rien ne peut agir sur macOS**. Sans
Surveillance de l'entrée, tout fonctionne sauf le bouton micro.

## Accorder les autorisations, pas à pas

L'assistant de premier lancement fait tout cela pour vous (les statuts se
mettent à jour en direct, sans redémarrage). Manuellement :

### Accessibilité (obligatoire)

1. Lancez DualSense Remap (depuis `dist/` ou `/Applications`).
2. Au premier mappage, macOS affiche la demande d'accès Accessibilité —
   cliquez « Ouvrir Réglages Système ». Sinon : **Réglages Système →
   Confidentialité et sécurité → Accessibilité**.
3. Activez l'interrupteur en face de **DualSense Remap** (déverrouillez avec
   le cadenas si besoin).
4. Revenez dans l'app : la page **Réglages** affiche « Accordée » en vert
   (sondage toutes les 2 s — aucun redémarrage nécessaire).

### Surveillance de l'entrée (optionnelle — bouton micro)

1. Dans l'app : **Réglages → Autorisations → Surveillance de l'entrée →
   Autoriser…** (ou directement **Réglages Système → Confidentialité et
   sécurité → Surveillance de l'entrée**).
2. Activez **DualSense Remap**.
3. macOS peut proposer de relancer l'app — acceptez.

Liens directs utilisés par l'app (utilisables aussi en `open …` dans le
Terminal) :

```
x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility
x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent
```

## Réinitialiser une autorisation (tccutil)

Quand un octroi semble « cassé » (l'interrupteur est vert mais rien ne se
passe), réinitialisez l'entrée TCC puis ré-accordez :

```bash
# Accessibilité
tccutil reset Accessibility com.dualsenseremap.app

# Surveillance de l'entrée
tccutil reset ListenEvent com.dualsenseremap.app

# Ou tout réinitialiser pour l'app :
tccutil reset All com.dualsenseremap.app
```

Relancez ensuite l'application et accordez à nouveau. Si l'entrée reste
grisée ou en double dans Réglages Système, sélectionnez-la et supprimez-la
avec le bouton « − », puis relancez l'app pour qu'elle se ré-enregistre.

### Pourquoi ça casse ? La signature ad hoc

Les octrois TCC sont liés à **l'identité de signature du code + le bundle
ID**. Les builds locales sont signées *ad hoc* (`codesign --sign -`), et
cette identité **change à chaque recompilation** : après un `make app`,
macOS peut considérer qu'il s'agit d'une app différente et ignorer l'ancien
octroi silencieusement. D'où la procédure `tccutil reset` ci-dessus.

Pour développer confortablement : signez avec un certificat « Apple
Development » stable (via le projet XcodeGen, voir
[BUILD.md](BUILD.md#2--alternative--xcodegen)) — les octrois survivent alors
aux recompilations.

## FAQ

**Pourquoi l'app n'est-elle pas sandboxée / sur l'App Store ?**
Le cœur de l'app est l'injection d'événements `CGEvent` vers *les autres
applications* (c'est ainsi qu'un bouton de manette devient un clic ou un
raccourci). Cette capacité est incompatible avec l'App Sandbox exigée par le
Mac App Store — comme tous les remappers (Karabiner-Elements, BetterTouchTool,
etc.), DualSense Remap est donc distribué hors App Store, non sandboxé.

**Pourquoi « Surveillance de l'entrée » alors que la manette est déjà lue ?**
GameController ne demande aucune autorisation, mais il n'expose pas le bouton
micro. Pour lui, l'app ouvre le périphérique HID en direct — et l'ouverture
d'un périphérique HID exige « Surveillance de l'entrée » depuis macOS 10.15.
Refuser cette autorisation ne désactive **que** le bouton micro.

**DualSense Remap lit-il mon clavier ou ma souris ?**
Non. L'app n'installe aucun « event tap » d'écoute : elle lit uniquement la
manette (GameController + le périphérique HID DualSense) et *émet* des
événements. Aucune frappe de votre clavier physique n'est observée, rien ne
quitte votre Mac.

**Faut-il redémarrer après avoir accordé ?**
Non. L'app sonde les octrois toutes les 2 secondes et les pastilles de statut
basculent en direct. Seule exception : macOS lui-même propose parfois de
relancer l'app après l'octroi de « Surveillance de l'entrée » — acceptez.

**Un binaire `swift run` peut-il recevoir les autorisations ?**
Mal : le processus est rattaché au Terminal (« responsible process »), et
c'est le Terminal qui doit alors être autorisé. Utilisez le bundle
`make app` pour un comportement TCC propre.
