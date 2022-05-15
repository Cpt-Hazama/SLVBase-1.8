datastream.Hook("hlr_npccontrol_menu_npcspawner_create", function(pl, handler, id, encoded, data)
	if HLR_NPCControl_Tools_AdminOnly["NPCSpawner"] == 0 && !pl:IsAdmin() then
		pl:SendLua("GAMEMODE:AddNotify(\"Sorry, this tool is for admins only!\", NOTIFY_HINT, 5);surface.PlaySound( \"buttons/button10.wav\" )") 
		return
	end
	local ent = ents.Create("obj_npcspawner")
	ent:SetPos(data.pos)
	ent:SetAngles(Angle(0,data.yaw,0))
	ent:SetNPCClass(data.class)
	ent:SetNPCBurrowed(data.burrowed)
	ent:SetNPCKeyValues(data.keyvalues)
	if string.len(data.equip) > 0 then ent:SetNPCEquipment(data.equip) end
	if data.spawnflags > 0 then ent:SetNPCSpawnflags(data.spawnflags) end
	ent:SetEntityOwner(pl)
	ent:SetKeyTurnOn(data.iKeyTurnOn)
	ent:SetKeyTurnOff(data.iKeyTurnOff)
	ent:SetSpawnDelay(data.delay)
	ent:SetMaxNPCs(data.max)
	ent:SetStartOn(data.startOn)
	ent:SetPatrolWalk(data.ppointsData.walk)
	ent:SetPatrolType(data.ppointsData.ptype)
	ent:SetStrictMovement(data.ppointsData.strict)
	ent:SetDeleteOnRemove(data.deleteOnRemove)
	if string.len(data.squad) > 0 then ent:SetSquad(data.squad) end
	for k, v in pairs(data.tblPatrolPoints) do
		ent:AddPatrolPoint(v)
	end
	ent:Spawn()
	ent:Activate()
	
	undo.Create("SENT")
		undo.AddEntity(ent)
		undo.SetPlayer(pl)
		undo.SetCustomUndoText("Undone NPC Spawner")
	undo.Finish("Scripted Entity (NPC Spawner)")
	
	cleanup.Register("obj_npcspawner")
	cleanup.Add(pl, "NPC Spawner", ent)
end)

local tblCustomRelationships = {}
hook.Add("OnEntityCreated", "HLR_NPCControl_npcrelationships", function(ent)
	timer.Simple(0, function()
		if ValidEntity(ent) && ent:IsNPC() then
			local class = ent.ClassName || ent:GetClass()
			for k, v in pairs(tblCustomRelationships) do
				if v.src == class then
					local bRevert = v.revert
					local rel = v.rel
					for k, v in pairs(ents.FindByClass(v.tgt)) do
						if ValidEntity(v) && (v:IsNPC() || v:IsPlayer()) then
							ent:AddEntityRelationship(v, rel, 10)
							if bRevert && v:IsNPC() then
								v:AddEntityRelationship(ent, rel, 10)
							end
						end
					end
				elseif v.tgt == class then
					local bRevert = v.revert
					local rel = v.rel
					for k, v in pairs(ents.FindByClass(v.src)) do
						if ValidEntity(v) && (v:IsNPC() || v:IsPlayer()) then
							v:AddEntityRelationship(ent, rel, 10)
							if bRevert && v:IsNPC() then
								ent:AddEntityRelationship(v, rel, 10)
							end
						end
					end
				end
			end
		end
	end)
end)

local function AddRelationship(classSource, classTarget, rel, bRevert)
	for k, entSrc in pairs(ents.FindByClass(classSource)) do
		if ValidEntity(entSrc) && (entSrc:IsNPC() || entSrc:IsPlayer()) then
			for k, entTgt in pairs(ents.FindByClass(classTarget)) do
				if ValidEntity(entTgt) && (entTgt:IsNPC() || entTgt:IsPlayer()) then
					if !entSrc:IsPlayer() then entSrc:AddEntityRelationship(entTgt, rel, 10) end
					if bRevert then
						if !entTgt:IsPlayer() then entTgt:AddEntityRelationship(entSrc, rel, 10) end
					end
				end
			end
		end
	end
end

concommand.Add("hlr_npccontrol_menu_npcrelationships_apply", function(pl,cmd,args)
	if HLR_NPCControl_Tools_AdminOnly["NPCRelationships"] == 0 && !pl:IsAdmin() then
		pl:SendLua("GAMEMODE:AddNotify(\"Sorry, this tool is for admins only!\", NOTIFY_HINT, 5);surface.PlaySound( \"buttons/button10.wav\" )") 
		return
	end
	local classSource = args[1]
	local classTarget = args[2]
	local rel = args[3]
	if rel == "like" then rel = 3
	elseif rel == "hate" then rel = 1
	elseif rel == "fear" then rel = 2
	else rel = 4 end
	local bRevert = tobool(tonumber(args[4]))
	local iExists = args[5]
	if iExists then
		for k, v in pairs(tblCustomRelationships) do
			if (v.src == classSource && v.tgt == classTarget) || (v.revert && v.tgt == classSource && v.src == classTarget) then
				tblCustomRelationships[k].rel = rel
				break
			end
		end
	else
		table.insert(tblCustomRelationships, {src = classSource, tgt = classTarget, rel = rel, revert = bRevert})
	end
	AddRelationship(classSource, classTarget, rel, bRevert)
end)

datastream.Hook("hlr_npccontrol_menu_npcrelationships_load", function(pl, handler, id, encoded, data)
	if !pl:IsAdmin() || !data then return end
	tblCustomRelationships = {}
	for k, v in pairs(data) do
		local rel = v.rel
		if rel == "like" then rel = 3
		elseif rel == "hate" then rel = 1
		elseif rel == "fear" then rel = 2
		else rel = 4 end
		tblCustomRelationships[k] = {src = v.src, tgt = v.tgt, rel = rel, revert = tobool(v.revert)}
		AddRelationship(v.src, v.tgt, rel, tobool(v.revert))
	end
end)


concommand.Add("hlr_npccontrol_menu_npcrelationships_remove", function(pl,cmd,args)
	local iRel = tonumber(args[1])
	if !iRel || !tblCustomRelationships[iRel] then return end
	local bReverse = tobool(tonumber(args[2]))
	if bReverse then
		tblCustomRelationships[iRel].revert = false
	else
		if tblCustomRelationships[iRel].revert then
			tblCustomRelationships[iRel].revert = false
			local tgt = tblCustomRelationships[iRel].src
			tblCustomRelationships[iRel].src = tblCustomRelationships[iRel].tgt
			tblCustomRelationships[iRel].tgt = tgt
		else
			tblCustomRelationships[iRel] = nil
		end
	end
end)

concommand.Add("hlr_nodegraph_selecttool", function(pl,cmd,args)
	if !ValidEntity(pl) then return end
	pl:SelectWeapon("gmod_tool")
	pl:ConCommand("gmod_tool hlr_nodegraph_create")
end)

HLR_NPCControl_Tools_AdminOnly = {}
local function AddAdminToolCmd(cmd, name, default)
	HLR_NPCControl_Tools_AdminOnly[name] = default
	concommand.Add(cmd, function(pl,cmd,args)
		if !pl:IsAdmin() || !tonumber(args[1]) then return end
		local value = tonumber(args[1])
		HLR_NPCControl_Tools_AdminOnly[name] = value
		
		local rp = RecipientFilter()
		rp:AddAllPlayers(v)
		
		umsg.Start("HLR_AdminSettings_UpdateCVar", rp)
			umsg.String("cl_" .. cmd)
			umsg.Long(value)
		umsg.End()
	end)
end
AddAdminToolCmd("hlr_npccontrol_menu_adminsettings_allow_npcviewcam", "NPCViewcam", 1)
AddAdminToolCmd("hlr_npccontrol_menu_adminsettings_allow_npcspawner", "NPCSpawner", 1)
AddAdminToolCmd("hlr_npccontrol_menu_adminsettings_allow_npcrelationships", "NPCRelationships", 0)
AddAdminToolCmd("hlr_npccontrol_menu_adminsettings_allow_npccontroller", "NPCController", 1)
AddAdminToolCmd("hlr_npccontrol_menu_adminsettings_allow_npchealth", "NPCHealth", 0)
AddAdminToolCmd("hlr_npccontrol_menu_adminsettings_allow_npcmovement", "NPCMovement", 1)
AddAdminToolCmd("hlr_npccontrol_menu_adminsettings_allow_npcnotarget", "NPCNoTarget", 0)
AddAdminToolCmd("hlr_npccontrol_menu_adminsettings_allow_npcfollower", "NPCFollower", 0)