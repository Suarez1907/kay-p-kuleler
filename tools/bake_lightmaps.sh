#!/usr/bin/env bash
# LightmapGI toplu fırınlama (Godot 4.8 betiklere bake() açmaz; editörün "Bake Lightmaps" düğmesi
# addons/kk_lightmap_baker eklentisiyle sürülür). Vulkan gerekir: GPU yoksa yazılımsal lavapipe
# (apt-get install mesa-vulkan-drivers) ve ekransız X (xvfb-run) yeterli.
#   tools/bake_lightmaps.sh 1-10          # seviye 1–10
#   tools/bake_lightmaps.sh assembly      # atölye
#   tools/bake_lightmaps.sh all           # bake_all_100_levels: atölye + 100 seviye
set -euo pipefail
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
P="$ROOT/godot-program"
spec="${1:-1-10}"
[ "$spec" = "all" ] && spec="assembly,1-100"
cd "$P"
"$GODOT" --headless --path . -- --bakegen="$spec" | grep bakegen
list=""
IFS=',' read -ra parts <<< "$spec"
for part in "${parts[@]}"; do
  if [ "$part" = "assembly" ]; then
    list="$list,res://scenes/baked/assembly_workshop.tscn"
  elif [[ "$part" == *-* ]]; then
    for k in $(seq "${part%-*}" "${part#*-}"); do list="$list,$(printf 'res://scenes/baked_levels/level_%03d.tscn' "$k")"; done
  else
    list="$list,$(printf 'res://scenes/baked_levels/level_%03d.tscn' "$part")"
  fi
done
KK_BAKE="${list#,}" xvfb-run -a -s "-screen 0 1600x1000x24" "$GODOT" --editor --path . --rendering-driver vulkan 2>&1 \
  | grep -E "KK_BAKE|Done baking" || true
