AddCSLuaFile( "shared.lua" )

include('shared.lua')

function ENT:OnSubmerged()
	self.bSubmerged = true
	self:SetMoveType(MOVETYPE_FLY)
	self:CapabilitiesAdd(CAP_MOVE_SWIM | CAP_SKIP_NAV_GROUND_CHECK)
	self.currentPath = nil
	self:SetAIType(5)
	
	self.nextDirY = 0
	self.nextDirP = 0
	self.iDirectionY = 0
	self.iDirectionP = 0
	self.nextTrace = 0
	self.nextRandomDir = CurTime() +math.Rand(4,12)
end

function ENT:OnAfloat()
	self.bSubmerged = false
	self:SetMoveType(MOVETYPE_STEP)
	self:CapabilitiesRemove(CAP_MOVE_SWIM | CAP_SKIP_NAV_GROUND_CHECK)
	self.currentPath = nil
	self:SetAIType(2)
	self:SetAngles(Angle(0,self:GetAngles().y,0))
end

function ENT:GetEnemies()
	local tblPotentialEnemies = {}
	local bIgnorePlayers = tobool(GetConVarNumber("ai_ignoreplayers")) || self.bIgnorePlayers
	if !bIgnorePlayers then table.Add(tblPotentialEnemies,player.GetAll()) end
	if !self.bIgnoreNPCs then
		table.Add(tblPotentialEnemies,ents.FindByClass("npc_*"))
		table.Add(tblPotentialEnemies,ents.FindByClass("monster_*"))
		table.Add(tblPotentialEnemies,ents.FindByClass("obj_sentrygun"))
	end
	local tblEnemies = {}
	local posSelf = self:GetPos()
	for k, ent in pairs(tblPotentialEnemies) do
		local bNPC = ent:IsNPC()
		local bPlayer = ent:IsPlayer()
		if (bNPC || bPlayer) && !ent:GetNoTarget() then
			local posEnemy = ent:GetPos()
			local fDist = posSelf:Distance(posEnemy)
			local bIsPlayer = bPlayer && !ent:IsPossessing()
			local bIsNPC = bNPC
			local bValid = (bIsNPC && ent != self && ent:Health() > 0) || (bIsPlayer && ent:Alive())
			if bValid && fDist <= self.fViewDistance && !ent.bSelfDestruct then
				local bCanSee = self:InSight(ent) || (bIsNPC && fDist <= self.fHearDistance) || bIsPlayer && (fDist <= 75 || (fDist <= self.fHearDistance && !ent:Crouching() && (ent:KeyDown(IN_FORWARD) || ent:KeyDown(IN_BACK) || ent:KeyDown(IN_MOVELEFT) || ent:KeyDown(IN_MOVERIGHT) || ent:KeyDown(IN_JUMP))))
				local iDisposition = self:Disposition(ent)
				if bCanSee && self:Visible(ent) && (iDisposition == 1 || iDisposition == 2) && ent:WaterLevel() == 0 && (!bIsPlayer || !gamemode.Call("NPCCanSee",self,ent)) then
					table.insert(tblEnemies,ent)
				end
			end
		end
	end
	self:AddToMemory(tblEnemies)
	return tblEnemies
end

function ENT:UpdateMemory()
	local mem = self:GetMemory()
	for ent, data in pairs(mem) do
		local bValid = ValidEntity(ent)
		local iDisposition = bValid && self:Disposition(ent)
		if !bValid || ent:Health() <= 0 || self:OBBDistance(ent) > self.fViewDistance || ent:GetNoTarget() || (ent:IsPlayer() && (!ent:Alive() || tobool(GetConVarNumber("ai_ignoreplayers")))) || (iDisposition != 1 && iDisposition != 2) || ent:WaterLevel() > 0 || ent.bSelfDestruct then
			self:RemoveFromMemory(ent)
		end
	end
end

function ENT:UpdateEnemies()
	local num = self.iMemCount
	if self.entEnemy && (!ValidEntity(self.entEnemy) || self.entEnemy:Health() <= 0 || self.entEnemy:GetNoTarget() || self.entEnemy:WaterLevel() > 0 || (self.entEnemy:IsPlayer() && tobool(GetConVarNumber("ai_ignoreplayers"))) || self.entEnemy.bSelfDestruct) then self:RemoveFromMemory(self.entEnemy) end
	self:UpdateMemory()
	self:GetEnemies()
	local fDistClosest = self.fViewDistance
	local posSelf = self:GetPos()
	local enemyLast = self.entEnemy
	local mem = self:GetMemory()
	for ent, data in pairs(mem) do
		local posEnemy = ent:GetPos()
		local fDist = posSelf:Distance(posEnemy)
		if fDist < fDistClosest then
			self.entEnemy = ent
			fDistClosest = fDist
		end
	end
	if self.entEnemy != enemyLast then self:OnPrimaryTargetChanged(self.entEnemy) end
	
	if self.sSquad && self.tblSquadMembers && self.iMemCount > 0 then
		for _, ent in pairs(self.tblSquadMembers) do
			if !ValidEntity(ent) then self.tblSquadMembers[_] = nil
			else ent:MergeMemory(mem) end
		end
		table.refresh(self.tblSquadMembers)
	end
	if num == 0 && self.iMemCount > 0 then self:OnFoundEnemy(self.iMemCount); return
	elseif num > 0 && self.iMemCount == 0 then self:SetState(self:GetDefaultState()); self:OnAreaCleared(); self.tblMemBlockedNodeLinks = {} end
	return mem
end

function ENT:OnThink()
	if !self.bSubmerged && self:WaterLevel() >= 2 then self:OnSubmerged() end
	--if ValidEntity(self.entEnemy) then Entity(1):ChatPrint(self.entEnemy:WaterLevel()) end
	if ValidEntity(self.entEnemy) && self.entEnemy:WaterLevel() > 0 then self.entEnemy = NULL; return end
	if self.bSubmerged then
		if CurTime() >= self.nextIdle then
			self:PlaySound("Idle")
			self.nextIdle = CurTime() +math.Rand(4,16)
		end
		if self:WaterLevel() <= 1 then self:OnAfloat(); return end
		if !ValidEntity(self.entEnemy) then
			local posSelf = self:GetPos()
			if CurTime() >= self.nextDirY then
				local trForward = self:CreateTrace(posSelf +self:GetForward() *380)
				if trForward.HitWorld then
					local trRight = self:CreateTrace(posSelf +self:GetRight() *380)
					local trLeft = self:CreateTrace(posSelf +self:GetRight() *-380)
					local tr
					local fDistRight = posSelf:Distance(trRight.HitPos)
					local fDistLeft = posSelf:Distance(trLeft.HitPos)
					if fDistRight < fDistLeft then self.iDirectionY = 2
					elseif fDistLeft < fDistRight then self.iDirectionY = 1
					else self.iDirectionY = math.random(1,2) end
					self.nextDirY = CurTime() +math.Rand(1.2,2.6)
					self:NextThink(CurTime() +0.2)
					self.nextRandomDir = CurTime() +math.Rand(3,6)
				end
			else
				local ang = self:GetAngles()
				if self.iDirectionY == 1 then ang.y = ang.y -1
				else ang.y = ang.y +1 end
				self:SetAngles(ang)
				self:NextThink(CurTime() +0.01)
			end
			
			if CurTime() >= self.nextDirP then
				local trUp = self:CreateTrace(posSelf, MASK_WATER, posSelf +Vector(0,0,120))
				local fDistUp = posSelf:Distance(trUp.HitPos)
				if math.Round(fDistUp) < 120 then
					self.iDirectionP = 2
					self.nextDirP = CurTime() +math.Rand(1.6,2.6)
					self:NextThink(CurTime() +0.2)
				end
				local trDown = self:CreateTrace(posSelf -Vector(0,0,75))
				if trDown.HitWorld then
					self.iDirectionP = 1
					self.nextDirP = CurTime() +math.Rand(1.6,2.6)
					self:NextThink(CurTime() +0.2)
				elseif self:GetAngles().p > 0 then
					self.nextDirP = CurTime() +9999
					self.iDirectionP = 2
				end
			else
				local ang = self:GetAngles()
				if self.iDirectionP == 1 then
					if ang.p > -42 && ang.p < 0 then
						ang.p = ang.p -1
						self:NextThink(CurTime() +0.01)
						if CurTime() >= self.nextTrace then
							self.nextTrace = CurTime() +0.2
							local trUp = self:CreateTrace(posSelf, MASK_WATER, posSelf +Vector(0,0,160))
							local fDistUp = posSelf:Distance(trUp.HitPos)
							if math.Round(fDistUp) < 160 then
								self.iDirectionP = 2
							end
						end
					else
						if ang.p < 0 then
							local tr = self:CreateTrace(posSelf -Vector(0,0,75))
							if !tr.HitWorld then
								self.iDirectionP = 2
								self:NextThink(CurTime() +0.2)
							end
						else
							ang.p = ang.p -1
							if ang.p == 0 then self.nextDirP = 0 end
							self:NextThink(CurTime() +0.01)
						end
					end
				else
					ang.p = math.floor(ang.p) +1
					if ang.p == 0 then
						self.nextDirP = 0
					elseif ang.p >= 42 then
						self.iDirectionP = 1
						self:NextThink(CurTime() +0.2)
					end
					self:NextThink(CurTime() +0.01)
				end
				self:SetAngles(ang)
			end
			if CurTime() >= self.nextRandomDir then
				self.nextRandomDir = CurTime() +math.Rand(3,6)
				local rand = math.random(1,2)
				if rand == 1 then
					local trRight = self:CreateTrace(posSelf +self:GetRight() *380)
					local trLeft = self:CreateTrace(posSelf +self:GetRight() *-380)
					local fDistRight = posSelf:Distance(trRight.HitPos)
					local fDistLeft = posSelf:Distance(trLeft.HitPos)
					if math.Round(fDistRight) < 380 && math.Round(fDistLeft) < 380 then
						rand = 2
					else
						if fDistRight < fDistLeft then self.iDirectionY = 2
						elseif fDistLeft < fDistRight then self.iDirectionY = 1
						else self.iDirectionY = math.random(1,2) end
						self.nextDirY = CurTime() +math.Rand(0.6,3)
					end
				end
				if rand == 2 then
					local trUp = self:CreateTrace(posSelf, MASK_WATER, posSelf +Vector(0,0,380))
					local trDown = self:CreateTrace(posSelf -Vector(0,0,380))
					local fDistUp = posSelf:Distance(trUp.HitPos)
					local fDistDown = posSelf:Distance(trDown.HitPos)
					if math.Round(fDistUp) == 380 || math.Round(fDistDown) == 380 then
						if fDistUp < fDistDown then self.iDirectionP = 2
						elseif fDistDown < fDistUp then self.iDirectionP = 1
						else self.iDirectionP = math.random(1,2) end
						self.nextDirP = CurTime() +math.Rand(0.6,3)
					end
				end
			end
			self:PlayActivity(ACT_SWIM,false,nil,nil,true)
			self:SetLocalVelocity(self:GetForward() *80)
			self:SelectSchedule()
			return true
		end
		local pos
		for _, node in pairs(nodegraph.GetNodes(5)) do
			if #node.links == 1 then
				for _, data in pairs(node.links) do
					if data.type == 1 then
						pos = node.pos
						break
					end
				end
			end
		end
		if !pos then return end
		local path = self:GeneratePath(pos)
		if path then
			local numPath = #path
			if numPath > 0 then
				if self.currentNodePos && self.currentPathTime then
					local estTime
					if numPath > 1 then
						local yawA = (path[1].pos -posSelf):GetNormal():Angle().y
						local yawB = (path[1].pos -path[2].pos):GetNormal():Angle().y
						local yaw = (360 +yawA) -yawB
						--Entity(1):ChatPrint("YAW: " .. yaw)
						local sin = math.abs(math.cos(math.Deg2Rad(yaw)))
						estTime = 0.8 *sin
						util.CreateSpriteTrace(path[1].pos, path[1].pos +Vector(0,0,100), 6, 50, Color(255,0,0,255))
						util.CreateSpriteTrace(path[2].pos, path[2].pos +Vector(0,0,100), 6, 50, Color(0,0,255,255))
					else estTime = 0.8 end
					--Entity(1):ChatPrint("Estimated time: " .. estTime)
					if (self.currentNodePos == path[1].pos && self.currentPathTime > 0 && self.currentPathTime <= estTime) then --|| self:NearestPoint(path[1].pos):Distance(path[1].pos) <= 85 then
						table.remove(self.currentPath, 1)
						path = self.currentPath
						--Entity(1):ChatPrint("Path shortened!")
					end
				end
				if #path > 0 then
					local pos = path[1].pos
					local angToEnemy = (pos -self:GetPos()):Angle()
					local ang = self:GetAngles()
					local _ang = ang -angToEnemy
					_ang.y = math.floor(_ang.y)
					_ang.p = math.floor(_ang.p)
					while _ang.y < 0 do _ang.y = _ang.y +360 end
					while _ang.p < 0 do _ang.p = _ang.p +360 end
					while _ang.y > 360 do _ang.y = _ang.y -360 end
					while _ang.p > 360 do _ang.p = _ang.p -360 end
					if _ang.y > 0 && _ang.y <= 180 then ang.y = ang.y -1
					elseif _ang.y > 180 then ang.y = ang.y +1 end
					if _ang.p > 0 then
						if _ang.p < 180 then
							if ang.p > -42 then ang.p = ang.p -1 end
						else
							if ang.p < 42 then ang.p = ang.p +1 end
						end
					end
					self:SetAngles(ang)
					self:PlayActivity(ACT_SWIM,false,nil,nil,true)
					self:NextThink(CurTime())
					local vel = self:GetForward() *140
					if vel.z > 0 && self:WaterLevel() < 3 then vel.z = 0 end
					self:SetLocalVelocity(vel)
					return true
				end
			end --ChaseDirect
		end
	end
	self:UpdateLastEnemyPositions()
end
