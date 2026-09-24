--[[
  ThreatForever — Foofi threat meter plugin for Details! on WoW Classic Forever.
]]

local AceLocale = LibStub("AceLocale-3.0")
local Loc = AceLocale:GetLocale("ThreatForever")
local detailsFramework = _G.DetailsFramework

local _GetNumSubgroupMembers = GetNumSubgroupMembers
local _GetNumGroupMembers = GetNumGroupMembers
local _UnitIsFriend = UnitIsFriend
local _UnitName = UnitName
local _IsInRaid = IsInRaid
local _IsInGroup = IsInGroup
local _UnitGroupRolesAssigned = DetailsFramework.UnitGroupRolesAssigned
local GetUnitName = GetUnitName
local Details = _G.Details
local GetSpellInfo = Details.GetSpellInfo or GetSpellInfo

local _ipairs = ipairs
local _table_sort = table.sort
local _cstr = string.format
local _unpack = unpack
local _math_floor = math.floor
local _math_abs = math.abs
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

-- Forever TOC ~16001 is not Classic Era for threat scaling.
local isClassicWow = detailsFramework.IsTimewalkWoW and detailsFramework.IsTimewalkWoW() and not (detailsFramework.IsForeverWow and detailsFramework.IsForeverWow())

-- Foofi brand accent (#0CD29D)
local ACCENT_R, ACCENT_G, ACCENT_B = 12 / 255, 210 / 255, 157 / 255
local function Accent()
	if EllesmereUI then
		if EllesmereUI.GetAccentColor then
			local r, g, b = EllesmereUI.GetAccentColor()
			if r then
				return r, g, b
			end
		end
		if EllesmereUI.DEFAULT_ACCENT_R then
			return EllesmereUI.DEFAULT_ACCENT_R, EllesmereUI.DEFAULT_ACCENT_G, EllesmereUI.DEFAULT_ACCENT_B
		end
	end
	return ACCENT_R, ACCENT_G, ACCENT_B
end

local function Chat(msg)
	print("|cff0cd29dThreatForever|r: " .. msg)
end

--> Create the plugin Object
local ThreatMeter = Details:NewPluginObject("Details_ThreatForever")
local ThreatMeterFrame = ThreatMeter.Frame
local PLUGIN_FRAME_NAME = "Details_ThreatForever"

ThreatMeter:SetPluginDescription(Loc["STRING_DESC"])

local _

local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local _UnitDetailedThreatSituation

if (isClassicWow) then
	_UnitDetailedThreatSituation = function(source, target)
		local isTanking, status, threatpct, rawthreatpct, threatvalue = UnitDetailedThreatSituation(source, target)
		if (threatvalue) then
			threatvalue = floor(threatvalue / 100)
		end
		return isTanking, status, threatpct, rawthreatpct, threatvalue
	end
else
	-- Forever / Midnight / Retail: already display units.
	_UnitDetailedThreatSituation = UnitDetailedThreatSituation
end

-- Threat bar colors: teal (safe) → amber (caution) → red (danger).
-- inverted=true: high % = dangerous (offtank / DPS).
function ThreatMeter:percent_color(value, inverted)
	value = tonumber(value) or 0
	if value < 0 then value = 0 end
	if value > 100 then value = 100 end

	local t = value / 100
	if inverted then
		-- low threat = teal, high = red
		if t < 0.5 then
			local u = t * 2
			return ACCENT_R + (1 - ACCENT_R) * u * 0.35, ACCENT_G + (0.75 - ACCENT_G) * u, ACCENT_B * (1 - u)
		else
			local u = (t - 0.5) * 2
			return 1, 0.75 * (1 - u) + 0.2 * u, 0.12 * (1 - u)
		end
	else
		if t < 0.5 then
			local u = t * 2
			return 1, 0.2 + 0.55 * u, 0.12
		else
			local u = (t - 0.5) * 2
			return 1 - (1 - ACCENT_R) * u, 0.75 + (ACCENT_G - 0.75) * u, 0.12 + (ACCENT_B - 0.12) * u
		end
	end
end

local lastThreatWarnAt = 0
local function MaybeWarnHighThreat(me, useAbsoluteMode)
	local options = ThreatMeter.options
	if not options or not options.playSound then
		return
	end
	if not me or me[3] then
		return
	end
	local role = me[4]
	if role == "TANK" then
		return
	end
	local pct = me[useAbsoluteMode and 7 or 2] or 0
	local threshold = useAbsoluteMode and (options.alertThresholdAbs or 100) or (options.alertThreshold or 80)
	if pct < threshold then
		return
	end
	local now = GetTime()
	if now - lastThreatWarnAt < 8 then
		return
	end
	lastThreatWarnAt = now
	Chat(_cstr(Loc["STRING_ALERT_HIGH"], pct))
	if PlaySound then
		PlaySound(SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
	end
end

local function CreatePluginFrames (data)

	--> catch Details! main object
	local _detalhes = _G.Details
	local DetailsFrameWork = _detalhes.gump

	--> data
	ThreatMeter.data = data or {}

	--> defaults
	ThreatMeter.RowWidth = 294
	ThreatMeter.RowHeight = 14
	--> amount of row wich can be displayed
	ThreatMeter.CanShow = 0
	--> all rows already created
	ThreatMeter.Rows = {}
	--> current shown rows
	ThreatMeter.ShownRows = {}
	-->
	ThreatMeter.Actived = false

	--> localize functions
	ThreatMeter.percent_color = ThreatMeter.percent_color

	ThreatMeter.GetOnlyName = ThreatMeter.GetOnlyName

	--> window reference
	local instance
	local player

	--> OnEvent Table
	function ThreatMeter:OnDetailsEvent (event, ...)

		if (event == "DETAILS_STARTED") then
			ThreatMeter:RefreshRows()

		elseif (event == "HIDE") then --> plugin hidded, disabled
			ThreatMeter.Actived = false
			ThreatMeter:Cancel()

		elseif (event == "SHOW") then

			instance = ThreatMeter:GetInstance (ThreatMeter.instance_id)

			ThreatMeter.RowWidth = instance.baseframe:GetWidth()-6

			ThreatMeter:UpdateContainers()
			ThreatMeter:UpdateRows()

			ThreatMeter:SizeChanged()

			player = GetUnitName ("player", true)

			ThreatMeter.Actived = false

			if (ThreatMeter:IsInCombat() or UnitAffectingCombat ("player")) then
				if (not ThreatMeter.initialized) then
					return
				end
				ThreatMeter.Actived = true
				ThreatMeter:Start()
			end

		elseif (event == "COMBAT_PLAYER_ENTER") then
			if (not ThreatMeter.Actived) then
				ThreatMeter.Actived = true
				ThreatMeter:Start()
			end

		elseif (event == "DETAILS_INSTANCE_ENDRESIZE" or event == "DETAILS_INSTANCE_SIZECHANGED") then

			local what_window = select (1, ...)
			if (what_window == instance) then
				ThreatMeter:SizeChanged()
				ThreatMeter:RefreshRows()
			end

		elseif (event == "DETAILS_OPTIONS_MODIFIED") then
			local what_window = select (1, ...)
			if (what_window == instance) then
				ThreatMeter:RefreshRows()
			end

		elseif (event == "DETAILS_INSTANCE_STARTSTRETCH") then
			ThreatMeterFrame:SetFrameStrata ("TOOLTIP")
			ThreatMeterFrame:SetFrameLevel (instance.baseframe:GetFrameLevel()+1)

		elseif (event == "DETAILS_INSTANCE_ENDSTRETCH") then
			ThreatMeterFrame:SetFrameStrata ("MEDIUM")

		elseif (event == "PLUGIN_DISABLED") then
			ThreatMeterFrame:UnregisterEvent ("PLAYER_TARGET_CHANGED")
			ThreatMeterFrame:UnregisterEvent ("PLAYER_REGEN_DISABLED")
			ThreatMeterFrame:UnregisterEvent ("PLAYER_REGEN_ENABLED")

		elseif (event == "PLUGIN_ENABLED") then
			ThreatMeterFrame:RegisterEvent ("PLAYER_TARGET_CHANGED")
			ThreatMeterFrame:RegisterEvent ("PLAYER_REGEN_DISABLED")
			ThreatMeterFrame:RegisterEvent ("PLAYER_REGEN_ENABLED")
		end
	end

	ThreatMeterFrame:SetWidth (300)
	ThreatMeterFrame:SetHeight (100)

	function ThreatMeter:UpdateContainers()
		for _, row in _ipairs (ThreatMeter.Rows) do 
			row:SetContainer (instance.baseframe)
		end
	end

	function ThreatMeter:UpdateRows()
		for _, row in _ipairs (ThreatMeter.Rows) do
			row.width = ThreatMeter.RowWidth
		end
	end

	function ThreatMeter:HideBars()
		for _, row in _ipairs (ThreatMeter.Rows) do 
			row:Hide()
		end
	end

	local target = nil
	local timer = 0
	local interval = 1.0

	local RoleIconCoord = {
		["TANK"] = {0, 0.28125, 0.328125, 0.625},
		["HEALER"] = {0.3125, 0.59375, 0, 0.296875},
		["DAMAGER"] = {0.3125, 0.59375, 0.328125, 0.625},
		["NONE"] = {0.3125, 0.59375, 0.328125, 0.625}
	}

	function ThreatMeter:SizeChanged()

		local instance = ThreatMeter:GetPluginInstance()

		local w, h = instance:GetSize()
		ThreatMeterFrame:SetWidth (w)
		ThreatMeterFrame:SetHeight (h)
		ThreatMeter.RowHeight = instance.row_info.height
		ThreatMeter.CanShow = math.floor ( h / (instance.row_info.height+1))

		for i = #ThreatMeter.Rows+1, ThreatMeter.CanShow do
			ThreatMeter:NewRow (i)
		end

		ThreatMeter.ShownRows = {}

		for i = 1, ThreatMeter.CanShow do
			ThreatMeter.ShownRows [i] = ThreatMeter.Rows[i]
			if (_detalhes.in_combat) then
				ThreatMeter.Rows[i]:Show()
			end
			ThreatMeter.Rows[i].width = w-5
		end

		for i = #ThreatMeter.ShownRows+1, #ThreatMeter.Rows do
			ThreatMeter.Rows [i]:Hide()
		end

	end

	local SharedMedia = LibStub:GetLibrary ("LibSharedMedia-3.0")

	function ThreatMeter:RefreshRow (row)

		local instance = ThreatMeter:GetPluginInstance()

		if (instance) then
			local font = SharedMedia:Fetch ("font", instance.row_info.font_face, true) or instance.row_info.font_face

			row.textsize = instance.row_info.font_size
			row.textfont = font
			row.texture = instance.row_info.texture
			row.shadow = instance.row_info.textL_outline

			row.width = instance.baseframe:GetWidth()-5
			row.height = instance.row_info.height
			local rowHeight = - ( (row.rowId -1) * (instance.row_info.height + 1) )
			row:ClearAllPoints()
			row:SetPoint ("topleft", ThreatMeterFrame, "topleft", 1, rowHeight)
			row:SetPoint ("topright", ThreatMeterFrame, "topright", -1, rowHeight)

		end
	end

	function ThreatMeter:RefreshRows()
		for i = 1, #ThreatMeter.Rows do
			ThreatMeter:RefreshRow (ThreatMeter.Rows [i])
		end
	end

	function ThreatMeter:NewRow (i)
		local newrow = DetailsFrameWork:NewBar (ThreatMeterFrame, nil, "ThreatForeverRow"..i, nil, 300, ThreatMeter.RowHeight)
		newrow:SetPoint (3, -((i-1)*(ThreatMeter.RowHeight+1)))
		newrow.lefttext = "bar " .. i
		local ar, ag, ab = Accent()
		newrow:SetColor(ar, ag, ab, 1)
		newrow.fontsize = 9.9
		newrow.fontface = "GameFontHighlightSmall"
		newrow:SetIcon ("Interface\\LFGFRAME\\UI-LFG-ICON-PORTRAITROLES", RoleIconCoord ["DAMAGER"])
		newrow.rowId = i
		ThreatMeter.Rows [#ThreatMeter.Rows+1] = newrow

		ThreatMeter:RefreshRow (newrow)

		newrow:Hide()

		return newrow
	end

	local absoluteSort = function (table1, table2)
		if (table1[6] > table2[6]) then
			return true
		else
			return false
		end
	end

	local relativeSort = function (table1, table2)
		if (table1[2] > table2[2]) then
			return true
		else
			return false
		end
	end

	function ThreatMeter:GetUnitId()
		local unitId
		if (ThreatMeter.saveddata.usefocus) then
			unitId = "focus"
			if (not UnitExists(unitId)) then
				unitId = "target"
			end
		else
			unitId = "target"
		end

		return unitId
	end

	local UpdateTableFromThreatSituation = function(threat_table, threatening, threatened)
		if not UnitDetailedThreatSituation then
			threat_table [2] = 0
			threat_table [3] = false
			threat_table [6] = 0
			threat_table [7] = 0
			return
		end
		local isTanking, status, threatpct, rawthreatpct, threatvalue = _UnitDetailedThreatSituation (threatening, threatened)
		-- Forever may return secret numbers; only use values we can read.
		local function readable(v)
			if v == nil then return nil end
			if issecretvalue and issecretvalue(v) then return nil end
			return v
		end
		threatpct = readable(threatpct)
		rawthreatpct = readable(rawthreatpct)
		threatvalue = readable(threatvalue)
		if (status ~= nil and not (issecretvalue and issecretvalue(status))) then
			threat_table [2] = threatpct or 0
			threat_table [3] = isTanking and true or false
			threat_table [6] = threatvalue or 0
			threat_table [7] = isTanking and 100 or (rawthreatpct or 0) -- rawthreatpct returns invalid values for the main tank
		else
			threat_table [2] = 0
			threat_table [3] = false
			threat_table [6] = 0
			threat_table [7] = 0
		end
	end

	local gougeSpells = {
		[15687] = 29425, -- Moroes: Gouge
		[22948] = 40491, -- Gurtogg Bloodboil: Bewildering Strike
		[25165] = 45256, -- Lady Sacrolash: Confounding Blow
	}
	local FindGougeSpellForUnit = function(unitId)
		if isClassicWow then
			local npcId = _detalhes:GetNpcIdFromGuid(UnitGUID(unitId))
			return gougeSpells[npcId]
		end
	end

	local Threater = function()

		local options = ThreatMeter.options

		local unitId = ThreatMeter:GetUnitId()

		if (ThreatMeter.Actived and UnitExists(unitId) and not _UnitIsFriend("player", unitId)) then

			--> get the threat of all players
			if (_IsInRaid()) then
				for i = 1, _GetNumGroupMembers(), 1 do

					local thisplayer_name = GetUnitName ("raid"..i, true)
					local threat_table_index = ThreatMeter.player_list_hash [thisplayer_name]
					local threat_table = ThreatMeter.player_list_indexes [threat_table_index]

					if (not threat_table) then
						--> some one joined the group while the player are in combat
						ThreatMeter:Start()
						return
					end

					UpdateTableFromThreatSituation(threat_table, "raid"..i, unitId)

				end

			elseif (_IsInGroup()) then
				for i = 1, _GetNumGroupMembers()-1, 1 do
					local thisplayer_name = GetUnitName ("party"..i, true)
					local threat_table_index = ThreatMeter.player_list_hash [thisplayer_name]
					local threat_table = ThreatMeter.player_list_indexes [threat_table_index]

					if (not threat_table) then
						--> some one joined the group while the player are in combat
						ThreatMeter:Start()
						return
					end

					UpdateTableFromThreatSituation(threat_table, "party"..i, unitId)

				end

				local thisplayer_name = GetUnitName ("player", true)
				local threat_table_index = ThreatMeter.player_list_hash [thisplayer_name]
				local threat_table = ThreatMeter.player_list_indexes [threat_table_index]

				UpdateTableFromThreatSituation(threat_table, "player", unitId)

			else

				--> player
				local thisplayer_name = GetUnitName ("player", true)
				local threat_table_index = ThreatMeter.player_list_hash [thisplayer_name]
				local threat_table = ThreatMeter.player_list_indexes [threat_table_index]

				UpdateTableFromThreatSituation(threat_table, "player", unitId)

				--> pet
				if (UnitExists ("pet")) then
					local thisplayer_name = GetUnitName ("pet", true) .. " *PET*"
					local threat_table_index = ThreatMeter.player_list_hash [thisplayer_name]
					local threat_table = ThreatMeter.player_list_indexes [threat_table_index]

					if threat_table then
						UpdateTableFromThreatSituation(threat_table, "pet", unitId)
					end
				end
			end

			local disableGougeMode = ThreatMeter.saveddata.disable_gouge
			local gougeSpellId = (not disableGougeMode) and FindGougeSpellForUnit(unitId)
			local useAbsoluteMode = gougeSpellId or ThreatMeter.saveddata.absolute_mode

			--> sort
			_table_sort (ThreatMeter.player_list_indexes, useAbsoluteMode and absoluteSort or relativeSort)
			local needMainTankDummyBar = true
			for index, t in _ipairs (ThreatMeter.player_list_indexes) do
				ThreatMeter.player_list_hash [t[1]] = index
				if t[3] then
					needMainTankDummyBar = false
				end
			end

			--> no threat on this enemy
			if (ThreatMeter.player_list_indexes [1][7] < 1) then
				ThreatMeter:HideBars()
				return
			end

			--> find main tank threat, even if they are not in group
			local mainTankAbsoluteThreat = ThreatMeter.player_list_indexes[1][6]/(ThreatMeter.player_list_indexes[1][7]/100)

			local lastIndex = 0
			local shownMe = false

			local me = ThreatMeter.player_list_indexes [ ThreatMeter.player_list_hash [player] ]
			local hidePullBar = ThreatMeter.saveddata.hide_pull_bar
			local needRangedPullBar = (not hidePullBar) and useAbsoluteMode
			local needMeleePullBar = (not hidePullBar) and useAbsoluteMode
			local needRelativePullBar = (not hidePullBar) and (not useAbsoluteMode) and me and (me[2] > 0) and (not me[3])

			--> find out scaling factor for bars
			local barValueUnit
			if useAbsoluteMode then
				barValueUnit = max(ThreatMeter.player_list_indexes[1][7]/100, needRangedPullBar and 1.3 or needMeleePullBar and 1.1 or 1.0)
			else
				barValueUnit = 1.0
			end

			--> find out gouge threshold (highest offtank threat, divided by 110%; this prevents the offtank from taking the boss back)
			local gougeThreshold = nil
			if gougeSpellId then
				for _, t in _ipairs (ThreatMeter.player_list_indexes) do
					if not t[3] then
						gougeThreshold = t[6] / 1.1
						break
					end
				end
			end

			local index = 1
			local lastIndex = #ThreatMeter.ShownRows
			local dummyBarCount = 0
			while index <= lastIndex do
				local thisRow = ThreatMeter.ShownRows[index]
				local threatActor = ThreatMeter.player_list_indexes[index-dummyBarCount]

				if needRelativePullBar then
					thisRow._icon:SetTexture ([[Interface\PVPFrame\Icon-Combat]])
					thisRow._icon:SetTexCoord (0, 1, 0, 1)

					local myPullThreat = me[6]*(100/me[2])
					local r,g = ThreatMeter:percent_color(me[2], true)

					thisRow:SetLeftText(Loc["STRING_PULL_YOU"])
					thisRow:SetRightText("+" .. ThreatMeter:ToK2 (myPullThreat - me[6]) .. " (" .. _cstr ("%.1f", 100-me[2]) .. "%)")
					thisRow:SetValue(me[2]/barValueUnit)
					thisRow:SetColor (r, g, 0, 1)
					thisRow:Show()

					needRelativePullBar = false

					index = index+1
					dummyBarCount = dummyBarCount+1
					if index > lastIndex then break end
					thisRow = ThreatMeter.ShownRows[index]
				end


				if needRangedPullBar and ((not threatActor) or (threatActor[7] < 130)) then
					thisRow._icon:SetTexture ([[Interface\PaperDoll\UI-PaperDoll-Slot-Ranged]])
					thisRow._icon:SetTexCoord (0, 1, 0, 1)

					thisRow:SetLeftText (Loc["STRING_PULL_RANGED"])
					thisRow:SetRightText(ThreatMeter:ToK2 (mainTankAbsoluteThreat*1.3) .. " (130%)")
					thisRow:SetValue(130/barValueUnit)
					thisRow:SetColor(1, 0.45, 0.12, 1)
					thisRow:Show()

					needRangedPullBar = false

					index = index+1
					dummyBarCount = dummyBarCount+1
					if index > lastIndex then break end
					thisRow = ThreatMeter.ShownRows[index]
				end

				if needMeleePullBar and ((not threatActor) or (threatActor[7] < 110)) then
					thisRow._icon:SetTexture ([[Interface\PaperDoll\UI-PaperDoll-Slot-MainHand]])
					thisRow._icon:SetTexCoord (0, 1, 0, 1)

					thisRow:SetLeftText (Loc["STRING_PULL_MELEE"])
					thisRow:SetRightText(ThreatMeter:ToK2 (mainTankAbsoluteThreat*1.1) .. " (110%)")
					thisRow:SetValue(110/barValueUnit)
					thisRow:SetColor(1, 0.55, 0.15, 1)
					thisRow:Show()

					needMeleePullBar = false

					index = index+1
					dummyBarCount = dummyBarCount+1
					if index > lastIndex then break end
					thisRow = ThreatMeter.ShownRows[index]
				end

				if needMainTankDummyBar and ((not threatActor) or (not useAbsoluteMode) or (threatActor[6] < mainTankAbsoluteThreat)) then
					thisRow._icon:SetTexture ([[Interface\LFGFrame\UI-LFG-Icon-PortraitRoles]])
					thisRow._icon:SetTexCoord (_unpack (RoleIconCoord ["TANK"]))
					
					thisRow:SetLeftText (Loc["STRING_PULL_TANK"])
					thisRow:SetRightText(ThreatMeter:ToK2 (mainTankAbsoluteThreat) .. " (100%)")
					thisRow:SetValue(100/barValueUnit)
					
					local r, g, b = Accent()
					for _, t in _ipairs (ThreatMeter.player_list_indexes) do
						if not t[3] then
							local otherPct = t[useAbsoluteMode and 7 or 2]
							r, g = ThreatMeter:percent_color(otherPct, true)
							b = 0
							break
						end
					end
					thisRow:SetColor(r, g, b or 0, 1)
					thisRow:Show()
					
					needMainTankDummyBar = false
					
					index = index+1
					dummyBarCount = dummyBarCount+1
					if index > lastIndex then break end
					thisRow = ThreatMeter.ShownRows[index]
				end

				if gougeThreshold and ((not threatActor) or (threatActor[6] < gougeThreshold)) then
					local spellName, _, spellTexture = GetSpellInfo (gougeSpellId)
					thisRow._icon:SetTexture (spellTexture)
					thisRow._icon:SetTexCoord (0, 1, 0, 1)

					local pct = gougeThreshold * 100 / mainTankAbsoluteThreat

					thisRow:SetLeftText (_cstr(Loc["STRING_PULL_SPELL"], spellName or "?"))
					thisRow:SetRightText(ThreatMeter:ToK2 (gougeThreshold) .. " (" .. _cstr ("%.1f", pct) .. "%)")
					thisRow:SetValue(pct/barValueUnit)
					thisRow:SetColor(1, 0.4, 0.15, 1)
					thisRow:Show()

					gougeThreshold = false

					index = index+1
					dummyBarCount = dummyBarCount+1
					if index > lastIndex then break end
					thisRow = ThreatMeter.ShownRows[index]
				end

				if (threatActor) then
					local role = threatActor[4]
					thisRow._icon:SetTexture ([[Interface\LFGFrame\UI-LFG-Icon-PortraitRoles]])
					thisRow._icon:SetTexCoord (_unpack (RoleIconCoord [role]))

					thisRow:SetLeftText (ThreatMeter:GetOnlyName (threatActor [1]))

					local pct = threatActor [useAbsoluteMode and 7 or 2]

					thisRow:SetRightText (ThreatMeter:ToK2 (threatActor [6]) .. " (" .. _cstr ("%.1f", pct) .. "%)")
					thisRow:SetValue (pct/barValueUnit)

					if (options.useplayercolor and threatActor [1] == player) then
						thisRow:SetColor (_unpack (options.playercolor))

					elseif (options.useclasscolors) then
						local color = RAID_CLASS_COLORS [threatActor [5]]
						if (color) then
							thisRow:SetColor (color.r, color.g, color.b)
						else
							local ar, ag, ab = Accent()
							thisRow:SetColor (ar, ag, ab, 1)
						end
					else
						if threatActor[3] then
							local r, g = Accent()
							for _, t in _ipairs (ThreatMeter.player_list_indexes) do
								if not t[3] then
									local otherPct = t[useAbsoluteMode and 7 or 2]
									r, g = ThreatMeter:percent_color(otherPct, true)
									break
								end
							end
							thisRow:SetColor (r, g, 0, 1)
						else
							local r, g = ThreatMeter:percent_color (pct, true)
							thisRow:SetColor (r, g, 0, 1)
						end
					end

					if (not thisRow.statusbar:IsShown()) then
						thisRow:Show()
					end
					if (threatActor [1] == player) then
						shownMe = true
					end
				else
					thisRow:Hide()
				end

				index = index+1
			end

			if me then
				MaybeWarnHighThreat(me, useAbsoluteMode)
			end

			if (not shownMe) then
				--> show my self into last bar
				local threat_actor = ThreatMeter.player_list_indexes [ ThreatMeter.player_list_hash [player] ]
				if (threat_actor) then
					if (threat_actor [2] and threat_actor [2] > 0.1) then
						local thisRow = ThreatMeter.ShownRows [#ThreatMeter.ShownRows]
						thisRow:SetLeftText (player)
						--thisRow.textleft:SetTextColor (unpack (RAID_CLASS_COLORS [threat_actor [5]]))
						local role = threat_actor [4]
						thisRow._icon:SetTexture ([[Interface\LFGFrame\UI-LFG-Icon-PortraitRoles]])
						thisRow._icon:SetTexCoord (_unpack (RoleIconCoord [role]))
						thisRow:SetRightText (ThreatMeter:ToK2 (threat_actor [6]) .. " (" .. _cstr ("%.1f", threat_actor [2]) .. "%)")
						thisRow:SetValue (threat_actor [2])

						if (options.useplayercolor) then
							thisRow:SetColor (_unpack (options.playercolor))
						else
							local r, g = ThreatMeter:percent_color (threat_actor [2], true)
							thisRow:SetColor (r, g, 0, .3)
						end
					end
				end
			end
		else
			--print ("nao tem target")
		end
	end

	function ThreatMeter:TargetChanged()
		if (not ThreatMeter.Actived) then
			return
		end

		local unitId = ThreatMeter:GetUnitId()

		local NewTarget = _UnitName(unitId)
		if (NewTarget and not _UnitIsFriend("player", unitId)) then
			target = NewTarget
			Threater()
		else
			ThreatMeter:HideBars()
		end
	end

	function ThreatMeter:Tick()
		Threater()
	end

	function ThreatMeter:Start()
		ThreatMeter:HideBars()
		if (ThreatMeter.Actived) then
			if (ThreatMeter.job_thread) then
				ThreatMeter:CancelTimer (ThreatMeter.job_thread)
				ThreatMeter.job_thread = nil
			end

			ThreatMeter.player_list_indexes = {}
			ThreatMeter.player_list_hash = {}

			--> pre build player list
			if (_IsInRaid()) then
                if (isClassicWow) then
                    if (not ThreatMeter.saveddata.only_my_group) then
                    for i = 1, _GetNumGroupMembers(), 1 do
                        local thisplayer_name = GetUnitName ("raid"..i, true)
                        local role = _UnitGroupRolesAssigned (thisplayer_name)
                        local _, class = UnitClass (thisplayer_name)
                        local t = {thisplayer_name, 0, false, role, class, 0, 0}
                        ThreatMeter.player_list_indexes [#ThreatMeter.player_list_indexes+1] = t
                        ThreatMeter.player_list_hash [thisplayer_name] = #ThreatMeter.player_list_indexes
                    end
                else
                    for i = 1, 4, 1 do
                        local thisplayer_name = GetUnitName ("party"..i, true)
                        if (thisplayer_name) then
                            local role = _UnitGroupRolesAssigned (thisplayer_name)
                            local _, class = UnitClass (thisplayer_name)
                            local t = {thisplayer_name, 0, false, role, class, 0, 0}
                            ThreatMeter.player_list_indexes [#ThreatMeter.player_list_indexes+1] = t
                            ThreatMeter.player_list_hash [thisplayer_name] = #ThreatMeter.player_list_indexes
                        end
                    end

                    local thisplayer_name = GetUnitName ("player", true)
                    local role = _UnitGroupRolesAssigned (thisplayer_name)
                    local _, class = UnitClass (thisplayer_name)
                    local t = {thisplayer_name, 0, false, role, class, 0, 0}
                    ThreatMeter.player_list_indexes [#ThreatMeter.player_list_indexes+1] = t
                    ThreatMeter.player_list_hash [thisplayer_name] = #ThreatMeter.player_list_indexes
                end
            else
				for i = 1, _GetNumGroupMembers(), 1 do
					local thisplayer_name = GetUnitName ("raid"..i, true)
					local role = _UnitGroupRolesAssigned (thisplayer_name)
					local _, class = UnitClass (thisplayer_name)
					local t = {thisplayer_name, 0, false, role, class, 0, 0}
					ThreatMeter.player_list_indexes [#ThreatMeter.player_list_indexes+1] = t
					ThreatMeter.player_list_hash [thisplayer_name] = #ThreatMeter.player_list_indexes
				end
            end

			elseif (_IsInGroup()) then
				for i = 1, _GetNumGroupMembers()-1, 1 do
					local thisplayer_name = GetUnitName ("party"..i, true)
					local role = _UnitGroupRolesAssigned (thisplayer_name)
					local _, class = UnitClass (thisplayer_name)
					local t = {thisplayer_name, 0, false, role, class, 0, 0}
					ThreatMeter.player_list_indexes [#ThreatMeter.player_list_indexes+1] = t
					ThreatMeter.player_list_hash [thisplayer_name] = #ThreatMeter.player_list_indexes

                    if (isClassicWow and ThreatMeter.saveddata.show_party_pets and UnitExists ("partypet" .. i)) then
                        local thispet_name = GetUnitName ("partypet" .. i, true) .. " *PET*"
                        local role = "DAMAGER"
                        local t = {thispet_name, 0, false, role, class, 0, 0}
                        ThreatMeter.player_list_indexes [#ThreatMeter.player_list_indexes+1] = t
                        ThreatMeter.player_list_hash [thispet_name] = #ThreatMeter.player_list_indexes
                    end
				end
				local thisplayer_name = GetUnitName ("player", true)
				local role = _UnitGroupRolesAssigned (thisplayer_name)
				local _, class = UnitClass (thisplayer_name)
				local t = {thisplayer_name, 0, false, role, class, 0, 0}
				ThreatMeter.player_list_indexes [#ThreatMeter.player_list_indexes+1] = t
				ThreatMeter.player_list_hash [thisplayer_name] = #ThreatMeter.player_list_indexes

                if (isClassicWow and ThreatMeter.saveddata.show_party_pets and UnitExists ("pet")) then
					local thispet_name = GetUnitName ("pet", true) .. " *PET*"
					local role = "DAMAGER"
					local t = {thispet_name, 0, false, role, class, 0, 0}
					ThreatMeter.player_list_indexes [#ThreatMeter.player_list_indexes+1] = t
					ThreatMeter.player_list_hash [thispet_name] = #ThreatMeter.player_list_indexes
				end
			else
				local thisplayer_name = GetUnitName ("player", true)
				local role = _UnitGroupRolesAssigned (thisplayer_name)
				local _, class = UnitClass (thisplayer_name)
				local t = {thisplayer_name, 0, false, role, class, 0, 0}
				ThreatMeter.player_list_indexes [#ThreatMeter.player_list_indexes+1] = t
				ThreatMeter.player_list_hash [thisplayer_name] = #ThreatMeter.player_list_indexes

				if (UnitExists ("pet")) then
					local thispet_name = GetUnitName ("pet", true) .. " *PET*"
					local role = "DAMAGER"
					local t = {thispet_name, 0, false, role, class, 0, 0}
					ThreatMeter.player_list_indexes [#ThreatMeter.player_list_indexes+1] = t
					ThreatMeter.player_list_hash [thispet_name] = #ThreatMeter.player_list_indexes
				end
			end

			local job_thread = ThreatMeter:ScheduleRepeatingTimer ("Tick", ThreatMeter.options.updatespeed)
			ThreatMeter.job_thread = job_thread
		end
	end

	function ThreatMeter:End()
		ThreatMeter:HideBars()
		if (ThreatMeter.job_thread) then
			ThreatMeter:CancelTimer (ThreatMeter.job_thread)
			ThreatMeter.job_thread = nil
		end
	end

	function ThreatMeter:Cancel()
		ThreatMeter:HideBars()
		if (ThreatMeter.job_thread) then
			ThreatMeter:CancelTimer (ThreatMeter.job_thread)
			ThreatMeter.job_thread = nil
		end
		ThreatMeter.Actived = false
	end

end

local build_options_panel = function()

	local options_frame = ThreatMeter:CreatePluginOptionsFrame ("ThreatForeverOptionsWindow", "ThreatForever", 1)

	local menu = {
		{
			type = "toggle",
			get = function() return ThreatMeter.saveddata.useplayercolor end,
			set = function (self, fixedparam, value) ThreatMeter.saveddata.useplayercolor = value end,
			desc = "Highlight your bar with the accent color below.",
			name = "Highlight Me"
		},
		{
			type = "color",
			get = function() return ThreatMeter.saveddata.playercolor end,
			set = function (self, r, g, b, a) 
				local current = ThreatMeter.saveddata.playercolor
				current[1], current[2], current[3], current[4] = r, g, b, a
			end,
			desc = "Your bar color when Highlight Me is on.",
			name = "My Color"
		},
		{
			type = "toggle",
			get = function() return ThreatMeter.saveddata.useclasscolors end,
			set = function (self, fixedparam, value) ThreatMeter.saveddata.useclasscolors = value end,
			desc = "Color bars by class (when Highlight Me is off for others).",
			name = "Class Colors"
		},

		{type = "blank"},

		{
			type = "toggle",
			get = function() return ThreatMeter.saveddata.usefocus end,
			set = function (self, fixedparam, value) ThreatMeter.saveddata.usefocus = value end,
			desc = "Track focus target when set, otherwise current target.",
			name = "Prefer Focus"
		},
		{
			type = "toggle",
			get = function() return not ThreatMeter.saveddata.hide_pull_bar end,
			set = function (self, fixedparam, value) ThreatMeter.saveddata.hide_pull_bar = not value end,
			desc = "Show melee / ranged pull thresholds.",
			name = "Pull Thresholds"
		},
		{
			type = "toggle",
			get = function() return ThreatMeter.saveddata.absolute_mode end,
			set = function(self, fixedparam, value) ThreatMeter.saveddata.absolute_mode = value end,
			desc = "Off: weighted % (aggro at 100%). On: absolute % (melee 110%, ranged 130%).",
			name = "Absolute Threat",
		},
		{
			type = "toggle",
			get = function() return not ThreatMeter.saveddata.disable_gouge end,
			set = function(self, fixedparam, value) ThreatMeter.saveddata.disable_gouge = not value end,
			desc = "On certain bosses, show a threshold where offtank / DPS can take aggro after a tank incap.",
			name = "Gouge Thresholds",
		},
		{
			type = "toggle",
			get = function() return ThreatMeter.saveddata.playSound end,
			set = function (self, fixedparam, value) ThreatMeter.saveddata.playSound = value end,
			desc = "Chat + sound when your threat crosses the danger line (not for tanks).",
			name = "High Threat Alert"
		},
	}

    -- Classic / Forever party options (skip on Apocalypse/Midnight retail if present)
    local isApocalypse = detailsFramework.IsAddonApocalypseWow and detailsFramework.IsAddonApocalypseWow()
        or detailsFramework.IsAddonApolcalpyseWow and detailsFramework.IsAddonApolcalpyseWow()
    if not isApocalypse then
        menu[#menu+1] = {
            type = "toggle",
            get = function() return ThreatMeter.saveddata.show_party_pets end,
            set = function(self, fixedparam, value) ThreatMeter.saveddata.show_party_pets = value end,
            desc = "Show pets in party (not in raid).",
            name = "Party Pets"
        }
        menu[#menu+1] = {
            type = "toggle",
            get = function() return ThreatMeter.saveddata.only_my_group end,
            set = function(self, fixedparam, value) ThreatMeter.saveddata.only_my_group = value end,
            desc = "In a raid, only show your party.",
            name = "Only My Group"
        }
    end

	local options_text_template = detailsFramework:GetTemplate ("font", "OPTIONS_FONT_TEMPLATE")
	local options_dropdown_template = detailsFramework:GetTemplate ("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
	local options_switch_template = detailsFramework:GetTemplate ("switch", "OPTIONS_CHECKBOX_TEMPLATE")
	local options_slider_template = detailsFramework:GetTemplate ("slider", "OPTIONS_SLIDER_TEMPLATE")
	local options_button_template = detailsFramework:GetTemplate ("button", "OPTIONS_BUTTON_TEMPLATE")
	menu.always_boxfirst = true

	detailsFramework:BuildMenu (options_frame, menu, 15, -35, 220, false, options_text_template, options_dropdown_template, options_switch_template, true, options_slider_template, options_button_template)
	options_frame:SetHeight(220)

end

ThreatMeter.OpenOptionsPanel = function()
	if (not ThreatForeverOptionsWindow) then
		build_options_panel()
	end
	ThreatForeverOptionsWindow:Show()
end

function ThreatMeter:OnEvent (_, event, ...)

	if (event == "PLAYER_TARGET_CHANGED") then
		ThreatMeter:TargetChanged()

	elseif (event == "PLAYER_REGEN_DISABLED") then
		lastThreatWarnAt = 0
		ThreatMeter.Actived = true
		ThreatMeter:Start()

	elseif (event == "PLAYER_REGEN_ENABLED") then
		ThreatMeter:End()
		ThreatMeter.Actived = false

	elseif (event == "ADDON_LOADED") then
		local AddonName = select (1, ...)

		if (AddonName == PLUGIN_FRAME_NAME or AddonName == "ThreatForever") then
			local function tryInstall()
				if (not _G.Details or not _G.Details.InstallPlugin) then
					return false
				end

				CreatePluginFrames ()

				local MINIMAL_DETAILS_VERSION_REQUIRED = 1
				local ar, ag, ab = Accent()

				local install, saveddata = _G.Details:InstallPlugin (
					"RAID",
					Loc["STRING_PLUGIN_NAME"],
					"Interface\\AddOns\\Details_TinyThreat\\Logo.png",
					ThreatMeter,
					"DETAILS_PLUGIN_THREAT_FOREVER",
					MINIMAL_DETAILS_VERSION_REQUIRED,
					"Foofi",
					"v1.0.0"
				)
				if (type (install) == "table" and install.error) then
					Chat(tostring(install.error))
					return true
				end

				_G.Details:RegisterEvent (ThreatMeter, "COMBAT_PLAYER_ENTER")
				_G.Details:RegisterEvent (ThreatMeter, "COMBAT_PLAYER_LEAVE")
				_G.Details:RegisterEvent (ThreatMeter, "DETAILS_INSTANCE_ENDRESIZE")
				_G.Details:RegisterEvent (ThreatMeter, "DETAILS_INSTANCE_SIZECHANGED")
				_G.Details:RegisterEvent (ThreatMeter, "DETAILS_INSTANCE_STARTSTRETCH")
				_G.Details:RegisterEvent (ThreatMeter, "DETAILS_INSTANCE_ENDSTRETCH")
				_G.Details:RegisterEvent (ThreatMeter, "DETAILS_OPTIONS_MODIFIED")

				ThreatMeterFrame:RegisterEvent ("PLAYER_TARGET_CHANGED")
				ThreatMeterFrame:RegisterEvent ("PLAYER_REGEN_DISABLED")
				ThreatMeterFrame:RegisterEvent ("PLAYER_REGEN_ENABLED")

				ThreatMeter.saveddata = saveddata or {}

				local sd = ThreatMeter.saveddata
				if sd.updatespeed == nil then sd.updatespeed = 0.5 end
				if sd.animate == nil then sd.animate = false end
				if sd.showamount == nil then sd.showamount = false end
				if sd.useplayercolor == nil then sd.useplayercolor = true end
				if sd.playercolor == nil then sd.playercolor = {ar, ag, ab, 1} end
				if sd.useclasscolors == nil then sd.useclasscolors = true end
				if sd.usefocus == nil then sd.usefocus = false end
				if sd.hide_pull_bar == nil then sd.hide_pull_bar = false end
				if sd.absolute_mode == nil then sd.absolute_mode = true end
				if sd.disable_gouge == nil then sd.disable_gouge = false end
				if sd.show_party_pets == nil then sd.show_party_pets = false end
				if sd.only_my_group == nil then sd.only_my_group = false end
				if sd.playSound == nil then sd.playSound = false end
				if sd.alertThreshold == nil then sd.alertThreshold = 80 end
				if sd.alertThresholdAbs == nil then sd.alertThresholdAbs = 100 end

				ThreatMeter.options = ThreatMeter.saveddata

				SLASH_THREATFOREVER1 = "/tf"
				SLASH_THREATFOREVER2 = "/threatforever"
				SLASH_THREATFOREVER3 = "/tinythreat"

				function SlashCmdList.THREATFOREVER (msg)
					local cmd = (msg or ""):lower():match("^%s*(%S*)")
					if cmd == "help" or cmd == "?" then
						Chat(Loc["STRING_COMMAND_LIST"])
						print("|cffffff00/tf|r — options")
						print("|cffffff00/tf alert|r — toggle high threat alert")
						return
					end
					if cmd == "alert" then
						sd.playSound = not sd.playSound
						Chat(sd.playSound and "alert on." or "alert off.")
						return
					end
					ThreatMeter.OpenOptionsPanel()
				end

				ThreatMeter.initialized = true
				return true
			end

			if (not tryInstall()) then
				C_Timer.After(1, function()
					if not ThreatMeter.initialized then
						tryInstall()
					end
				end)
				C_Timer.After(5, function()
					if not ThreatMeter.initialized then
						tryInstall()
					end
				end)
			end
		end
	end
end

-- OnEvent is invoked by Details:NewPluginObject (PLAYER_LOGIN → ADDON_LOADED with frame name).
