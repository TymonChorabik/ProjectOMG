# 🥋 +1 Kung Fu Chop! — Game Design

A Roblox **"+1" incremental simulator** in the style of *+1 Stone Skipping*. You train your
kung fu on training floors to gain **Strength**, then launch down a lane and smash through as
many board walls as your Strength allows to earn **Wins**. You spend Wins on better hands,
pets and trails, and rebirth to multiply everything. The whole world and UI use a chunky,
studded LEGO-like look.

All numbers below come from `src/shared/Config.luau`, which you can tune freely.

---

## The core loop

```
 Train on a floor ──► Strength ──► Smash the wall lane ──► Wins
        ▲                                                   │
        │      better hands · pets · trails · eggs ◄────────┘
        │                                                   │
        └──────── Rebirth (resets Strength, ×Strength) ◄────┘
```

1. **Train.** Stand on a training floor's pad and you chop automatically, gaining Strength.
   There is no clicking.
2. **Smash.** Step on the yellow launch pad. You fly down the lane and break every wall your
   Strength can beat. The walls you break pay out **Wins**.
3. **Spend.** Wins unlock hand items, hatch eggs (pets) and buy trails, all of which make you
   stronger or faster.
4. **Rebirth.** At max level (40), rebirth to reset Strength and level and get a permanent
   multiplier. Rebirths also unlock better training floors.

---

## The map (one hub)

| Area | What's there |
|---|---|
| **Spawn / centre** | Spawn point and the yellow **launch pad** at the start of the wall lane |
| **Right side** | **Training floors**: small studded pools side by side, each with a pad and an item to break |
| **The lane** | **Board Wall lane**: 150 walls in 6 themed biomes running away from spawn |
| **Item plaza** | Pedestals with every **hand item**; walk up and press E to equip |
| **Behind spawn** | **Eggs** on pads, the "Best in game" **Lion King** showcase, and global **leaderboards** |

---

## Strength: training floors

- Stand on a floor's pad and every **0.6 s** you chop for one chop's Strength × the floor's
  multiplier.
- The server checks where you're standing, so autoclickers do nothing.
- Other players on the same pad are hidden for you, so it feels like your own floor.
- Each floor has its own breakable target, which shatters with each chop.

| Floor | Multiplier | Unlocks at | Breaks |
|---|---|---|---|
| Wooden Dojo | ×1 | start | Wooden Boards |
| Bamboo Garden | ×4 | 2 rebirths | Bamboo |
| Waterfall Shrine | ×10 | 4 rebirths | Ice Blocks |
| Lava Pit | ×20 | 6 rebirths | Bricks |
| Golden Temple | ×30 | game pass (R$ 99) | Gold Bars |
| Dragon Sanctum | ×75 | game pass (R$ 249) | Obsidian |
| Cosmic Dojo | ×200 | game pass (R$ 599) | Star Crystals |

**Strength per chop** is calculated as:

> equipped hand bonus × floor multiplier × rebirth multiplier × pet bonus × boosts × friend
> boost

---

## Wins: the Board Wall lane

- **Layout:** 150 walls (6 biomes × 25). Wall *n* needs `10 × 1.15^(n−1)` Strength to break.
- **A run:** you break walls in order until one is too tough, then land back near the pad.
- **Cooldown:** 1.5 s between runs. Runs last 2.5 to 11 s.
- **Your best distance** goes on the *Longest Smash* leaderboard.
- **Auto Smash pass:** farms the lane hands-free from anywhere. It launches, smashes, comes back
  and repeats every 1.5 s.

| Biome | Walls | Wins per wall |
|---|---|---|
| Bamboo Grove | 1–25 | 1 |
| Autumn Temple | 26–50 | 3 |
| Frost Peak | 51–75 | 10 |
| Lava Fortress | 76–100 | 30 |
| Sky Palace | 101–125 | 100 |
| Cosmic Rift | 126–150 | 300 |

Wins are multiplied by rebirths (+10% each), the 2x Wins pass and the 2x Wins boost.

---

## Hand items (the game's "stones")

- **Unlocking:** each hand item unlocks at a lifetime-Wins milestone. Equip one at a time.
- **Bonus:** the item's bonus is its base Strength per chop.

| Item | Bonus | Lifetime Wins |
|---|---|---|
| Bare Fists | +1 | 0 |
| Cloth Wraps | +3 | 2 |
| Leather Wraps | +5 | 10 |
| Training Gloves | +12 | 40 |
| Iron Knuckles | +30 | 150 |
| Bamboo Bracers | +75 | 500 |
| Jade Gauntlets | +200 | 1.5K |
| Golden Gauntlets | +500 | 4.5K |
| Lava Fists | +1.25K | 14K |
| Frost Claws | +3.5K | 40K |
| Thunder Fists | +10K | 125K |
| Dragon Claws | +30K | 400K |
| Void Gauntlets | +100K | 1.25M |
| Celestial Palms | +300K | 4M |
| **Phoenix Relic** (pass) | always **+125%** over your best | R$ 499 |

---

## Pets & eggs

- **Slots:** you can equip 3 pets (5 with the +2 Pet Slots pass), and hold up to 60.
- **Bonus:** each pet adds a % Strength bonus.
- **Hatching:** walk up to an egg and a panel shows the pet chances. **Hatch 1 / 3 / 8** with
  the keys **E / R / T**. Several hatches play together.

| Egg | Cost | Pets (rarest last) |
|---|---|---|
| Common | 50 Wins | Puppy, Kitty, Bunny, Panda |
| Uncommon | 500 Wins | Fox, Monkey, Tiger, Golden Panda |
| Rare | 4K Wins | Owl, Crane, Snow Leopard, Jade Dragon |
| Legendary | 30K Wins | Red Panda, Kirin, Thunder Tiger, Shadow Dragon |
| Rainbow | R$ 45 / 119 / 299 (1/3/8) | Rainbow Unicorn, Galaxy Cat, **Dragon King** (Secret) |

- **Rarities:** Common, Uncommon, Rare, Epic, Legendary, Mythic, Secret.
- **2x Luck boost:** doubles the weight of every non-Common pet.
- **Lion King** (pass, R$ 799): always **1000% better** than your best other pet.

---

## Trails

Trails are bought with Wins. They add a coloured trail and extra walk speed (base speed 20).

| Trail | Cost | Speed |
|---|---|---|
| Breeze | 100 | +2 |
| Flame | 1K | +4 |
| Frost | 7.5K | +6 |
| Thunder | 40K | +8 |
| Rainbow | 200K | +10 |
| Galaxy | 1M | +12 |

---

## Rebirth & levels

- **Levels:** your level (1–40) follows your Strength. Level 40 is the rebirth goal.
- **Cost:** the first rebirth costs 2,500 Strength, and each one after costs ×3.5 more.
- **Rewards:** each rebirth gives **+50% Strength** and **+10% Wins**, permanently, and unlocks
  the next floors.
- **What resets:** Strength and level. You keep Wins, items, pets and trails.
- **Skip Rebirth** (R$ 49) rebirths you immediately.

---

## Rewards & social

- **Playtime gifts:** 12 gifts over 90 minutes per session, including Strength, Wins, eggs and
  2x boosts.
- **Offline training:** you earn 35% of idle training while away (up to 8 h). A **Welcome
  Back** popup lets you claim it, or ×3 for R$ 9.
- **Boosts:** timed **2x Strength / 2x Wins / 2x Luck**, from gifts, codes or the shop.
- **Codes** (Shop → Codes): `RELEASE`, `KUNGFU`, `CHOP`. Each can be used once per player.
- **Friend boost:** +10% Strength per friend in the server, up to +50%.
- **Leaderboards:** global top 10 for Most Wins, Most Rebirths and Longest Smash.

---

## Monetization (Robux)

| Game passes | Price | | Developer products | Price |
|---|---|---|---|---|
| Auto Smash | 25 | | Strength +10K / 100K / 1M / 10M | 11 / 45 / 95 / 199 |
| 2x Strength | 49 | | Wins Tiny / Small / Medium / Large | 25 / 59 / 115 / 229 |
| 2x Wins | 59 | | 2x Strength / Wins / Luck boost (10 min) | 29 each |
| +2 Pet Slots | 99 | | Boost Bundle (all 3, 20 min) | 95 |
| Golden Temple | 99 | | Skip Rebirth | 49 |
| Dragon Sanctum | 249 | | Rainbow Egg ×1 / ×3 / ×8 | 45 / 119 / 299 |
| Cosmic Dojo | 599 | | Starter Pack (Galaxy Cat + 25K Strength + 1K Wins, once) | 49 |
| Phoenix Relic | 499 | | x3 Offline claim | 9 |
| Lion King | 799 | | | |

All IDs are placeholders (`Id = 0`) until they're created on the Creator Hub (see `TODO.md`).
In Studio, test purchases are granted free.

---

## UI

- **Look:** a studded, chunky look modelled on *+1 Stone Skipping*.
  - Windows are tinted dark glass that blurs the world behind them.
  - Cards are pastel plastic with 3D bevels.
  - Green Robux buttons; inventory tabs down the left side.
- **HUD:** menu tiles on the left (Shop, Rebirth, Pets, Trails, Inventory, Gifts), a level bar
  with Strength pack buttons, Auto Smash, offers on the right, and Rebirths/Wins in the corner.
- **Windows:** Shop, Rebirth, Inventory (Hands / Pets / Boosts tabs), Trails, Playtime Rewards,
  Welcome Back, and the egg panel.
- **Style rules:** see [`docs/UI_STYLE.md`](docs/UI_STYLE.md).

---

## Tech overview

- **Project:** a Rojo project with a pre-built `KungFuChop.rbxl`. Full layout in `README.md`.
- **Server-authoritative:** the client only asks "start my run" or "buy/equip X". The server
  computes every number and validates every request.
- **Saving:** player data is saved in a session-locked DataStore. Robux purchases are granted
  idempotently.
- **Map:** the map is baked offline (`tools/mapgen`). UI previews are rendered offline
  (`tools/uipreview`).
- **Tests:** unit tests for the game math live in `tests/`.
