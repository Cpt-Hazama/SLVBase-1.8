SWEP.Spawnable = false
SWEP.AdminSpawnable = false

function SWEP:Initialize()
end

function SWEP:TranslateActivity(act)
	local owner = self.Owner
	return ValidEntity(owner) && owner:TranslateActivity(act) || act
end