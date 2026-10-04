--!strict
-- Interactable: membaca Attribute objek interaktif dengan nilai default yang aman.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("Config"):WaitForChild("GameConfig") :: ModuleScript)

local Config = GameConfig.Interaction

local Interactable = {}

function Interactable.getId(target: Instance): string?
	local value = target:GetAttribute(Config.ATTR_ID)
	if typeof(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

function Interactable.getMaxDistance(target: Instance): number
	local value = target:GetAttribute(Config.ATTR_MAX_DISTANCE)
	if typeof(value) == "number" and value > 0 then
		return value
	end
	return Config.DEFAULT_DISTANCE
end

function Interactable.getActionText(target: Instance): string
	local value = target:GetAttribute(Config.ATTR_ACTION_TEXT)
	if typeof(value) == "string" and value ~= "" then
		return value
	end
	return "Gunakan"
end

function Interactable.getObjectText(target: Instance): string
	local value = target:GetAttribute(Config.ATTR_OBJECT_TEXT)
	if typeof(value) == "string" and value ~= "" then
		return value
	end
	return target.Name
end

return table.freeze(Interactable)