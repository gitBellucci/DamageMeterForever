# Details! for WoW Classic Forever

Port of Terciob's **Details! Damage Meter** (Midnight / no-CLEU build) for Forever.

## Why this exists

Forever uses the same combat restrictions as Midnight: addons cannot parse `COMBAT_LOG_EVENT_UNFILTERED`. Details must read Blizzard's `C_DamageMeter` API instead. Classic Era Details will not work here.

## What was changed

- `Details_Forever.toc` / `Details_DataStorage_Forever.toc` — Interface `16001` / `11601`
- `Libs/DF/fw.lua` — `IsForeverWow()` (TOC 16000–19999) forces the Midnight path
- `classes/class_damage.lua` — `IsUsingBlizzardAPI()` was always false on Forever (TOC < 120000); now Forever always feeds from `C_DamageMeter` (same model as Epic Damage Meter / LuckyoneUI)
- `core/parser_nocleu.lua` — safe `Enum.DamageMeterType` mapping when Forever is missing some enum members
- UI/Cooltip Forever shims for missing retail templates / `SetGradientAlpha`

## Included

- `Details`
- `Details_DataStorage` (optional history storage)

## Not included (use Forever versions separately)

- `Details_TinyThreat` — already provided as the standalone Forever Tiny Threat in this AddOns folder
- Encounter Breakdown / Raid Check / Vanguard / Streamer / Compare2 — Midnight-incompatible child plugins

## Install

Already under `_classic_beta_\Interface\AddOns\`. `/reload` or restart the client, enable **Details! Damage Meter (Forever)** in the addon list.

## Upstream

Based on retail Details `#Details.20260401.14850.171` from CurseForge / your local `_retail_` install.
