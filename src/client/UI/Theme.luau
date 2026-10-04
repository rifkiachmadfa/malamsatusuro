--!strict
-- Theme: satu-satunya tempat gaya GUI. Hitam-putih, panel hitam semi transparan, tanpa border.

local Theme = {}

Theme.Black = Color3.fromRGB(0, 0, 0)
Theme.White = Color3.fromRGB(255, 255, 255)
Theme.Muted = Color3.fromRGB(170, 170, 170)

Theme.PanelTransparency = 0.35
Theme.FontBody = Enum.Font.GothamMedium
Theme.FontBold = Enum.Font.GothamBold

return table.freeze(Theme)