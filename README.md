# Damage Meter Forever

<p align="center">
  <img src="docs/logo.png" alt="Damage Meter Forever" width="320">
</p>

Foofi damage meter for [WoW Classic Forever](https://worldofforever.com/).

Built on the [Details!](https://github.com/Tercioo/Details-Damage-Meter) core (Terciob), adapted for Forever secret API and **C_DamageMeter**. **ThreatForever** is included (Mode → Plugins).

<p align="center">
  <img src="docs/ingame.png" alt="Damage Meter Forever in combat" width="420">
</p>

<p align="center">
  <img src="docs/options.png" alt="Damage Meter Forever options" width="720">
</p>

## Package contents

| Folder (exact name required) | Addon list title |
|------------------------------|------------------|
| `DamageMeterForever` | **Damage Meter Forever** (includes ThreatForever) |
| `DamageMeterForever_DataStorage` | **Damage Meter Forever: Storage** |

## Install

Prefer the [release zip](https://github.com/gitBellucci/DamageMeterForever/releases/latest). Do **not** use GitHub’s green **Code → Download ZIP** unless you rename folders.

1. Extract so you have exactly **`DamageMeterForever`** and **`DamageMeterForever_DataStorage`**
2. Put both in `World of Warcraft\_classic_beta_\Interface\AddOns\`
3. Remove any old `Details` / `Details_DataStorage` / `Details_TinyThreat` / standalone `ThreatForever` folders
4. Fully restart WoW and enable both addons

## Use

- `/df` or `/details` — options
- Mode / Plugins → **ThreatForever**
- `/tf` — threat options

## Credits

- Core: [Details! Damage Meter](https://github.com/Tercioo/Details-Damage-Meter) by Terciob  
- Forever port & branding: Foofi
