# FPS / frametime MangoHud → carte « Moniteur système » de Plasma

Affiche FPS et frametime dans une carte native du Moniteur système de KDE
Plasma 6, sans overlay sur le jeu.

**Fonctionnement :** le fork de MangoHud (branche `stats-export`) écrit un JSON
toutes les 500 ms. Le plugin
[ksystemstats_scripts](https://github.com/KerJoe/ksystemstats_scripts) lance
`mangohud.py`, qui expose ces valeurs comme capteurs. Le widget natif les affiche.

Testé uniquement sur CachyOS + Plasma 6.

## Installation

```bash
git clone --depth 1 -b stats-export https://github.com/Amenothes/FPS_plasmoid.git ~/dev/MangoHud
cd ~/dev/MangoHud
bash widget/install.sh
```

Pour les jeux 32 bits : `bash widget/install.sh --with-32bit`.

Le script installe les dépendances, construit et installe le plugin
`ksystemstats_scripts`, compile le fork dans `~/.local`, et copie le capteur.

Attention : le fork remplace le MangoHud système pour l'utilisateur (le layer
Vulkan de `~/.local/share/vulkan/implicit_layer.d/` est lu avant celui de
`/usr/share`). Sans `export_file` dans la config, le comportement est celui
d'upstream. Retour en arrière :

```bash
rm -rf ~/.local/lib/mangohud ~/.local/share/vulkan/implicit_layer.d/MangoHud* ~/.local/bin/mangohud
```

## Widget

Clic droit sur le bureau > Ajouter des widgets > Moniteur système.
Graphe : capteur `fps` (préfixe MangoHud). Texte : `frametime`.
Si le capteur n'apparaît pas, fermer et rouvrir la fenêtre de configuration.

## Variables d'environnement du jeu

```
MANGOHUD=1
MANGOHUD_CONFIG=export_file=/home/UTILISATEUR/.cache/mangohud-stats,no_display=1
```

Le chemin doit être dans `$HOME` (pressure-vessel isole `/run/user`).

Jeu à `HOME` isolé (`start.sh`, lancement portable) : le loader Vulkan ne voit
pas `~/.local/share/vulkan`. Ajouter :

```
XDG_DATA_HOME=/home/UTILISATEUR/.local/share
```

## Dépannage

Vérifier quelle bibliothèque le jeu a chargée (jeu lancé), dans bash :

```bash
for p in $(grep -l libMangoHud /proc/*/maps 2>/dev/null | cut -d/ -f3); do echo "== $p: $(tr "\0" " " < /proc/$p/cmdline | cut -c1-80)"; grep -o "[^ ]*libMangoHud[^ ]*" /proc/$p/maps | sort -u; done
```

Le processus du jeu doit pointer vers `~/.local/lib/mangohud/` (ou `lib32/`) et
non vers `/run/host/usr/lib/...` (MangoHud système, qui ignore `export_file`).
Un jeu 32 bits sans build 32 bits retombe sur le MangoHud système.

Le fichier d'export doit être rafraîchi toutes les 500 ms :

```bash
stat -c '%y %s' ~/.cache/mangohud-stats; cat ~/.cache/mangohud-stats
```

Après une mise à jour majeure de Plasma, le plugin peut casser (ABI de
libksysguard) : refaire `makepkg -si` dans `~/ksystemstats_scripts`.

## Limites connues

- Deux jeux simultanés écrivent dans le même fichier : le dernier gagne.
- Le capteur retombe à 0 si le fichier n'a pas été écrit depuis 2 s.
