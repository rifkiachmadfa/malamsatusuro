#!/usr/bin/env python3
"""Rakit harness: sematkan source ASLI repo + mutasi opsional, jalankan dengan luau CLI.
Pemakaian: gen.py <repo_root> <luau_bin> [mutasi...]
Mutasi dikenali: M1..M6 (lihat MUTATIONS)."""
import subprocess, sys, pathlib

repo = pathlib.Path(sys.argv[1])
luau = sys.argv[2]
mut_names = sys.argv[3:]
here = pathlib.Path(__file__).parent

FILES = [
    "shared/Config/GameConfig", "shared/Config/QuestConfig", "shared/Config/CollectionConfig",
    "shared/Config/ItemConfig", "shared/Util/Log", "shared/Util/Spatial",
    "server/Config/GhostConfig", "server/Config/FailureConfig", "server/Config/KnockConfig",
    "server/Services/GameManager", "server/Services/QuestService", "server/Services/CollectibleService",
    "server/Services/FailureService", "server/Services/GhostService", "server/Services/PartyService",
    "server/Ghosts/Kuntilanak",
]

MUTATIONS = {
    "M1": ("server/Ghosts/Kuntilanak", "if other ~= target then", "if false then"),
    "M2": ("server/Ghosts/Kuntilanak", "stolen = CollectibleService.returnToWorld(bindings.collectionId, owned)", "stolen = 0"),
    "M3": ("server/Config/FailureConfig", "GHOST_KUNTILANAK = true,", "GHOST_KUNTILANAK = false,"),
    "M4": ("server/Ghosts/Kuntilanak", "\t\tand ItemService.count(player, itemId) > 0\n", ""),
    "M5": ("server/Services/CollectibleService", "if QuestService.removeProgress(config.questId, counterId, #created) == nil then", "if false then"),
    "M6": ("server/Ghosts/Kuntilanak",
           "-- Dijalankan lewat task.spawn: periksa ulang state. Pickup terakhir (4/4) sudah memindahkan quest ke KELOR_COMPLETE.\n\t\tif QuestService.getState(def.questId) ~= bindings.activeState then",
           "-- MUTASI\n\t\tif false then"),
    "M7": [
        ("server/Ghosts/Kuntilanak", "\t\tand GameManager.getPlayerState(player) == PlayerState.NORMAL\n", ""),
        ("server/Services/GhostService", "if GameManager.getPlayerState(player) ~= PlayerState.NORMAL then\n\t\treturn false\n\tend\n\tif beforePunish", "if beforePunish"),
    ],
}

sources = {}
for f in FILES:
    sources[f] = (repo / "src" / (f + ".luau")).read_text(encoding="utf-8")

for name in mut_names:
    entries = MUTATIONS[name]
    if isinstance(entries, tuple):
        entries = [entries]
    for path, old, new in entries:
        if old not in sources[path]:
            sys.exit(f"mutasi {name}: teks target tidak ditemukan di {path}")
        sources[path] = sources[path].replace(old, new, 1)

def lua_long(s):
    level = 0
    while f"]{'=' * level}]" in s:
        level += 1
    eq = "=" * level
    return f"[{eq}[\n{s}]{eq}]"

parts = ["SOURCES = {}\n"]
for k, v in sources.items():
    parts.append(f"SOURCES[{k!r}] = {lua_long(v)}\n".replace("'", '"'))
out = "".join(parts)
for fn in ["prelude.luau", "world.luau", "tests.luau"]:
    out += "\n" + (here / fn).read_text(encoding="utf-8") + "\n"

target = here / ("harness_" + ("_".join(mut_names) or "base") + ".luau")
target.write_text(out, encoding="utf-8")
r = subprocess.run([luau, str(target)], capture_output=True, text=True)
print(r.stdout)
if r.stderr.strip():
    print("STDERR:", r.stderr[:3000])
sys.exit(r.returncode)
