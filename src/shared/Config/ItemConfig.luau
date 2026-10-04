--!strict
-- ItemConfig: definisi item quest (data saja). Item = Tool di Player.Backpack (ADR-018).
-- Template Tool dibuat user di Studio (ServerStorage.QuestTemplates), tidak masuk Git (ADR-011).

export type ItemDef = {
	displayName: string, -- nama tampilan di Backpack
	templateName: string, -- nama Tool di ServerStorage.QuestTemplates
	stackable: boolean, -- true: satu Tool dengan Attribute Count (nama "Daun Kelor x3")
	unique: boolean, -- true: pemain tidak boleh memegang lebih dari satu
}

local ItemConfig = {}

ItemConfig.TEMPLATE_FOLDER = "QuestTemplates" -- Folder di ServerStorage
ItemConfig.ATTR_ITEM_ID = "ItemId" -- diset server pada setiap Tool hasil clone
ItemConfig.ATTR_COUNT = "Count" -- hanya untuk item stackable
ItemConfig.MAX_STACK = 99

-- Kunci = ItemId. Daftar mengikuti GDD bagian "Important Items".
ItemConfig.Items = table.freeze({
	DaunKelor = { displayName = "Daun Kelor", templateName = "DaunKelor", stackable = true, unique = false },
	KunciPeti = { displayName = "Kunci Peti", templateName = "KunciPeti", stackable = false, unique = true },
	KerisPusaka = { displayName = "Keris Pusaka", templateName = "KerisPusaka", stackable = false, unique = true },
	MawarMerah = { displayName = "Mawar Merah", templateName = "MawarMerah", stackable = true, unique = false },
	MawarPutih = { displayName = "Mawar Putih", templateName = "MawarPutih", stackable = true, unique = false },
	Melati = { displayName = "Melati", templateName = "Melati", stackable = true, unique = false },
	KantilKuning = { displayName = "Kantil Kuning", templateName = "KantilKuning", stackable = true, unique = false },
	KembangKantilHitam = {
		displayName = "Kembang Kantil Hitam",
		templateName = "KembangKantilHitam",
		stackable = false,
		unique = true,
	},
	MinyakZaitun = { displayName = "Minyak Zaitun", templateName = "MinyakZaitun", stackable = true, unique = false },
	KainKafan = { displayName = "Kain Kafan", templateName = "KainKafan", stackable = false, unique = true },
} :: { [string]: ItemDef })

return table.freeze(ItemConfig)
