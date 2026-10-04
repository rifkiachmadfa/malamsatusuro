--!strict
-- Spatial: helper posisi, dipakai server (validasi jarak) dan client (deteksi objek terdekat).

local Spatial = {}

function Spatial.getPosition(instance: Instance): Vector3?
	if instance:IsA("Model") then
		return instance:GetPivot().Position
	elseif instance:IsA("BasePart") then
		return instance.Position
	end
	return nil
end

-- Posisi HumanoidRootPart pemain, atau nil jika karakter tidak ada / sudah mati.
function Spatial.getCharacterPosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

return table.freeze(Spatial)