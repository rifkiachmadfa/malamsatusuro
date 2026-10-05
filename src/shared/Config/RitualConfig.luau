--!strict
-- RitualConfig: tempat persembahan (Workspace.QuestObjects.RitualCollection) dan daftar persembahan quest.
-- Quest dianggap SELESAI saat item quest DISIMPAN di RitualCollection, bukan saat bicara ke Pemandu.
-- Pemandu hanya melaporkan bahwa quest sudah selesai (dialog). Hanya data, tanpa logika.

export type Offering = {
	questId: string,
	itemId: string, -- ItemConfig.Items key
	obtainedState: string, -- state quest saat item sudah di tangan pemain
	submittedState: string, -- state sementara saat item disimpan; langsung lanjut ke COMPLETE
}

local RitualConfig = {}

RitualConfig.MODEL_NAME = "RitualCollection" -- Workspace.QuestObjects.RitualCollection (Model)
RitualConfig.INTERACTION_ID = "RitualCollection"
RitualConfig.ACTION_TEXT = "Simpan"
RitualConfig.OBJECT_TEXT = "Tempat Ritual"
RitualConfig.MAX_DISTANCE = 14

-- Urutan = urutan quest di GDD. Quest Kantil dan Kafan baru dibuat di Phase 5 dan 7.
RitualConfig.Offerings = table.freeze({
	{ questId = "KERIS", itemId = "KerisPusaka", obtainedState = "KERIS_OBTAINED", submittedState = "KERIS_SUBMITTED" },
	{
		questId = "KANTIL",
		itemId = "KembangKantilHitam",
		obtainedState = "CANTIL_BLACK_OBTAINED",
		submittedState = "CANTIL_SUBMITTED",
	},
	{ questId = "KAFAN", itemId = "KainKafan", obtainedState = "KAIN_OBTAINED", submittedState = "KAIN_SUBMITTED" },
} :: { Offering })

return table.freeze(RitualConfig)
