# Blender → Roblox pipeline for breakable objects

The game works without any meshes: every breakable is built from stud-textured voxel segments.
For smoother, hand-styled objects, use Blender meshes. They plug into the same break system.

## 1. Generate (or model) the pre-fractured mesh

```bash
blender --background --python blender/build_breakables.py
```

The script (tested with Blender 4.2) builds a clean low-poly model for every object in
`Config.Breakables`, then:

* **pre-fractures** it with jittered, slightly tilted cutting planes into closed chunks
  (`Segment_1`, `Segment_2`, …), each with its origin at the chunk centre so debris spins nicely;
* box-projects **stud-scaled UVs** (1 Blender unit = 1 stud = one tile of `assets/textures/stud_tile.png`);
* exports `blender/export/<ObjectId>.fbx` (Y-up, unit scale applied, texture embedded).

Modelling by hand? Follow the same rules: keep it low-poly, model at 1 unit = 1 stud, split the
object into separate mesh objects (one per breakable chunk), and keep chunks closed.

## 2. Import into Studio

1. **Home → Import 3D** (3D Importer) → choose `blender/export/IronAnvil.fbx`.
2. Under *File General* set **Scale Unit = Stud**, then **Import**.
3. Rename the imported Model to the breakable id (e.g. `IronAnvil`) and move it into
   **ServerStorage → BreakableModels**.

## 3. What the game does with it

At server start, `BreakableBuilder.ApplyCustomModel` sees `ServerStorage.BreakableModels.IronAnvil`
and swaps that stand's voxel segments for your mesh pieces:

* scaled to fit the object's `Size` from `Config.Breakables`;
* every MeshPart gets the object's colour palette (set the attribute `KeepColor = true` on a
  piece to keep its own colour) and the square-stud `Texture` overlay on all faces when
  `Config.Assets.StudTexture` is set;
* pieces are welded to the stand's `Core`, and on a smash each one flies off as stud debris.

Remove the model from `BreakableModels` to go back to the voxel version.
