#!/usr/bin/env bash
# Installe le fork MangoHud (export FPS/frametime) et le capteur ksystemstats.
# Usage : bash widget/install.sh [--with-32bit]
set -euo pipefail

WITH_32=0
[ "${1:-}" = "--with-32bit" ] && WITH_32=1

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_DIR="$HOME/ksystemstats_scripts"
STUBS="$HOME/.cache/mangohud-lib32-stubs"

info() { printf '\n==> %s\n' "$*"; }
die()  { printf 'ERREUR : %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "ne pas lancer en root (sudo est appelé quand il faut)"
command -v pacman >/dev/null || die "script prévu pour Arch / CachyOS (pacman introuvable)"
[ -f "$REPO/src/stats_export.cpp" ] || die "ce script doit rester dans widget/ du dépôt cloné (branche stats-export)"

info "1/5 Dépendances de compilation"
sudo pacman -S --needed base-devel git meson ninja glslang vulkan-headers \
  python-mako pkgconf cmake wayland-protocols yaml-cpp extra-cmake-modules
if [ "$WITH_32" -eq 1 ]; then
  sudo pacman -S --needed lib32-gcc-libs lib32-glibc lib32-libx11 lib32-libxcb \
    lib32-libxkbcommon lib32-wayland lib32-vulkan-icd-loader lib32-mesa \
    lib32-libdrm lib32-dbus
fi

info "2/5 Plugin ksystemstats_scripts"
if pacman -Q ksystemstats_scripts >/dev/null 2>&1; then
  echo "déjà installé"
else
  [ -d "$PLUGIN_DIR/.git" ] || git clone https://github.com/KerJoe/ksystemstats_scripts.git "$PLUGIN_DIR"
  (cd "$PLUGIN_DIR" && makepkg -si)
fi

info "3/5 Fork MangoHud 64 bits"
cd "$REPO"
OPTS=(--prefix="$HOME/.local" -Dwith_mangohud_next=false -Dwith_server=false)
if [ -f build/build.ninja ]; then
  meson setup --reconfigure build "${OPTS[@]}"
else
  meson setup build "${OPTS[@]}"
fi
meson compile -C build
meson install -C build

build_32() {
  # libcap n'existe pas en 32 bits sur Arch : stub statique, utilisé seulement
  # par du code Intel de mangohud-next, jamais exécuté.
  mkdir -p "$STUBS/lib/pkgconfig"
  cat > "$STUBS/capstub.c" << 'EOF'
#include <stddef.h>
void *cap_get_proc(void) { return NULL; }
int cap_get_flag(void *c, int cap, int t, int *v) { if (v) *v = 0; return 0; }
int cap_free(void *p) { return 0; }
EOF
  gcc -m32 -fPIC -c "$STUBS/capstub.c" -o "$STUBS/capstub.o"
  ar rcs "$STUBS/lib/libcap.a" "$STUBS/capstub.o"
  cat > "$STUBS/lib/pkgconfig/libcap.pc" << EOF
prefix=$STUBS
libdir=\${prefix}/lib
Name: libcap
Description: stub 32 bits pour build MangoHud
Version: 2.78
Libs: -L\${libdir} -lcap
Cflags: -I/usr/include
EOF
  (
    cd "$REPO"
    export CC="gcc -m32" CXX="g++ -m32" LDFLAGS=-m32
    unset PKG_CONFIG_PATH
    export PKG_CONFIG_LIBDIR="$STUBS/lib/pkgconfig:/usr/lib32/pkgconfig:/usr/share/pkgconfig"
    rm -rf build/meson32
    meson setup build/meson32 --prefix="$HOME/.local" --libdir lib/mangohud/lib32 \
      -Dappend_libdir_mangohud=false -Dwith_mangohud_next=false -Dwith_server=false
    meson compile -C build/meson32
    meson install -C build/meson32
  )
  if ldd "$HOME/.local/lib/mangohud/lib32/libMangoHud.so" | grep -q libcap; then
    echo "ATTENTION : la lib 32 bits dépend encore d'une libcap dynamique." >&2
  fi
}

if [ "$WITH_32" -eq 1 ]; then
  info "4/5 Fork MangoHud 32 bits"
  build_32
else
  info "4/5 Build 32 bits ignorée (relancer avec --with-32bit pour les jeux 32 bits)"
fi

info "5/5 Capteur ksystemstats"
mkdir -p "$HOME/.local/share/ksystemstats-scripts"
install -m755 "$REPO/widget/mangohud.py" "$HOME/.local/share/ksystemstats-scripts/mangohud.py"
systemctl --user restart plasma-ksystemstats.service

cat << EOF

Terminé. Reste à faire à la main :

1. Clic droit sur le bureau > Ajouter des widgets > Moniteur système.
   Graphe : capteur fps (préfixe MangoHud). Texte : frametime.

2. Dans les variables d'environnement de chaque jeu (Faugus / Steam) :
     MANGOHUD=1
     MANGOHUD_CONFIG=export_file=$HOME/.cache/mangohud-stats,no_display=1

3. Jeu à HOME isolé (start.sh, lancement portable), ajouter aussi :
     XDG_DATA_HOME=$HOME/.local/share

Après une grosse mise à jour de Plasma, refaire "makepkg -si" dans $PLUGIN_DIR.
EOF
