# FPS / frametime MangoHud → widget Plasma

Affiche les FPS et le frametime dans une carte « Moniteur système » de KDE
Plasma, sans overlay sur le jeu.

MangoHud (branche `stats-export` de ce fork) écrit un JSON toutes les 500 ms.
`mangohud.py` l'expose comme capteur ksystemstats, et le widget natif l'affiche.

## 1. Compiler le fork (64 bits)

```bash
git clone -b stats-export https://github.com/Amenothes/FPS_plasmoid.git MangoHud
cd MangoHud
meson setup build --prefix=$HOME/.local -Dwith_mangohud_next=false -Dwith_server=false
meson compile -C build
meson install -C build
```

Attention : le fork remplace le MangoHud système (le layer Vulkan de
`~/.local/share/vulkan/implicit_layer.d/` est lu avant celui de `/usr/share`).

## 2. Jeux 32 bits (build séparée)

Un jeu 32 bits charge `lib32`, donc il faut compiler aussi en 32 bits, dans
**bash**. `libcap` n'a pas de version 32 bits sur Arch/CachyOS : on fournit un
stub statique (il ne sert qu'au code Intel de `mangohud-next`).

```bash
mkdir -p ~/dev/lib32-stubs/lib/pkgconfig
printf '#include <stddef.h>\nvoid *cap_get_proc(void){return NULL;}\nint cap_get_flag(void *c,int cap,int t,int *v){if(v)*v=0;return 0;}\nint cap_free(void *p){return 0;}\n' > /tmp/capstub.c
gcc -m32 -fPIC -c /tmp/capstub.c -o /tmp/capstub.o
ar rcs ~/dev/lib32-stubs/lib/libcap.a /tmp/capstub.o
printf 'prefix=%s/dev/lib32-stubs\nlibdir=${prefix}/lib\nName: libcap\nDescription: stub 32 bits\nVersion: 2.78\nLibs: -L${libdir} -lcap\n' "$HOME" > ~/dev/lib32-stubs/lib/pkgconfig/libcap.pc

cd ~/dev/MangoHud
export CC="gcc -m32" CXX="g++ -m32" LDFLAGS=-m32
unset PKG_CONFIG_PATH
export PKG_CONFIG_LIBDIR=$HOME/dev/lib32-stubs/lib/pkgconfig:/usr/lib32/pkgconfig:/usr/share/pkgconfig
meson setup build/meson32 --prefix=$HOME/.local --libdir lib/mangohud/lib32 \
  -Dappend_libdir_mangohud=false -Dwith_mangohud_next=false -Dwith_server=false
meson compile -C build/meson32
meson install -C build/meson32
```

## 3. Capteur ksystemstats

```bash
mkdir -p ~/.local/share/ksystemstats-scripts
cp widget/mangohud.py ~/.local/share/ksystemstats-scripts/
chmod +x ~/.local/share/ksystemstats-scripts/mangohud.py
systemctl --user restart plasma-ksystemstats.service
```

Puis : clic droit sur le bureau → Ajouter des widgets → Moniteur système.
Graphe : capteur `fps` (préfixe MangoHud). Texte : `frametime`.

## 4. Variables d'environnement du jeu

```
MANGOHUD=1
MANGOHUD_CONFIG=export_file=/home/UTILISATEUR/.cache/mangohud-stats,no_display=1
```

Le chemin doit être dans `$HOME` (pressure-vessel isole `/run/user`).

Jeu avec un `HOME` isolé (lancement portable, `start.sh`) : le loader Vulkan ne
voit pas `~/.local/share/vulkan`. Ajouter :

```
XDG_DATA_HOME=/home/UTILISATEUR/.local/share
```

## Dépannage

Vérifier quelle bibliothèque le jeu a chargée (jeu lancé) :

```bash
for p in $(grep -l libMangoHud /proc/*/maps 2>/dev/null | cut -d/ -f3); do echo "== $p: $(tr "\0" " " < /proc/$p/cmdline | cut -c1-80)"; grep -o "[^ ]*libMangoHud[^ ]*" /proc/$p/maps | sort -u; done
```

Le processus du jeu doit pointer vers `~/.local/lib/mangohud/` (ou `lib32/`),
pas vers `/run/host/usr/lib/...` (MangoHud système, qui ignore `export_file`).

## Limite connue

Deux jeux lancés en même temps écrivent dans le même fichier : le dernier gagne.
