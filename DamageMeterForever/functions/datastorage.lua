
DETAILS_STORAGE_VERSION = 7

function Details:CreateStorageDB()
	DetailsDataStorage = {
		VERSION = DETAILS_STORAGE_VERSION,
		normal = {},
		heroic = {},
		mythic = {},
		["totalkills"] = {},
		["mythic_plus"] = {},
		["saved_encounters"] = {},
	}
	return DetailsDataStorage
end

-- Embedded in DamageMeterForever (no separate LoadOnDemand addon).
local f = CreateFrame("frame", nil, UIParent)
f:Hide()
f:RegisterEvent("ADDON_LOADED")

f:SetScript("OnEvent", function(self, event, addonName)
	if (addonName == "DamageMeterForever" or addonName == "DamageMeterForever_DataStorage" or addonName == "Details_DataStorage") then
		DetailsDataStorage = DetailsDataStorage or Details:CreateStorageDB()
		DetailsDataStorage.Data = DetailsDataStorage.Data or {}

		if (DetailsDataStorage.VERSION and DetailsDataStorage.VERSION < DETAILS_STORAGE_VERSION) then
			table.wipe(DetailsDataStorage)
			DetailsDataStorage = Details:CreateStorageDB()
		elseif (not DetailsDataStorage.VERSION) then
			DetailsDataStorage = Details:CreateStorageDB()
		end

		if (Details and Details.debug) then
			print("|cFFFFFF00Details! Storage|r: loaded!")
		end

		DETAILS_STORAGE_LOADED = true
		if (Details222) then
			Details222.storageLoaded = true
		end
	end
end)
