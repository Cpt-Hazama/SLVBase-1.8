if !SinglePlayer() || !SLVBase_IsInstalledOnServer then return end
require("nodegraph")
local tblClientCMDs = {}
local function NewConVar(name, strDef)
	tblClientCMDs[name] = CreateClientConVar(name, strDef || "", false, false)
end
NewConVar("cl_hlr_nodegraph_nodes_ground_select")
NewConVar("cl_hlr_nodegraph_visibledist")
local tblGhostNodeEnts = {}
local function CreateNodeModel(node, id)
	local iType = node.type
	local tblEntsEffects = ents.FindByClass("class CLuaEffect")
	local effectdata = EffectData()
	effectdata:SetOrigin(node.pos)
	effectdata:SetScale(1)
	util.Effect("effect_cube", effectdata)
	local ent
	for k, v in pairs(ents.FindByClass("class CLuaEffect")) do
		if !table.HasValue(tblEntsEffects,v) then
			ent = v
			ent.nodeID = id
			local mdl = "models/editor/"
			if iType == 2 then mdl = mdl .. "Ground_node.mdl"
			elseif iType == 3 then mdl = mdl .. "Air_node.mdl"
			elseif iType == 4 then mdl = mdl .. "Climb_node.mdl"
			else mdl = mdl .. "Water_node.mdl" end
			ent:SetModel(mdl)
			if node.persistent then
				ent:SetColor(1,1,1,255)
				ent.persistent = true
			end
			break
		end
	end
	tblGhostNodeEnts[id] = ent
end

local iSelectedNode
concommand.Add("cl_hlr_nodegraph_nodes_select", function(pl,cmd,args)
	iSelectedNode = tonumber(args[1])
	for k, v in pairs(tblGhostNodeEnts) do
		if k != iSelectedNode then
			v:SetColor(255,255,255,255)
		else
			v:SetColor(255,0,0,255)
		end
	end
end)

local tblHulls = {
	[1] = {max = Vector(13, 13, 72), min = Vector(-13, -13, 0)},
	[2] = {max = Vector(20, 20, 40), min = Vector(-20, -20, 0)},
	[4] = {max = Vector(15, 15, 72), min = Vector(-15, -15, 0)},
	[8] = {max = Vector(12, 12, 24), min = Vector(-12, -12, 0)},
	[16] = {max = Vector(35, 35, 32), min = Vector(-35, -35, 0)},
	[32] = {max = Vector(16, 16, 64), min = Vector(-16, -16, 0)},
	[64] = {max = Vector(8, 8, 8), min = Vector(-8, -8, 0)},
	[128] = {max = Vector(40, 40, 100), min = Vector(-40, -40, 0)},
	[256] = {max = Vector(38, 38, 76), min = Vector(-38, -38, 0)},
	[512] = {max = Vector(18, 18, 100), min = Vector(-18, -18, 0)}
}
local iForceHullPerm = 0
local mat = Material("trails/laser")
local matTest = Material("tools/toolsnodraw")
local bGhostNode = false
local entGhostNode
local entNodeOver
local offset = 40
local entLinkSelectedA
local bKeyDown = false
local iNodeLinkType = 0
local function NodeGraph_ShowNodes(bShow, iType)
	if bShow then
		local color = Color(0,255,0,255)
		local tblNodes = nodegraph.GetNodes(iType)
		/*if iType == 2 then color = Color(0,255,0,255)
		elseif iType == 3 then color = Color(0,255,255,255)
		else color = Color(255,0,255,255) end*/
		if table.Count(tblGhostNodeEnts) > 0 then return end
		local pos = LocalPlayer():GetShootPos()
		local flDist = GetConVarNumber("cl_hlr_nodegraph_visibledist")
		for k, v in pairs(tblNodes) do
			if v.pos:Distance(pos) <= flDist then
				CreateNodeModel(v, k)
			end
		end
		local pl = LocalPlayer()
		hook.Add("RenderScreenspaceEffects", "HLR_NodeGraph_Menu_ShowNodes", function()
			local posShoot = pl:GetShootPos()
			local bLinkAValid
			flDist = GetConVarNumber("cl_hlr_nodegraph_visibledist")
			if ValidEntity(pl) then
				local tblGhostIDs = {}
				for k, v in pairs(tblGhostNodeEnts) do
					if tblNodes[v.nodeID].pos:Distance(posShoot) > flDist then
						v:Remove()
						tblGhostNodeEnts[k] = nil
					else table.insert(tblGhostIDs, v.nodeID) end
				end
				for k, v in pairs(tblNodes) do
					if !table.HasValue(tblGhostIDs, k) then
						if v.pos:Distance(posShoot) <= flDist then
							CreateNodeModel(v, k)
						end
					end
				end
				bLinkAValid = ValidEntity(entLinkSelectedA)
				if bLinkAValid && !pl:KeyDown(IN_USE) then
					entLinkSelectedA = nil
					bLinkAValid = false
					if !ValidEntity(entNodeOver) && ValidEntity(entGhostNode) then
						entGhostNode:SetColor(0,255,0,200)
					end
				end
				local wep = pl:GetActiveWeapon()
				if ValidEntity(wep) && wep:GetClass() == "gmod_tool" && wep.Mode == "hlr_nodegraph_create" then
					if input.IsKeyDown(KEY_PAD_PLUS) then
						if !bKeyDown then
							bKeyDown = true
							iNodeLinkType = iNodeLinkType +1
							if iNodeLinkType > 5 then iNodeLinkType = 0 end
							local mode
							if iNodeLinkType == 0 then mode = "Ground"
							elseif iNodeLinkType == 1 then mode = "Jump Up"
							elseif iNodeLinkType == 2 then mode = "Jump Down"
							elseif iNodeLinkType == 3 then mode = "Jump Wide"
							elseif iNodeLinkType == 4 then mode = "Crouch"
							else mode = "Ladder" end
							LocalPlayer():ChatPrint("Set Node Link Type to: " .. mode)
						end
					elseif bKeyDown then
						bKeyDown = false
					end
					if LocalPlayer():KeyDown(IN_RELOAD) then
						local off
						if LocalPlayer():KeyDown(IN_DUCK) then off = 2
						elseif LocalPlayer():KeyDown(IN_SPEED) then off = 8
						else off = 4 end
						if LocalPlayer():KeyDown(IN_FORWARD) then
							offset = offset +off
						elseif LocalPlayer():KeyDown(IN_BACK) then
							if offset -off < 40 then offset = 40
							else offset = offset -off end
						end
					end
					if !bGhostNode then
						bGhostNode = true
						local tblEntsEffects = ents.FindByClass("class CLuaEffect")
						local effectdata = EffectData()
						effectdata:SetOrigin(util.TraceLine(util.GetPlayerTrace(LocalPlayer())).HitPos)
						effectdata:SetScale(1)
						util.Effect("effect_cube", effectdata)
						local ent
						for k, v in pairs(ents.FindByClass("class CLuaEffect")) do
							if !table.HasValue(tblEntsEffects,v) then
								ent = v
								ent:SetColor(0,255,0,200)
								local mdl = "models/editor/"
								if iType == 2 then mdl = mdl .. "Ground_node.mdl"
								elseif iType == 3 then mdl = mdl .. "Air_node.mdl"
								elseif iType == 4 then mdl = mdl .. "Climb_node.mdl"
								else mdl = mdl .. "Water_node.mdl" end
								ent:SetModel(mdl)
								break
							end
						end
						entGhostNode = ent
					elseif ValidEntity(entGhostNode) then
						local tracePl = util.GetPlayerTrace(LocalPlayer())
						local tr = util.TraceLine(tracePl)
						local pos
						if iType != 3 && iType != 5 then
							pos = tr.HitPos
						else
							pos = tracePl.start +tr.Normal *offset
						end
						entGhostNode:SetPos(pos)
						if ValidEntity(entNodeOver) then
							local flDist = entGhostNode:GetPos():Distance(entNodeOver:GetPos())
							if flDist > 21 then
								if (!iSelectedNode || iSelectedNode != entNodeOver.nodeID) && !entNodeOver.persistent then entNodeOver:SetColor(255,255,255,255) end
								if !ValidEntity(entLinkSelectedA) then entGhostNode:SetColor(0,255,0,200) end
								entNodeOver = nil
							end
						else
							local tblEnts = ents.FindByClass("class CLuaEffect")
							local flDistMin = 21
							for k, v in pairs(tblEnts) do
								local flDist = v:GetPos():Distance(pos)
								if flDist < flDistMin && v.nodeID then
									flDistMin = flDist
									entNodeOver = v
								end
							end
							if ValidEntity(entNodeOver) && (!entNodeOver.persistent || ValidEntity(entLinkSelectedA)) then
								if !entNodeOver.persistent then
									entNodeOver:SetColor(255,0,0,255)
								end
								entGhostNode:SetColor(0,255,0,0)
							elseif !ValidEntity(entLinkSelectedA) then
								if entNodeOver && bGhostNode then
									entGhostNode:SetColor(0,255,0,200)
									entNodeOver = nil
								end
								cam.Start3D(EyePos(), EyeAngles())
									render.SetMaterial(mat)
									for k, v in pairs(tblNodes) do
										if v.pos:Distance(pos) <= 320 then
											local posStart = v.pos +Vector(0,0,3)
											local posEnd = pos +Vector(0,0,3)
											local tr = util.TraceLine({start = posStart, endpos = posEnd, mask = MASK_NPCWORLDSTATIC})
											if !tr.Hit then
												render.DrawBeam(posStart, posEnd, 10, 0, 0, color)
											end
										end
									end
								cam.End3D()
							end
						end
					else
						entGhostNode = nil
						bGhostNode = false
						if ValidEntity(entNodeOver) then
							if (!iSelectedNode || iSelectedNode != entNodeOver.nodeID) && !entNodeOver.persistent then entNodeOver:SetColor(255,255,255,255) end
						end
						entNodeOver = nil
					end
				elseif bGhostNode then
					bGhostNode = false
					if ValidEntity(entGhostNode) then entGhostNode:Remove() end
					entGhostNode = nil
					if ValidEntity(entNodeOver) then
						if (!iSelectedNode || iSelectedNode != entNodeOver.nodeID) && !entNodeOver.persistent then entNodeOver:SetColor(255,255,255,255) end
					end
					entNodeOver = nil
				end
			end
			//local tblNodesEnts = {}
			//for k, v in pairs(ents.FindByClass("class CLuaEffect")) do
			//	if v.nodeID then tblNodesEnts[v.nodeID] = v end
			//end
			local iHull = GetConVarNumber("cl_hlr_nodegraph_nodes_viewhulllinks")
			cam.Start3D(EyePos(), EyeAngles())
				render.SetMaterial(mat)
				for k, v in pairs(tblNodes) do
					//if tblNodesEnts[k] && EyePos():Distance(tblNodesEnts[k]:GetPos()) <= GetConVarNumber("cl_hlr_nodegraph_visibledist") then
						for _, link in pairs(v.links) do
							local col
							if (iHull == -1 || link.move &iHull == iHull) && link.dest > k && v.pos:Distance(posShoot) <= flDist && posShoot:Distance(tblNodes[link.dest].pos) <= flDist then //&& (!v.persistent || link.move > 0) then
								if bLinkAValid && (link.dest == entLinkSelectedA.nodeID || k == entLinkSelectedA.nodeID) then
									if ValidEntity(entNodeOver) && (entNodeOver.nodeID == k || entNodeOver.nodeID == link.dest) then col = Color(255,0,0,255)
									else col = Color(255,255,0,255) end
								elseif v.persistent && tblNodes[link.dest].persistent then col = Color(192,192,192,255)
								elseif link.move == 0 then col = Color(255,128,0,255)
								elseif link.type == 0 then col = color
								elseif link.type == 1 then col = Color(255,255,255,255)
								elseif link.type == 2 then col = Color(192,192,192,255)
								elseif link.type == 3 then col = Color(128,128,0,255)
								elseif link.type == 4 then col = Color(0,0,255,255)
								else col = Color(128,0,255,255) end
								render.DrawBeam(v.pos +Vector(0,0,3), tblNodes[link.dest].pos +Vector(0,0,3), 10, 0, 0, col)
							end
						end
					//end
				end
				if bLinkAValid && ValidEntity(entNodeOver) && entLinkSelectedA != entNodeOver then
					local bLinked
					for k, v in pairs(tblNodes[entLinkSelectedA.nodeID].links) do
						if (iHull == -1 || link.move &iHull == iHull) && v.dest == entNodeOver.nodeID then bLinked = true; break end
					end
					local col
					if !bLinked then
						local posStart = entLinkSelectedA:GetPos() +Vector(0,0,3)
						local posEnd = entNodeOver:GetPos() +Vector(0,0,3)
						local tr = util.TraceLine({start = posStart, endpos = posEnd, mask = MASK_NPCWORLDSTATIC})
						if !tr.Hit then col = Color(0,255,255,255)
						else col = Color(255,0,255,255) end
						render.DrawBeam(posStart, posEnd, 10, 0, 0, col)
					end
					if iHull != -1 then
						local posStart = entLinkSelectedA:GetPos() +Vector(0,0,3)
						local posEnd = entNodeOver:GetPos() +Vector(0,0,3)
						local col = col || Color(255,0,0,255)
						local bounds = tblHulls[iHull]
						local min, max = bounds.min, bounds.max
						local normal = (posEnd -posStart):GetNormal()
						local ang = normal:Angle()
						local right = ang:Right()
						local up = ang:Up()
						local posMin = posStart +normal *min.x
						local posMax = posEnd +normal *max.x
						for k, v in pairs({
											{posMin +right *min.y +up *min.z, posMax +right *min.y +up *min.z},
											{posMin -right *min.y +up *min.z, posMax -right *min.y +up *min.z},
											{posMin +right *max.y +up *max.z, posMax +right *max.y +up *max.z},
											{posMin -right *max.y +up *max.z, posMax -right *max.y +up *max.z},
											{posMin +right *min.y +up *min.z, posMin +right *min.y +up *max.z},
											{posMin -right *min.y +up *min.z, posMin -right *min.y +up *max.z},
											{posMax +right *min.y +up *min.z, posMax +right *min.y +up *max.z},
											{posMax -right *min.y +up *min.z, posMax -right *min.y +up *max.z},
											{posMin +right *min.y +up *min.z, posMin -right *min.y +up *min.z},
											{posMin +right *min.y +up *max.z, posMin -right *min.y +up *max.z},
											{posMax +right *min.y +up *min.z, posMax -right *min.y +up *min.z},
											{posMax +right *min.y +up *max.z, posMax -right *min.y +up *max.z}
										}) do
							render.DrawBeam(v[1], v[2], 10, 0, 0, col)
						end
					end
				end
			cam.End3D()
		end)
	else
		if ValidEntity(entGhostNode) then entGhostNode:Remove() end
		bGhostNode = false
		if ValidEntity(entNodeOver) then
			if (!iSelectedNode || iSelectedNode != entNodeOver.nodeID) && !entNodeOver.persistent then entNodeOver:SetColor(255,255,255,255) end
		end
		entNodeOver = nil
		for k, v in pairs(tblGhostNodeEnts) do
			if ValidEntity(v) then
				v:Remove()
			end
		end
		tblGhostNodeEnts = {}
		hook.Remove("RenderScreenspaceEffects", "HLR_NodeGraph_Menu_ShowNodes")
	end
end

concommand.Add("cl_hlr_nodegraph_nodes_ground_show", function(pl,cmd,args)
	NodeGraph_ShowNodes(tobool(args[1]), 2)
end)

concommand.Add("cl_hlr_nodegraph_nodes_air_show", function(pl,cmd,args)
	NodeGraph_ShowNodes(tobool(args[1]), 3)
end)

concommand.Add("cl_hlr_nodegraph_nodes_climb_show", function(pl,cmd,args)
	NodeGraph_ShowNodes(tobool(args[1]), 4)
end)

concommand.Add("cl_hlr_nodegraph_nodes_water_show", function(pl,cmd,args)
	NodeGraph_ShowNodes(tobool(args[1]), 5)
end)

local iTypeCur = 0
concommand.Add("cl_hlr_nodegraph_selecttool", function(pl,cmd,args)
	RunConsoleCommand("hlr_nodegraph_create_type", math.Clamp(iTypeCur +1,2,5))
	RunConsoleCommand("hlr_nodegraph_selecttool", iTypeCur)
end)

local hulls = {
	[1] = "human",
	[2] = "small_centered",
	[4] = "wide_human",
	[8] = "tiny",
	[16] = "wide_short",
	[32] = "medium",
	[64] = "tiny_centered",
	[128] = "large",
	[256] = "large_centered",
	[512] = "medium_tall"
}
concommand.Add("cl_hlr_nodegraph_hullsettings", function(pl,cmd,args)
	local panel = GetControlPanel("Manage nodegraph")
	panel:ClearControls()
	iForceHullPerm = 0
	for ID, hull in pairs(hulls) do
		local ctrl = panel:AddControl("CheckBox", {Label = "Force " .. hull .. " permission", Command = "cl_hlr_nodegraph_nodes_forcehullperm_" .. hull})
	end
	local cmd = iTypeCur == 1 && "cl_hlr_nodegraph_nodes_ground_menu" || iTypeCur == 2 && "cl_hlr_nodegraph_nodes_air_menu" || iTypeCur == 3 && "cl_hlr_nodegraph_nodes_climb_menu" || "cl_hlr_nodegraph_nodes_water_menu"
	panel:AddControl("Button", {Label = "Go back", Text = "nodegraph_hullsettings_goback", Command = cmd})
end)
for ID, hull in pairs(hulls) do
	local cmd = "cl_hlr_nodegraph_nodes_forcehullperm_" .. hull
	CreateClientConVar(cmd, 0, false, false)
	local function OnChange(cmd,prev,new)
		new = tonumber(new)
		if new == 0 then
			if iForceHullPerm &ID == ID then
				iForceHullPerm = iForceHullPerm -ID
			end
		elseif iForceHullPerm &ID != ID then iForceHullPerm = iForceHullPerm +ID end
	end
	cvars.AddChangeCallback(cmd, OnChange)
	timer.Simple(0, function() if GetConVarNumber(cmd) > 0 then OnChange(cmd,0,1) end end)
end
CreateClientConVar("cl_hlr_nodegraph_nodes_viewhulllinks", -1, false, false)

local function NodeGraph_SubMenu(iType)
	iTypeCur = iType
	RunConsoleCommand("hlr_nodegraph_create_type", iType +1)
	local panel = GetControlPanel("Manage nodegraph")
	panel:ClearControls()
	if !panel then return end
	local listbox = {}
	listbox.MenuButton = 0
	listbox.Height = 150
	listbox.Options = {}
	local cmdType
	local tbl = nodegraph.GetNodes(iType +1)
	if iType == 1 then
		listbox.Label = "Ground Nodes"
		cmdType = "ground"
	elseif iType == 2 then
		listbox.Label = "Air Nodes"
		cmdType = "air"
	elseif iType == 3 then
		listbox.Label = "Climb Nodes"
		cmdType = "climb"
	else
		listbox.Label = "Water Nodes"
		cmdType = "water"
	end
	for k, v in pairs(tbl) do
		listbox.Options[tostring(v.pos)] = {cl_hlr_nodegraph_nodes_select = k}
	end
	panel:AddControl("ListBox", listbox)
	panel:AddControl("CheckBox", {Label = "Show Nodes", Command = "cl_hlr_nodegraph_nodes_" .. cmdType .. "_show"})
	panel:AddControl("Slider", {Label = "Visible Node Distance", min = 1, max = 2000, Type = "Integer", Command = "cl_hlr_nodegraph_visibledist"})
	local options = {["Show all links"] = {cl_hlr_nodegraph_nodes_viewhulllinks = -1}}
	
	local iViewHullLinks = GetConVarNumber("cl_hlr_nodegraph_nodes_viewhulllinks")
	local optSelected
	for ID, hull in pairs(hulls) do
		options["Show " .. hull .. " links"] = {cl_hlr_nodegraph_nodes_viewhulllinks = ID}
		if iViewHullLinks == ID then optSelected = "Show " .. hull .. " links" end
	end
	local ctrl = vgui.Create("CtrlListBox", panel)
	for k, v in pairs(options) do
		v.id = nil
		ctrl:AddOption(k, v)
	end
	panel:AddPanel(ctrl)
	ctrl:SetText(optSelected || "Show all links")
	
	panel:AddControl("Button", {Label = "Hull Settings", Text = "Hull Settings", Command = "cl_hlr_nodegraph_hullsettings"})
	panel:AddControl("Button", {Label = "Nodegraph Tool", Text = "Nodegraph Tool", Command = "cl_hlr_nodegraph_selecttool"})
	panel:AddControl("Button", {Label = "Add", Text = "Add", Command = "cl_hlr_nodegraph_nodes_" .. cmdType .. "_add"})
	panel:AddControl("Button", {Label = "Remove", Text = "Remove", Command = "cl_hlr_nodegraph_nodes_" .. cmdType .. "_remove"})
	panel:AddControl("Button", {Label = "Go back", Text = "Go back", Command = "cl_hlr_nodegraph_main"})
end

local function AddNode(iMode, iType)
	local pl = LocalPlayer()
	local pos
	if iMode == 1 then
		if iType == 3 || iType == 5 then
			if ValidEntity(entGhostNode) then
				pos = entGhostNode:GetPos()
			else pos = util.TraceLine(util.GetPlayerTrace(pl)).HitPos end
		else
			pos = util.TraceLine(util.GetPlayerTrace(pl)).HitPos
		end
	else pos = LocalPlayer():GetPos() end
	local iNodeID = nodegraph.AddNode(pos, iType, iForceHullPerm)
	CreateNodeModel(nodegraph.GetNodes()[iNodeID], iNodeID)
	
	NodeGraph_SubMenu(iType -1)
end

concommand.Add("cl_hlr_nodegraph_nodes_tool_primary", function(pl,cmd,args)
	if pl:KeyDown(IN_USE) then
		local pl = LocalPlayer()
		local tracePl = util.GetPlayerTrace(pl)
		local tr = util.TraceLine(tracePl)
		local pos
		if iTypeCur != 2 && iTypeCur != 4 then pos = tr.HitPos
		else pos = tracePl.start +tr.Normal *offset end
		local entNode
		local tblEnts = ents.FindByClass("class CLuaEffect")
		
		local flDistMin = 21
		for k, v in pairs(tblEnts) do
			local flDist = v:GetPos():Distance(pos)
			if flDist < flDistMin && v.nodeID && (!v.persistent || ValidEntity(entLinkSelectedA)) then
				flDistMin = flDist
				entNode = v
			end
		end
		
		if !ValidEntity(entLinkSelectedA) then entLinkSelectedA = entNode
		elseif ValidEntity(entNode) then
			local entLinkSelectedB = entNode
			local iHull = GetConVarNumber("cl_hlr_nodegraph_nodes_viewhulllinks")
			if entNode == entLinkSelectedA then
				nodegraph.RemoveLink(entLinkSelectedA.nodeID, nil, iHull != -1 && iHull)
			else
				local iForceHullPerm = iForceHullPerm
				if iHull != -1 && iForceHullPerm &iHull != iHull then iForceHullPerm = iForceHullPerm +iHull end
				local bLinkExists
				for k, v in pairs(nodegraph.GetNodes(iTypeCur +1)[entLinkSelectedA.nodeID].links) do
					if v.dest == entNode.nodeID then
						bLinkExists = true
						nodegraph.RemoveLink(entLinkSelectedA.nodeID, v.dest, iHull != -1 && v.move &iHull == iHull && iHull || nil)
						if iHull != -1 && v.move &iHull != iHull then
							local hullMoveAdd = math.SplitByPowerOfTwo(iForceHullPerm)
							local iForceHullPermAdd = 0
							for k, v in pairs(math.SplitByPowerOfTwo(v.move)) do
								if !table.HasValue(hullMoveAdd, v) then iForceHullPermAdd = iForceHullPermAdd +v end
							end
							nodegraph.AddLink(entLinkSelectedA.nodeID, entNode.nodeID, iNodeLinkType, iForceHullPerm +iForceHullPermAdd)
						end
						break
					end
				end
				if !bLinkExists then nodegraph.AddLink(entLinkSelectedA.nodeID, entNode.nodeID, iNodeLinkType, iForceHullPerm) end
			end
		end
		return
	end
	local cmd
	if iTypeCur == 1 then cmd = "ground"
	elseif iTypeCur == 2 then cmd = "air"
	elseif iTypeCur == 3 then cmd = "climb"
	else cmd = "water" end
	if ValidEntity(entNodeOver) then
		iSelectedNode = entNodeOver.nodeID
		RunConsoleCommand("cl_hlr_nodegraph_nodes_" .. cmd .. "_remove", 2)
		if ValidEntity(entGhostNode) then
			entGhostNode:SetColor(0,255,0,200)
		end
	else
		RunConsoleCommand("cl_hlr_nodegraph_nodes_" .. cmd .. "_add", 1)
	end
end)

local function RemoveNode(iType, iMode)
	iMode = iMode || 1
	local tbl = nodegraph.GetNodes(iType +1)
	
	if iMode == 1 then
		if !iSelectedNode || !tbl[iSelectedNode] then return end
	else
		local pl = LocalPlayer()
		local tracePl = util.GetPlayerTrace(pl)
		local tr = util.TraceLine(tracePl)
		local pos
		if iType != 2 && iType != 4 then pos = tr.HitPos
		else pos = tracePl.start +tr.Normal *offset end
		local tblEnts = ents.FindByClass("class CLuaEffect")
		local entNode
		local flDistMin = 21
		for k, v in pairs(tblEnts) do
			local flDist = v:GetPos():Distance(pos)
			if flDist < flDistMin && v.nodeID then
				flDistMin = flDist
				entNode = v
			end
		end
		if !ValidEntity(entNode) then return end
		iSelectedNode = entNode.nodeID
		if !iSelectedNode || !tbl[iSelectedNode] then return end
	end
	nodegraph.RemoveNode(iSelectedNode)
	
	tblGhostNodeEnts[iSelectedNode]:Remove()
	tblGhostNodeEnts[iSelectedNode] = nil
	iSelectedNode = nil
	NodeGraph_SubMenu(iType)
end

concommand.Add("cl_hlr_nodegraph_nodes_ground_remove", function(pl,cmd,args)
	local iMode = tonumber(args[1]) || 1
	RemoveNode(1, iMode)
end)

concommand.Add("cl_hlr_nodegraph_nodes_ground_add", function(pl,cmd,args)
	local iMode = tonumber(args[1]) || 1
	AddNode(iMode, 2)
end)

concommand.Add("cl_hlr_nodegraph_nodes_air_remove", function(pl,cmd,args)
	local iMode = tonumber(args[1]) || 1
	RemoveNode(2, iMode)
end)

concommand.Add("cl_hlr_nodegraph_nodes_air_add", function(pl,cmd,args)
	local iMode = tonumber(args[1]) || 1
	AddNode(iMode, 3)
end)

concommand.Add("cl_hlr_nodegraph_nodes_climb_remove", function(pl,cmd,args)
	local iMode = tonumber(args[1]) || 1
	RemoveNode(3, iMode)
end)

concommand.Add("cl_hlr_nodegraph_nodes_climb_add", function(pl,cmd,args)
	local iMode = tonumber(args[1]) || 1
	AddNode(iMode, 4)
end)

concommand.Add("cl_hlr_nodegraph_nodes_water_remove", function(pl,cmd,args)
	local iMode = tonumber(args[1]) || 1
	RemoveNode(4, iMode)
end)

concommand.Add("cl_hlr_nodegraph_nodes_water_add", function(pl,cmd,args)
	local iMode = tonumber(args[1]) || 1
	AddNode(iMode, 5)
end)

concommand.Add("cl_hlr_nodegraph_nodes_save", function(pl)
	nodegraph.Save()
	LocalPlayer():ChatPrint("Nodegraph successfully saved!")
end)

concommand.Add("cl_hlr_nodegraph_reload", function(pl)
	nodegraph.Reload()
	LocalPlayer():ChatPrint("Nodegraph successfully reloaded!")
end)

concommand.Add("cl_hlr_nodegraph_nodes_ground_menu", function(pl)
	NodeGraph_SubMenu(1)
end)

concommand.Add("cl_hlr_nodegraph_nodes_air_menu", function(pl)
	NodeGraph_SubMenu(2)
end)

concommand.Add("cl_hlr_nodegraph_nodes_climb_menu", function(pl)
	NodeGraph_SubMenu(3)
end)

concommand.Add("cl_hlr_nodegraph_nodes_water_menu", function(pl)
	NodeGraph_SubMenu(4)
end)

local function NodeGraph_MainMenu(panel)
	RunConsoleCommand("hlr_nodegraph_create_type", 0)
	panel:AddControl("Button", {Label = "Ground Nodes", Text = "Ground Nodes", Command = "cl_hlr_nodegraph_nodes_ground_menu"})
	panel:AddControl("Button", {Label = "Air Nodes", Text = "Air Nodes", Command = "cl_hlr_nodegraph_nodes_air_menu"})
	panel:AddControl("Button", {Label = "Climb Nodes", Text = "Climb Nodes", Command = "cl_hlr_nodegraph_nodes_climb_menu"})
	panel:AddControl("Button", {Label = "Water Nodes", Text = "Water Nodes", Command = "cl_hlr_nodegraph_nodes_water_menu"})
	panel:AddControl("Button", {Label = "Save", Text = "Save", Command = "cl_hlr_nodegraph_nodes_save"})
	panel:AddControl("Button", {Label = "Reload Nodegraph", Text = "Reload Nodegraph", Command = "cl_hlr_nodegraph_reload"})
end

concommand.Add("cl_hlr_nodegraph_main", function(pl)
	local panel = GetControlPanel("Manage nodegraph")
	if panel then
		NodeGraph_ShowNodes(false)
		panel:ClearControls()
		NodeGraph_MainMenu(panel)
	end
end)

hook.Add("PopulateToolMenu", "HLR_Nodegraph_PopulateToolMenu", function()
	spawnmenu.AddToolMenuOption("Utilities", "Nodegraph Control", "Manage nodegraph", "Manage nodegraph", "", "", NodeGraph_MainMenu)
end)
