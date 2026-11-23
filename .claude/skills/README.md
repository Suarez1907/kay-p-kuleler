# Proje skill'leri

[gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills)
(Apache-2.0, `GAMEDEV-SKILLS-LICENSE` / `GAMEDEV-SKILLS-NOTICE`) paketinden bu oyuna uyan alt küme:

* `gamedev-router` (paketin `router` skill'i; yalnızca aşağıdakiler kurulu, diğer motorlara yönlendirdiği skill'ler yok)
* Godot: `godot-gdscript`, `godot-nodes-scenes`, `godot-signals-groups`, `godot-ui-control`, `godot-animation`,
  `godot-shaders`, `godot-3d-essentials`, `godot-resources`, `godot-audio`, `godot-export`, `godot-gdscript-headless-testing`
* Disiplin: `game-ui-ux`, `game-feel`, `level-design`, `audio-design`, `performance-optimization`, `shader-programming`
* Tür: `puzzle-design` (paketin `genres/puzzle` skill'i)

Paketin denetleyicileri bu projede (salt okunur) çalıştırıldı:

    python3 -I .claude/skills/godot-nodes-scenes/scripts/check_godot_project.py godot-program   # 0 hata
    godot --headless --path godot-program --script <mutlak yol>/godot-gdscript/assets/check_scripts_compile.gd   # 0 bozuk
    godot --headless --path godot-program --script <mutlak yol>/godot-audio/assets/check_audio_buses.gd         # 0 bilinmeyen yol
