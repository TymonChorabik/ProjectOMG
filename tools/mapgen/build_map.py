#!/usr/bin/env python3
"""
Bake the hub map into Rojo model files so it shows up in Studio's Workspace.

Runs the game's real MapBuilder (plus Config, PetModels, ItemModels, ...) offline with the
Luau CLI on top of a small mock Roblox API (tools/mapgen/mock_roblox.luau), then converts the
resulting instance tree into one `.model.json` per top-level map section:

    src/workspace/Map/Ground.model.json
    src/workspace/Map/Lane.model.json
    src/workspace/Map/TrainingZones.model.json
    ...

`default.project.json` maps that folder to Workspace.Map, so `rojo serve` / `rojo build` put
the whole hub — ground, cliffs, zones, pedestals, eggs, leaderboards and the 150-wall lane —
into the place.

Re-run after changing Config (objects, dojo colours, stud texture ids) or MapBuilder:

    python3 tools/mapgen/build_map.py          # needs `luau` on PATH (or LUAU=/path/to/luau)
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(ROOT, "src", "workspace", "Map")

MODULES = [
    ("ReplicatedStorage/Shared/Config", "src/shared/Config.luau"),
    ("ReplicatedStorage/Shared/Formulas", "src/shared/Formulas.luau"),
    ("ReplicatedStorage/Shared/NumberFormat", "src/shared/NumberFormat.luau"),
    ("ReplicatedStorage/Shared/StudSurface", "src/shared/StudSurface.luau"),
    ("ReplicatedStorage/Shared/PetModels", "src/shared/PetModels.luau"),
    ("ReplicatedStorage/Shared/ItemModels", "src/shared/ItemModels.luau"),
    ("ServerScriptService/Server/Modules/MapBuilder", "src/server/Modules/MapBuilder.luau"),
]

DRIVER = r"""
local function warn(...) print("WARN", ...) end
local MapBuilder = require(game:GetService("ServerScriptService").Server.Modules.MapBuilder)
local root = MapBuilder.Build(workspace)
print(serialize(root))
"""


def bundle() -> str:
    with open(os.path.join(HERE, "mock_roblox.luau"), encoding="utf-8") as f:
        parts = [f.read(), "local function warn(...) end"]
    for path, source in MODULES:
        with open(os.path.join(ROOT, source), encoding="utf-8") as f:
            body = f.read().replace("export type ", "type ")
        parts.append(f'defineModule("{path}", function(script)\n{body}\nend)')
    parts.append(DRIVER)
    return "\n".join(parts)


def num(value: float) -> float:
    rounded = round(value, 4)
    return int(rounded) if rounded == int(rounded) else rounded


def convert(value):
    if not isinstance(value, dict) or "$t" not in value:
        return num(value) if isinstance(value, float) else value
    kind, v = value["$t"], value["v"]
    if kind in ("Vector3", "Vector2", "Color3"):
        return [num(x) for x in v]
    if kind == "CFrame":
        x, y, z, *m = (num(c) for c in v)
        return {"CFrame": {"position": [x, y, z], "orientation": [m[0:3], m[3:6], m[6:9]]}}
    if kind == "UDim":
        return {"UDim": [num(v[0]), int(v[1])]}
    if kind == "UDim2":
        return {"UDim2": [[num(v[0]), int(v[1])], [num(v[2]), int(v[3])]]}
    if kind == "NumberRange":
        return {"NumberRange": [num(v[0]), num(v[1])]}
    if kind == "NumberSequence":
        return {"NumberSequence": {"keypoints": [{"time": num(t), "value": num(val), "envelope": num(e)} for t, val, e in v]}}
    if kind == "ColorSequence":
        return {"ColorSequence": {"keypoints": [{"time": num(t), "color": [num(r), num(g), num(b)]} for t, r, g, b in v]}}
    if kind == "Enum":
        return v  # Rojo resolves enum item names
    raise ValueError(f"unsupported value type {kind}")


def convert_attribute(value):
    if isinstance(value, bool):
        return {"Bool": value}
    if isinstance(value, (int, float)):
        return {"Float64": value}
    if isinstance(value, str):
        return {"String": value}
    if isinstance(value, dict) and value.get("$t") == "Color3":
        return {"Color3": [num(x) for x in value["v"]]}
    if isinstance(value, dict) and value.get("$t") == "Vector3":
        return {"Vector3": [num(x) for x in value["v"]]}
    raise ValueError(f"unsupported attribute value {value!r}")


def to_rojo(node, top: bool = False):
    out = {"ClassName": node["ClassName"]}
    if not top:
        out = {"Name": node["Name"], **out}
    props = {key: convert(value) for key, value in node["Properties"].items()}
    if node["Attributes"]:
        props["Attributes"] = {"Attributes": {k: convert_attribute(v) for k, v in node["Attributes"].items()}}
    if node["Tags"]:
        props["Tags"] = node["Tags"]
    if props:
        out["Properties"] = props
    if node["Children"]:
        out["Children"] = [to_rojo(child) for child in node["Children"]]
    return out


def count(node) -> int:
    return 1 + sum(count(child) for child in node["Children"])


def main() -> int:
    luau = os.environ.get("LUAU", "luau")
    with tempfile.TemporaryDirectory() as tmp:
        path = os.path.join(tmp, "mapgen.luau")
        with open(path, "w", encoding="utf-8") as f:
            f.write(bundle())
        try:
            result = subprocess.run([luau, path], cwd=tmp, capture_output=True, text=True)
        except FileNotFoundError:
            print(f"Could not run '{luau}'. Install the Luau CLI or set LUAU=/path/to/luau.")
            return 2
    if result.returncode != 0:
        print(result.stdout[-4000:], result.stderr[-4000:], sep="\n")
        return result.returncode

    json_line = next(line for line in reversed(result.stdout.splitlines()) if line.startswith("{"))
    tree = json.loads(json_line)

    if os.path.isdir(OUT_DIR):
        shutil.rmtree(OUT_DIR)
    os.makedirs(OUT_DIR)

    total = 0
    for section in tree["Children"]:
        target = os.path.join(OUT_DIR, f"{section['Name']}.model.json")
        with open(target, "w", encoding="utf-8") as f:
            json.dump(to_rojo(section, top=True), f, separators=(",", ":"), ensure_ascii=False)
            f.write("\n")
        n = count(section)
        total += n
        print(f"  {section['Name']:<14} {n:>5} instances -> {os.path.relpath(target, ROOT)}")
    print(f"Baked {total} instances into Workspace.Map")
    return 0


if __name__ == "__main__":
    sys.exit(main())
