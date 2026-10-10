# UI style guide

How the game's UI is built, so new screens match. Everything below is created in code
(`src/client/UI/`). The values are the ones the code uses; the design tokens live in
`Theme.luau`.

Sizes are in pixels at 1080p. Windows sit under one `UIScale` that grows or shrinks them with
the screen (about ×1.3 at 1080p, smaller on phones).

---

## 1. Palette

| Use | Hex | Theme name |
|---|---|---|
| Outlines, text strokes, shadows | `#120E16` | `Colors.Ink` |
| Window glass (top, 40% transparent) | `#282A36` | `Colors.Window` |
| Primary / Robux button | `#60CE28` | `Colors.Green` |
| CLAIM! bar, tick badge | `#3DDC5A` | `Colors.Claim` |
| Countdown bar | `#1F2433` | `Colors.TimerBar` |
| Close button | `#FF2850` | `Colors.Close` |
| Side tab, idle | `#5B6482` | `Colors.TabIdle` |
| Side tab, selected (+ white outline) | `#2EC4F0` | `Colors.TabActive` |
| Grid backdrop (20% transparent) | `#2A2F3F` | `Colors.GridBackdrop` |
| Item slot (tinted 45% toward the rarity) | `#7A84A0` | `Colors.Slot` |
| Locked slot | `#68708A` | `Colors.SlotLocked` |
| Currency / stat text | `#FFD632` | `Colors.Gold` |
| Robux price text | `#6EEB46` | `Colors.GreenText` |

**Card backdrops (pastels).** These are soft, so the colour never fights the icon or text:

| Blue | Lavender | Peach | Mint | Butter | Teal | Pink | Slate |
|---|---|---|---|---|---|---|---|
| `#6EC1FA` | `#B58CF5` | `#FF9A85` | `#6EDC9A` | `#FFD166` | `#5FD6CF` | `#FF9FCB` | `#808AAA` |

Rainbow and gold are kept for premium or rare items only: the Starter Pack, Lion King, Phoenix
Relic, the best playtime gift, and Secret pets.

**Gradient rule.** Every coloured surface is painted white with a `UIGradient`
(`Rotation = 90`) that runs from a lighter top to a deeper bottom (`Theme.Gradient(color)`):

- **Top:** saturation × 0.72, value + 0.14
- **Bottom:** saturation × 1.08 + 0.04, value − 0.14

---

## 2. Building blocks

### Window (`MenuWindow.new`)
1. **Frame:** `BackgroundColor3 #282A36`, `BackgroundTransparency 0.4`.
   - `UICorner 10`
   - `UIStroke 3.5 Ink`
   - `UIGradient` (glass: white → `#AAAAB9`, `Rotation 90`)
2. **Title:**
   - TextLabel centred on the top border, `Font FredokaOne`, `MaxTextSize 80`.
   - `UIStroke` 6.5 × 0.8 in Ink.
   - Drop shadow: a dark copy 3px lower at 55% transparency, behind it.
3. **Decorative icon:** 104×104, centre at `(62, 0)`, `Rotation −10`. It sits on the top border,
   inside the left edge.
4. **Close button:** 64×66, centre at `(1, −46, 0, 0)`. It sits on the top border, inside the right
   edge. No studs.
5. **Content:**
   - `ScrollingFrame` at `(8, 58)`, size `(1, −16, 1, −66)`, `ScrollBarThickness 5`.
   - `UIListLayout Padding 8`.
   - `UIPadding` top 6, bottom 8, left 3, right 7.

### Card (`MenuWindow.Card`)
1. **Holder:** transparent Frame (size, position and layout order go here).
2. **Bevel:** Frame offset 5px down, height −5, colour `Theme.Shade(base, 0.34)`, `UICorner 6`,
   `UIStroke 4 Ink`.
3. **Face:** Frame height −5.
   - `UICorner 6`
   - `UIStroke 4 Ink`
   - `UIGradient` (the gradient rule above)
   - Studs: square studs that fade out toward the bottom (`StudBackground`)
   - **Gloss:** Frame at `(3, 3)`, size `(1, −6, 0.5, −3)`, white, `UICorner 4`, `UIGradient`
     transparency 0.64 → 1 (`Rotation 90`).
   - **Lit edge:** transparent Frame inset 2px, `UIStroke 1.5 white` at 0.68 transparency.
4. **Content padding:** titles at `(14, 10)` with size `(1, −28, 0, 32)`, so text never touches the
   border. Hero icons sit on a soft white halo (`MenuWindow.Glow`): two circles at 0.84 and 0.74
   transparency.

### Robux / primary button (`MenuWindow.PriceButton`)
1. **Holder:** transparent Frame (e.g. 150×58, or full card width −24).
2. **Bevel:** Frame offset 6px down, colour `Theme.Shade(#60CE28, 0.3)`, `UICorner 6`, `UIStroke 3 Ink`.
3. **Face:** `TextButton` with `AutoButtonColor false`.
   - `UICorner 6`
   - `UIStroke 3 Ink`
   - Green `UIGradient` (the gradient rule)
   - Gloss and lit edge as on cards
   - No studs
4. **Text:** `"<Robux icon> 49"`, using `utf8.char(0xE002)` and one space.
   - `Font GothamBold`, `MaxTextSize 32`.
   - `UIStroke` 4 × 0.8 in Ink.
   - Drop shadow 3px.
5. **Feedback:** hover scales to ×1.05; press pushes the face down onto the bevel, then a Back-ease
   bounce.

### Side tabs (Inventory)
- **Layout:** a column of square `ChunkyButton`s hanging off the window's left edge.
  - `UIListLayout Padding 12`, `HorizontalAlignment Right`.
  - `CornerRadius 14` on every tab.
  - Each tab is a big icon with its caption over the bottom.
- **Idle:** 100×100, `#5B6482`, Ink outline, icon at 0.25 transparency.
- **Selected:** 114×114 (so it sticks out further left), `#2EC4F0`, white `UIStroke`, full-strength
  icon.

### Grid slots (pets, hands, boosts)
- **Backdrop:** `#2A2F3F` at 20% transparency, `UICorner 14`, `UIStroke 3.5`.
  - `UIGridLayout`: 5 columns that stretch to fill (`CellSize (1/5, −4.8, 0, 106)`),
    `CellPadding 6`.
- **Pet slot:**
  - Face colour `#7A84A0` lerped 45% toward the rarity colour.
  - `UIStroke 3.5` in the rarity colour.
  - Bonus text on top, 3D model below.
- **Hand slot:** pastel blue when unlocked. When locked: `#68708A` with a black overlay at 0.7
  transparency and 🔒 in the corner.
- **Selected:** `UIStroke 4.5` white.
- **Equipped:** `MenuWindow.CheckBadge`.
  - A 28px green circle (`#3DDC5A`) with an Ink stroke.
  - A white tick made of two rotated rounded frames.
  - Placed in the bottom-right corner.

### Playtime reward cells
- **Row colours:** pastel blue, lavender, peach. The final gift is rainbow.
- **Countdown:** dark bar `#1F2433` with white text.
- **Ready:** `#3DDC5A` bar reading `CLAIM!`.
- **Claimed:** black overlay at 0.45 transparency plus a big 68px tick badge (`Rotation −8`).

### Text
- **Font:** `GothamBold` for UI text, `FredokaOne` for window titles.
- **Outline:** `UIStroke Contextual` in Ink, at 0.8 × the requested thickness.
- **Drop shadows:** on window titles, section headers ("~ Gamepasses ~"), card titles and every
  button label (`Create.Label{ Shadow = true }`).
- **Icons:** emoji `TextLabel`s with a soft dark outline (`UIStroke`, Ink, 0.3 transparency,
  1.5–3.5px depending on size).
