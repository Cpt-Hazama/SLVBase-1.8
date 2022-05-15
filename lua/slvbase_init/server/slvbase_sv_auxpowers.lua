CreateConVar("sv_auxpowers", "0", {FCVAR_NOTIFY, FCVAR_REPLICATED})
local tblPlayers = {}
hook.Add("PlayerAuthed", "HLR_AUXPowers_PlayerInit", function(pl, steamID, uniqueID)
	tblPlayers[pl] = {nextAUXDrain = 0, iDrownDmg = 0}
	pl:SetNetworkedInt("auxpower", 100)
	pl:SetNetworkedInt("flashlightpower", 100)
end)

local meta = FindMetaTable("Player")
function meta:EnableAUXPowers()
	if tblPlayers[self] then return end
	tblPlayers[self] = {nextAUXDrain = 0, iDrownDmg = 0}
	self:SetNetworkedInt("auxpower", 100)
	self:SetNetworkedInt("flashlightpower", 100)
	umsg.Start("HLR_ShowAUXHud", self)
		umsg.Bool(true)
	umsg.End()
end

function meta:DisableAUXPowers()
	if !tblPlayers[self] then return end
	tblPlayers[self] = nil
	umsg.Start("HLR_ShowAUXHud", self)
		umsg.Bool(false)
	umsg.End()
end

function meta:AUXPowersEnabled()
	return tblPlayers[self] != nil
end

local bEnabled = tobool(GetConVarNumber("sv_auxpowers"))
hook.Add("Think", "HLR_AUXPowers_Think", function()
	if !tobool(GetConVarNumber("sv_auxpowers")) then
		if bEnabled then
			for pl, data in pairs(tblPlayers) do
				if ValidEntity(pl) then
					if data.speedRun then pl:SetRunSpeed(data.speedRun) end
					tblPlayers[pl] = {nextAUXDrain = 0, iDrownDmg = 0}
				end
			end
			bEnabled = false
			for k, v in pairs(player.GetAll()) do
				v:SetNetworkedInt("auxpower", 100)
				v:SetNetworkedInt("flashlightpower", 100)
			end
		end
		return
	end
	if !bEnabled then bEnabled = true end
	for pl, data in pairs(tblPlayers) do
		if ValidEntity(pl) then
			local iEnergyLight = pl:GetNetworkedInt("flashlightpower")
			if pl:FlashlightIsOn() then
				if !data.nextFLDrain || CurTime() >= data.nextFLDrain then
					tblPlayers[pl].nextFLDrain = CurTime() +0.6
					if iEnergyLight > 0 then pl:SetNetworkedInt("flashlightpower", iEnergyLight -1)
					else pl:Flashlight(false) end
				end
			elseif iEnergyLight < 100 then
				if !data.nextFLDrain || CurTime() >= data.nextFLDrain then
					tblPlayers[pl].nextFLDrain = CurTime() +0.04
					pl:SetNetworkedInt("flashlightpower", iEnergyLight +1)
				end
			end
			
			local iAuxPower = pl:GetNetworkedInt("auxpower")
			local bSprinting = pl:KeyDown(IN_SPEED) && (pl:KeyDown(IN_FORWARD) || pl:KeyDown(IN_MOVELEFT) || pl:KeyDown(IN_MOVERIGHT) || pl:KeyDown(IN_BACK))
			local bUnderWater = pl:WaterLevel() == 3
			if bSprinting || bUnderWater then
				if bSprinting && (iAuxPower == 100 || pl:KeyPressed(IN_SPEED)) then pl:EmitSound("player/suit_sprint.wav", 75, 100) end
				if CurTime() >= data.nextAUXDrain then
					local iDrain = bSprinting && bUnderWater && 2 || 1
					if bSprinting then tblPlayers[pl].nextAUXDrain = CurTime() +0.04 end
					if bUnderWater then tblPlayers[pl].nextAUXDrain = CurTime() +0.04 end
					if iAuxPower > 0 then
						local speedRun = pl:GetRunSpeed()
						if !tblPlayers[pl].speedRun || (tblPlayers[pl].speedRun != speedRun && speedRun != pl:GetWalkSpeed()) then tblPlayers[pl].speedRun = speedRun end
						pl:SetRunSpeed(tblPlayers[pl].speedRun)
						pl:SetNetworkedInt("auxpower", math.Clamp(iAuxPower -iDrain, 0, 100))
					else
						if bUnderWater && !data.nextDrownDmg then
							tblPlayers[pl].nextRecover = nil
							tblPlayers[pl].nextDrownDmg = CurTime() +6.5
							if !data.iDrownDmg then tblPlayers[pl].iDrownDmg = 0 end
						end
						pl:SetRunSpeed(pl:GetWalkSpeed())
					end
				end
			elseif iAuxPower < 100 then
				if CurTime() >= data.nextAUXDrain then
					tblPlayers[pl].nextAUXDrain = CurTime() +0.02
					pl:SetNetworkedInt("auxpower", iAuxPower +1)
				end
			end
			if data.nextDrownDmg then
				if CurTime() >= data.nextDrownDmg then
					tblPlayers[pl].nextDrownDmg = CurTime() +1
					local dmg = DamageInfo()
					dmg:SetDamage(10)
					dmg:SetDamageType(DMG_DROWN)
					dmg:SetAttacker(pl)
					dmg:SetInflictor(pl)
					pl:TakeDamageInfo(dmg)
					pl:ViewPunch(Angle(1,0,0))
					tblPlayers[pl].iDrownDmg = data.iDrownDmg +10
				end
				if !bUnderWater || !pl:Alive() then
					tblPlayers[pl].nextDrownDmg = nil
					if pl:Alive() then tblPlayers[pl].nextRecover = 0
					else tblPlayers[pl].iDrownDmg = 0 end
				end
			elseif data.nextRecover && CurTime() >= data.nextRecover && !bUnderWater && pl:Alive() then
				if data.iDrownDmg > 0 then
					local iHealth = pl:Health()
					local iHealthMax = pl:GetMaxHealth()
					if iHealth > iHealthMax then tblPlayers[pl].nextRecover = nil; tblPlayers[pl].iDrownDmg = nil; return end
					local iHealthAdd = math.Clamp(data.iDrownDmg, 0, 10)
					if iHealth +iHealthAdd > iHealthMax then iHealthAdd = iHealthMax -iHealth end
					pl:SetHealth(iHealth +iHealthAdd)
					tblPlayers[pl].iDrownDmg = data.iDrownDmg -10
					tblPlayers[pl].nextRecover = CurTime() +1.8
				else
					tblPlayers[pl].nextRecover = nil
					tblPlayers[pl].iDrownDmg = nil
				end
			end
		else tblPlayers[pl] = nil end
	end
end)
