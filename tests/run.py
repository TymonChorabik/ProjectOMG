#!/usr/bin/env python3
"""
Offline unit tests for the pure Luau modules (no Roblox Studio needed).

Bundles the modules under test into one Luau chunk with a tiny fake instance tree so
`require(script.Parent.X)` works, stubs the handful of Roblox datatypes Config uses, appends
tests/spec.luau and runs it with the `luau` CLI (https://github.com/luau-lang/luau/releases).

    python3 tests/run.py            # uses `luau` from PATH
    LUAU=/path/to/luau python3 tests/run.py
"""

import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (fake instance path, source file)
MODULES = [
    ("Shared/Config", "src/shared/Config.luau"),
    ("Shared/Formulas", "src/shared/Formulas.luau"),
    ("Shared/NumberFormat", "src/shared/NumberFormat.luau"),
]

PRELUDE = r"""
-- Roblox datatype stubs (only what the pure modules touch) ---------------------
Color3 = {
	fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end,
	new = function(r, g, b) return { R = r or 0, G = g or 0, B = b or 0 } end,
}
Vector3 = { new = function(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end }
UDim2 = { new = function(...) return { ... } end }
Enum = setmetatable({}, {
	__index = function(_, enumName)
		return setmetatable({}, { __index = function(_, item) return enumName .. "." .. item end })
	end,
})

-- Fake instance tree + require shim ------------------------------------------------
local Instances = {}
local function node(path)
	if Instances[path] then return Instances[path] end
	local parentPath, name = string.match(path, "^(.*)/([^/]+)$")
	local self = { Name = name or path, _children = {}, _path = path }
	Instances[path] = self
	if parentPath then
		local parent = node(parentPath)
		self.Parent = parent
		parent._children[self.Name] = self
	end
	return setmetatable(self, {
		__index = function(t, key)
			if key == "WaitForChild" or key == "FindFirstChild" then
				return function(inst, childName) return inst._children[childName] end
			end
			return rawget(t, "_children")[key]
		end,
	})
end

local loaders, cache = {}, {}
local function define(path, fn)
	loaders[path] = fn
	node(path)
end
local _require = function(inst)
	local path = inst._path
	if cache[path] == nil then
		local fn = assert(loaders[path], "no module at " .. tostring(path))
		cache[path] = fn(Instances[path])
	end
	return cache[path]
end
"""


def build_bundle() -> str:
    parts = [PRELUDE]
    for path, source in MODULES:
        with open(os.path.join(ROOT, source), encoding="utf-8") as f:
            # `export type` is only legal at chunk top level; the bundle wraps each module in a function.
            body = f.read().replace("export type ", "type ")
        parts.append(f'define("{path}", function(script)\n\tlocal require = _require\n{body}\nend)\n')
    parts.append("local function module(path) return _require(Instances[path]) end\n")
    with open(os.path.join(ROOT, "tests", "spec.luau"), encoding="utf-8") as f:
        parts.append(f.read())
    return "\n".join(parts)


def main() -> int:
    luau = os.environ.get("LUAU", "luau")
    with tempfile.TemporaryDirectory() as tmp:
        bundle_path = os.path.join(tmp, "bundle.luau")
        with open(bundle_path, "w", encoding="utf-8") as f:
            f.write(build_bundle())
        try:
            result = subprocess.run([luau, bundle_path], cwd=tmp)
        except FileNotFoundError:
            print(f"Could not run '{luau}'. Install the Luau CLI or set LUAU=/path/to/luau.")
            return 2
        return result.returncode


if __name__ == "__main__":
    sys.exit(main())
