# ✅ To-Do

What's left before (and after) launch. Tick items off as you go (`- [x]`).

## 🚀 Before publishing

- [ ] **Create the Robux items** on the Creator Hub (your experience → *Monetization*).
  - 9 game passes and 18 developer products.
  - Paste each `Id` into `Config.Monetization` (`src/shared/Config.luau`). `Id = 0` means
    "not set up yet".
- [ ] **Turn on API Services** in Game Settings → Security, so saving and leaderboards work.
  Publish the place once.
- [ ] **Change the codes** in `Config.Codes` (`RELEASE`, `KUNGFU`, `CHOP`) to the ones you'll
  announce.
- [ ] **Make a game icon, thumbnails and a description.**

## 🔍 Check in Studio

The UI was only checked in offline previews, so check these in Studio:

- [ ] Robux icon shows in prices. They use the character U+E002; if you see a box, switch
  `Theme.Robux` to `"R$"`.
- [ ] Emoji icons get their dark outline (UIStroke on emoji text).
- [ ] The egg panel appears next to the egg and Hatch 1/3/8 work (keys E/R/T).
- [ ] Training floors: you chop on the pad, and other players on the same pad are invisible.
- [ ] Auto Smash keeps farming the lane from anywhere.
- [ ] Windows look right on phone and tablet (Device emulator).
- [ ] Saving: leave and rejoin; Welcome Back shows offline Strength.

## 🎨 Art, animation & sound (yours)

- [ ] **Chop / training animation:** upload it and paste the ID into
  `Config.Assets.ChopAnimation`.
- [ ] **Sounds:** replace the built-in placeholder sounds in `Config.Assets.Sounds` (chop,
  smash, click, purchase…). Add music.
- [ ] **Effects:** hit sparks, wall shatter, level-up, rebirth and hatch effects.
- [ ] **Models:** pets, hand items, eggs, training-floor targets and the lane walls are
  currently simple part models.
- [ ] **Custom icons:** replace the emoji icons in the shop, tabs and HUD with 3D-rendered
  images (upload them and swap the emoji for ImageLabels).
- [ ] **Stud texture (optional):** upload `assets/textures/stud_overlay.png` and paste it
  into `Config.Assets.StudTexture`.

## ✨ Features to build next

- [ ] **Free Reward window:** like/favourite the game and join the group, then
  "Verify & Claim" (e.g. +10,000 Strength). Needs your group ID.
- [ ] **Worlds:** a Worlds window and world portals, with a second map area and its own
  floors, lane and eggs.
- [ ] **Gift gamepasses:** a purple gift button next to each price. Pick a player, buy a
  "gift" product, and the server grants the pass to them.
- [ ] **Titles:** a "My Titles" tab like the reference.
- [ ] **Index:** a collection book of every pet and item found.
- [ ] **Pet extras:** auto-delete by rarity, Equip Best sort options, maybe pet fusing.
- [ ] **Daily rewards / login streak.**
- [ ] **More hand items, trails and eggs** for late game.

## ⚖️ Balance

- [ ] Playtest the first 30 minutes: how fast are the first rebirth and first egg?
- [ ] Tune wall toughness (`Config.Lane`), Wins per biome, rebirth cost and floor
  multipliers.
- [ ] Check that Robux prices feel fair against the free progression.
