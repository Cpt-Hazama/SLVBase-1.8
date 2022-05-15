if(SLVBase) then return end
require("datastream")
if SERVER then
	require("nodegraph")
	require("tracex")
	AI_TYPE_STATIC = 1
	AI_TYPE_GROUND = 2
	AI_TYPE_AIR = 3
	AI_TYPE_WATER = 5
end
/*require("navigation")
NODEGRAPH_GROUND = 1
NODEGRAPH_AIR = 2
NODEGRAPH_WATER = 3
local grid = 128

local navGround = CreateNav(grid)
local navAir = CreateNav(grid)
local navWater = CreateNav(grid)
navGround:SetDiagonal(true)
navAir:SetDiagonal(true)
navWater:SetDiagonal(true)
-- Load nodegraph
local numNodesGround = table.Count(navGround:GetNodes())
local numNodesAir = table.Count(navAir:GetNodes())
local numNodesWater = table.Count(navWater:GetNodes())
nodegraph = {
	GetNodes = function(graph)
		return graph == NODEGRAPH_GROUND && navGround:GetNodes() || graph == NODEGRAPH_AIR && navAir:GetNodes() || graph == NODEGRAPH_WATER && navWater:GetNodes() || nil
	end,
	Exists = function(graph)
		return graph == NODEGRAPH_GROUND && numNodesGround > 0 || graph == NODEGRAPH_AIR && numNodesAir > 0 || graph == NODEGRAPH_WATER && numNodesWater > 0 || false
	end,
	GetNav = function(graph)
		return graph == NODEGRAPH_GROUND && navGround || graph == NODEGRAPH_AIR && navAir || graph == NODEGRAPH_WATER && navWater || nil
	end,
	GetGroundNodes = function() return navGround:GetNodes() end,
	GetAirNodes = function() return navAir:GetNodes() end,
	GetWaterNodes = function() return navWater:GetNodes() end,
	GetGroundNav = function() return navGround end,
	GetAirNav = function() return navAir end,
	GetWaterNav = function() return navWater end,
	GetNode = function(type, ID)
		local ngraph = nodegraph.GetNav(type)
		return ngraph:GetNodeByID(ID)
	end,
	RemoveLinks = function(node)
		for i = 0, 7 do node:RemoveConnection(i) end
	end,
	AddLink = function(nodeA, nodeB)
		local conA = table.Copy(nodeA:GetConnections())
		if table.Count(conA) == 8 then return 0 end
		local conB = table.Copy(nodeB:GetConnections())
		if table.Count(conB) == 8 then return 1 end
		nodegraph.RemoveLinks(nodeA)
		nodegraph.RemoveLinks(nodeB)
		local i = 0
		for _, node in pairs(conA) do
			nodeA:ConnectTo(node, i)
			i = i +1
		end
		local iDir = i
		i = 0
		for _, node in pairs(conB) do
			nodeB:ConnectTo(node, i)
			i = i +1
		end
		iDir = (i > iDir && i || iDir) +1
		nodeA:ConnectTo(nodeB, iDir)
		return -1
	end,
	RemoveLink = function(type, nodeA, nodeB)
		local IDA = nodeA:GetID()
		local IDB = nodeB:GetID()
		local posA = nodeA:GetPosition()
		local normalA = nodeA:GetNormal()
		local connectionsA = nodeA:GetConnections()
		
		local posB = nodeB:GetPosition()
		local normalB = nodeB:GetNormal()
		local connectionsB = nodeB:GetConnections()
		
		local ngraph = nodegraph.GetNav(type)
		ngraph:RemoveNode(nodeA)
		ngraph:RemoveNode(nodeB)
		nodeA = ngraph:CreateNode(posA, normalA)
		nodeB = ngraph:CreateNode(posB, normalB)
		for _, nodeLink in ipairs(connectionsA) do
			if nodeLink:GetID() != IDB then
				nodeA:ConnectTo(nodeLink, 1)
				break
			end
		end
		
		for _, nodeLink in ipairs(connectionsB) do
			if nodeLink:GetID() != IDA then
				nodeB:ConnectTo(nodeLink, 1)
				break
			end
		end
		IDA, IDB = nodeA:GetID(), nodeB:GetID()
		return IDA, IDB
	end,
	CreateNode = function(type, pos, normal)
		local ngraph = nodegraph.GetNav(type)
		return ngraph:CreateNode(pos, normal)
	end,
	RemoveNode = function(type, node)
		local ngraph = nodegraph.GetNav(type)
		ngraph:RemoveNode(node)
	end,
	RemoveNodeByID = function(type, ID)
		local ngraph = nodegraph.GetNav(type)
		ngraph:RemoveNode(ngraph:GetNodeByID(ID))
	end
}*/

local tblAddonsDerived = {}
SLVBase = {
	AddDerivedAddon = function(name, tblInfo)
		print("Adding derived addon " .. name)
		tblAddonsDerived[name] = tblInfo
	end,
	AddonInitialized = function(name)
		print("Initializing derived addon " .. name)
		return !name || tblAddonsDerived[name] != nil
	end,
	GetDerivedAddons = function() return tblAddonsDerived end,
	GetDerivedAddon = function(name) return tblAddonsDerived[name] end,
	InitLua = function(dir)
		local _dir = "lua/" .. dir .. "/"
		local tblFiles = {client = {}, server = {}}
		for k, v in pairs(file.Find(_dir .. "*",true)) do
			if string.find(v, ".lua") then table.insert(tblFiles.client, v); table.insert(tblFiles.server, v)
			elseif v == "client" || v == "server" then
				for k, _v in pairs(file.Find(_dir .. v .. "/*",true)) do
					if string.find(_v, ".lua") then
						table.insert(tblFiles[v], v .. "/" .. _v)
					end
				end
			end
		end
		if CLIENT then
			for k, v in pairs(tblFiles.client) do
				include(dir .. "/" .. v)
			end
		else
			for k, v in pairs(tblFiles.client) do
				AddCSLuaFile(dir .. "/" .. v)
			end
			for k, v in pairs(tblFiles.server) do
				include(dir .. "/" .. v)
			end
		end
	end,
	AddNPC = function(Category,Name,Class,KeyValues,fOffset,bOnCeiling,bOnFloor)
		list.Set("NPC",Class,{Name = Name,Class = Class,Category = Category,Offset = fOffset,KeyValues = KeyValues,OnCeiling = bOnCeiling,OnFloor = bOnFloor})
	end,
	RegisterEntity = function(path,name,reload)
		local _ENT = _G.ENT
		ENT = {}
		local r = string.Right(path,1)
		if(r != "\/" && r != "\\") then path = path .. "/" end
		if(SERVER) then include(path .. name .. "/init.lua")
		else include(path .. name .. "/cl_init.lua") end
		pcall(scripted_ents.Register,ENT,name,reload)
		ENT = _ENT
	end,
	RegisterWeapon = function(path,name,reload)
		local _SWEP = _G.SWEP
		SWEP = {}
		local r = string.Right(path,1)
		if(r != "\/" && r != "\\") then path = path .. "/" end
		if(SERVER) then include(path .. name .. "/init.lua")
		else include(path .. name .. "/cl_init.lua") end
		pcall(weapons.Register,SWEP,name,reload)
		SWEP = _SWEP
	end
}

for _, particle in pairs({
		"svl_explosion",
		"blood_impact_red_01",
		"blood_impact_yellow_01",
		"blood_impact_green_01",
		"blood_impact_blue_01"
	}) do
	PrecacheParticleSystem(particle)
end

HITBOX_GENERIC = 100
HITBOX_HEAD = 101
HITBOX_CHEST = 102
HITBOX_STOMACH = 103
HITBOX_LEFTARM = 104
HITBOX_RIGHTARM = 105
HITBOX_LEFTLEG = 106
HITBOX_RIGHTLEG = 107
HITBOX_GEAR = 108
HITBOX_ADDLIMB = 109
HITBOX_ADDLIMB2 = 110

hook.Add("InitPostEntity", "SLV_PrecacheModels", function()
	local models = {}
	local function AddDir(path)
		for k, v in pairs(file.Find(path .. "*",true)) do
			if string.find(v, ".mdl") then
				table.insert(models, path .. v)
			end
		end
	end
	
	local function AddFile(file)
		table.insert(models, file)
	end
	for i = 1, 6 do AddFile("models/gibs/ice_shard0" .. i .. ".mdl") end
	
	for k, v in pairs(models) do
		util.PrecacheModel(v)
	end
	hook.Remove("InitPostEntity", "SLV_PrecacheModels")
end)

if CLIENT then
	if SinglePlayer() then SLVBase_IsInstalledOnServer = true
	else
		SLVBase_IsInstalledOnServer = false
		local addons = GetAddonList()
		for k, sAddon in pairs(addons) do
			local info = file.Read("addons/" .. sAddon .. "/info.txt",true)
			if info && string.find(info, "SLVBase") then
				local path = "addons/" .. sAddon
				SLVBase_IsInstalledOnServer = true
				hook.Add("InitPostEntity", "slv_waitforinit", function()
					datastream.StreamToServer("slv_checkvalid",1,nil,function(accepted)
						if accepted then
							SLVBase_IsInstalledOnServer = false
							local tblFilesWeapons = {}
							local tblFilesStools = {}
							local tblFilesEnts = {}
							local iTool
							local listWeapons = weapons.GetList()
							local listNPCs = list.Get("NPC")
							--local listEnts = scripted_ents.GetList()
							local listEntsSpawnable = scripted_ents.GetSpawnable()
							for k, data in pairs(listWeapons) do
								if data.Folder == "weapons/gmod_tool" then iTool = k; break end
							end
							for addon, info in pairs(tblAddonsDerived) do
								local path
								for _, addonName in pairs(addons) do
									if addonName != sAddon then
										local info = file.Read("addons/" .. addonName .. "/info.txt",true)
										if info && string.find(info, addon) then
											path = "addons/" .. addonName
											break
										end
									end
								end
								if path then
									table.Add(tblFilesWeapons, file.FindDir(path .. "/lua/weapons/*",true))
									if iTool && listWeapons[iTool].Tool then
										table.Add(tblFilesStools, file.Find(path .. "/lua/weapons/gmod_tool/stools/*.lua",true))
									end
									table.Add(tblFilesEnts, file.FindDir(path .. "/lua/entities/*",true))
									if info.Unload then info:Unload() end
								end
							end
							for k, class in pairs(tblFilesWeapons) do
								tblFilesWeapons[k] = "weapons/" .. class
							end
							for k, data in pairs(listWeapons) do
								if table.HasValue(tblFilesWeapons, data.Folder) then
									listWeapons[k].Spawnable = false
									listWeapons[k].AdminSpawnable = false
								end
							end
							if iTool && listWeapons[iTool].Tool then
								for k, file in pairs(tblFilesStools) do
									tblFilesStools[k] = string.sub(file, 1, string.len(file) -4)
								end
								for stool, data in pairs(listWeapons[iTool].Tool) do
									if table.HasValue(tblFilesStools, stool) then
										listWeapons[iTool]["Tool"][stool] = nil
									end
								end
							end
							for k, class in pairs(tblFilesEnts) do
								class = string.lower(class)
								if listNPCs[class] then list.Set("NPC", class, nil)
								elseif listEntsSpawnable[class] then
									local data = scripted_ents.Get(class)
									local tblData = {Spawnable = false, AdminSpawnable = false, Type = data.Type, Base = data.Base}
									scripted_ents.Register(tblData, class, true)
								end
							end
							RunConsoleCommand("spawnmenu_reload")
						end
					end)
				end)
				break
			end
		end
	end
else
	NPC_STATE_LOST = 8
	if !SinglePlayer() then
		hook.Add("AcceptStream", "SLVBase_CheckValidity", function(pl, handler, ID)
			if handler == "slv_checkvalid" then return false end
		end)
		umsg.Start("SLVBase_addons", ply);
			umsg.Short(table.Count(SLVBase.GetDerivedAddons()));
			for addon,data in pairs(SLVBase.GetDerivedAddons()) do
				umsg.String(addon);
			end
		umsg.End();
	end
end

usermessage.Hook("SLVBase_addons",function(um)
	local numAddons = um:ReadShort();
	local addons = SLVBase.GetDerivedAddons();
	for i=1,numAddons do
		local name = um:ReadString();
		if(!table.HasValue(addons,name)) then
			print("Addon ",name," not installed!");
		end
	end
end);
SLVBase.InitLua("slvbase_init")
