--!strict
-- QuestView: mengubah state quest + counter menjadi baris tampilan Quest UI (fungsi murni, tanpa Instance).
-- Hanya data tampilan; sumber kebenaran tetap QuestService di server.

local QuestConfig = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("QuestConfig") :: ModuleScript)

export type Line = {
	kind: "title" | "objective",
	text: string,
	done: boolean,
}

local QuestView = {}

-- Quest pertama masih LOCKED = game belum dimulai (pemain belum bicara ke Pemandu): panel disembunyikan.
-- Selain itu HANYA SATU quest yang tampil (quest berjalan = quest pertama yang bukan LOCKED dan bukan COMPLETE).
-- Jika quest berikutnya belum diaktifkan, quest yang baru selesai tetap tampil (semua tercentang) sampai
-- quest berikutnya aktif. Quest yang belum dibuka tidak pernah ditampilkan.
function QuestView.getCurrentQuestId(getState: (questId: string) -> string?): string?
	local firstState = getState(QuestConfig.ORDER[1])
	if firstState == nil or firstState == "LOCKED" then
		return nil
	end

	local lastStarted: string? = nil
	for _, questId in QuestConfig.ORDER do
		local state = getState(questId) or "LOCKED"
		if state == "LOCKED" then
			break
		end
		if state ~= "COMPLETE" then
			return questId
		end
		lastStarted = questId
	end
	return lastStarted
end

function QuestView.build(
	getState: (questId: string) -> string?,
	getCounter: (questId: string, counterId: string) -> number?
): { Line }
	local lines: { Line } = {}

	local questId = QuestView.getCurrentQuestId(getState)
	if not questId then
		return lines
	end

	local def = (QuestConfig.Quests :: any)[questId] :: QuestConfig.QuestDef
	local state = getState(questId) or "LOCKED"
	local stateIndex = table.find(def.states, state) or 1

	table.insert(lines, { kind = "title", text = string.upper(def.displayName), done = state == "COMPLETE" })

	for _, objective in def.objectives do
		local doneIndex = table.find(def.states, objective.doneAt) or math.huge
		local done = stateIndex >= doneIndex

		local text = objective.text
		if objective.counter then
			local target = def.counters[objective.counter].target
			text = string.format("%s %d/%d", text, getCounter(questId, objective.counter) or 0, target)
		end

		table.insert(lines, {
			kind = "objective",
			text = (if done then "✓ " else "○ ") .. text,
			done = done,
		})
	end

	return lines
end

return table.freeze(QuestView)
