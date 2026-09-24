local Loc = LibStub("AceLocale-3.0"):NewLocale("ThreatForever", "enUS", true)

if (not Loc) then
	return
end

Loc["STRING_PLUGIN_NAME"] = "ThreatForever"

Loc["STRING_SLASH_ANIMATE"] = "animate"
Loc["STRING_SLASH_SPEED"] = "speed"
Loc["STRING_SLASH_AMOUNT"] = "amount"

Loc["STRING_COMMAND_LIST"] = "commands:"
Loc["STRING_SLASH_SPEED_DESC"] = "update interval in seconds (0.1–3.0)"
Loc["STRING_SLASH_SPEED_CHANGED"] = "update speed set to "
Loc["STRING_SLASH_SPEED_CURRENT"] = "update speed is "

Loc["STRING_PULL_YOU"] = "You pull at"
Loc["STRING_PULL_RANGED"] = "Ranged pull"
Loc["STRING_PULL_MELEE"] = "Melee pull"
Loc["STRING_PULL_TANK"] = "Tank"
Loc["STRING_PULL_SPELL"] = "%s threshold"
Loc["STRING_ALERT_HIGH"] = "high threat — %.0f%%"
Loc["STRING_DESC"] = "Foofi threat meter for Details! on WoW Classic Forever."
