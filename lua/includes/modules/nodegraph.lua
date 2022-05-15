require("aigraph")
require("a_star_pathfinding")
if(CLIENT && !SinglePlayer()) then return end
local map = game.GetMap()
local dir = "garrysmod/"
local flPathSub = "maps/graphs/" .. map .. ".ain"
for _,addon in ipairs(GetAddonList()) do	// Need to check addons first because of the way file.Read works.
	local dirAddon = "addons/" .. addon .. "/"
	if(file.Exists(dirAddon .. flPathSub,true)) then
		dir = dir .. dirAddon
		break
	end
end
local nodegraph_default,links = ParseGraphFile(dir .. flPathSub)
local bNoNodegraph
if(!nodegraph_default) then
	nodegraph_default = {}
	links = {}
	bNoNodegraph = true
	MsgN("WARNING: Unable to load nodegraph!")
end
local nodes = {}
local tblNodePositions = {}
for k, v in pairs(nodegraph_default) do
	if table.HasValue(tblNodePositions, v.pos) then
		nodegraph_default[k] = nil
	else
		tblNodePositions[k] = v.pos
	end
end
local nodesGround = {}
local nodesAir = {}
local nodesClimb = {}
local nodesWater = {}

local HULL_HUMAN = HULL_HUMAN
local HULL_SMALL_CENTERED = HULL_SMALL_CENTERED
local HULL_WIDE_HUMAN = HULL_WIDE_HUMAN
local HULL_TINY = HULL_TINY
local HULL_WIDE_SHORT = HULL_WIDE_SHORT
local HULL_MEDIUM = HULL_MEDIUM
local HULL_TINY_CENTERED = HULL_TINY_CENTERED
local HULL_LARGE = HULL_LARGE
local HULL_LARGE_CENTERED = HULL_LARGE_CENTERED
local HULL_MEDIUM_TALL = HULL_MEDIUM_TALL

local bEdited = false
local function InitCustomNodeSystem()
	if(bNoNodegraph) then return end
	local content = file.Read("nodegraph/" .. game.GetMap() .. ".txt")
	if(!content) then return end
	bEdited = true
	local bSuccess,data = pcall(glon.decode,content)
	if(!bSuccess) then
		MsgN("Unable to load nodegraph: '" .. data .. "'.")
		return
	end
	for ID,node in pairs(data.nodes) do
		node.ID = ID
		node.links = {}
	end
	for _,link in ipairs(data.links) do
		local ID = link[1]
		local dest = link[2]
		local move = link[3]
		local type = link[4]
		
		local node = data.nodes[ID]
		local tbLinkSrc = {
			dest = dest,
			move = move,
			type = type
		}
		table.insert(node.links,tbLinkSrc)
		local tbLinkTgt = table.Copy(tbLinkSrc)
		tbLinkTgt.dest = ID
		if(!nodes[dest]) then	-- If not a vanilla node
			table.insert(data.nodes[dest].links,tbLinkTgt)
		else
			table.insert(nodes[dest].links,tbLinkTgt)
		end
	end
	table.Merge(nodes,data.nodes)
	for ID, node in pairs(data.nodes) do
		if(node.type == 2) then nodesGround[ID] = node
		elseif(node.type == 3) then nodesAir[ID] = node
		elseif(node.type == 4) then nodesClimb[ID] = node
		elseif(node.type == 5) then nodesWater[ID] = node end
	end
end
local function GetHullID(iHull)
	if iHull == HULL_HUMAN then return 1
	elseif iHull == HULL_SMALL_CENTERED then return 2
	elseif iHull == HULL_WIDE_HUMAN then return 4
	elseif iHull == HULL_TINY then return 8
	elseif iHull == HULL_WIDE_SHORT then return 16
	elseif iHull == HULL_MEDIUM then return 32
	elseif iHull == HULL_TINY_CENTERED then return 64
	elseif iHull == HULL_LARGE then return 128
	elseif iHull == HULL_LARGE_CENTERED then return 256
	elseif iHull == HULL_MEDIUM_TALL then return 512 end
	return 0
end
debug.sethook()
for ID, node in pairs(nodegraph_default) do
	nodes[ID] = {ID = ID, persistent = true}
	for key,info in pairs(node) do
		if(key == "link") then
			nodes[ID].links = {}
			local links = {}
			for IDDest,link in pairs(info) do
				local nodeDest
				if(link.dest.pos != node.pos) then nodeDest = link.dest
				elseif(link.src.pos != node.pos) then nodeDest = link.src end
				if(nodeDest) then
					local IDDest
					for ID,pos in pairs(tblNodePositions) do
						if(pos == nodeDest.pos) then IDDest = ID; break end
					end
					if(IDDest && !links[IDDest]) then
						local move = 0
						for hull,mv in pairs(link.move) do
							if(mv > 0) then move = move +GetHullID(hull -1) end
						end
						table.insert(nodes[ID].links,{
							dest = IDDest,
							type = 0,
							move = move
						})
						links[IDDest] = true
					end
				end
			end
		/*elseif(key == "offset") then
			local iHull = 0
			local iHullCur = 1
			local i = 1
			while iHullCur <= 512 do
				if v[i] > 0 then iHull = iHull +iHullCur end
				i = i +1
				iHullCur = iHullCur *2
			end
			nodes[ID]["move"] = iHull*/
		elseif(key == "pos" || key == "info" || key == "yaw" || key == "zone" || key == "type") then
			nodes[ID][key] = info
		end
	end
end
for k, v in pairs(nodes) do
	if v.type == 2 then nodesGround[k] = v
	elseif v.type == 3 then nodesAir[k] = v
	elseif v.type == 4 then nodesClimb[k] = v end
end
InitCustomNodeSystem()

local ipairs = ipairs
local pairs = pairs
local table = table
local math = math
local util = util
local Vector = Vector
local astar = astar
local file = file
local game = game
local tostring = tostring
local timer = timer
local debug = debug
local glon = glon
local pcall = pcall
local MsgN = MsgN

module("nodegraph")

function GetNodes(iType)
	return !iType && nodes || iType == 2 && nodesGround || iType == 3 && nodesAir || iType == 4 && nodesClimb || iType == 5 && nodesWater
end

function Reload()
	InitCustomNodeSystem()
end

function GetGroundNodes()
	return nodesGround
end

function GetAirNodes()
	return nodesAir
end

function GetClimbNodes()
	return nodesClimb
end

function GetWaterNodes()
	return nodesWater
end

function IsEdited()
	return bEdited
end

function FindNodesInSphere(pos, dist, iType)
	local nodes = {}
	for _, node in pairs(GetNodes(iType)) do
		if node.pos:Distance(pos) <= dist then
			table.insert(nodes, node)
		end
	end
	return nodes
end

function GetNodeLinks(node, iType)
	if !node then return links || {} end
	iType = iType || 2
	for k, v in pairs(GetNodes(iType)) do
		if v.pos == node.pos then
			return v.link
		end
	end
	return {}
end

function GetClosestNode(pos, iType)
	iType = iType || 2
	local flDist = math.huge
	local node
	for k, v in pairs(GetNodes(iType)) do
		local _flDist = pos:Distance(v.pos)
		if _flDist < flDist /*&& !util.TraceLine({start = pos +Vector(0,0,3), v.pos +Vector(0,0,3)}).Hit*/ then	-- Visible?
			flDist = _flDist
			node = v
		end
	end
	return node
end

function Exists()
	return table.Count(nodes) > 0 || false
end

local function HullCanUsePath(iMove, iHull)
	local hullID = GetHullID(iHull)
	return iMove &hullID == hullID
end

function GeneratePath(posStart, posEnd, iType, iHull, fcLinkFilter)
	if !Exists() || table.IsEmpty(GetNodes(iType)) then return {} end
	local nodeStart = GetClosestNode(posStart, iType)
	local nodeEnd = GetClosestNode(posEnd, iType)
	local b, _path, nStatus = astar.CalculatePath(nodeStart, nodeEnd, function(node)
		local tblNeigh = {}
		for k, v in pairs(node.links) do
			table.insert(tblNeigh, nodes[v.dest])
		end
		return pairs(tblNeigh)
	end, function(nodeCur, nodeNeigh, nodeStart, nodeTarget, heuristic, ...)
		for k, v in pairs(nodeCur.links) do
			if nodes[v.dest].pos == nodeNeigh.pos then
				if (v.type == 2 && nodeCur.pos.z < nodeNeigh.pos.z) || (iHull && !HullCanUsePath(v.move, iHull)) then
					return false
				end
			end
		end
		return !fcLinkFilter || fcLinkFilter(nodeCur, nodeNeigh)
	end, function(nodeA, nodeB)
		return nodeA.pos:Distance(nodeB.pos)
	end, function(nodeCur, nodeNeigh, nodeStart, nodeTarget, heuristic, ...)
		return 1
	end)
	local path = {}
	for i = #_path, 1, -1 do
		path[(#_path +1) -i] = _path[i]
	end
	return path, nodeStart, nodeEnd
end

function CreateAstarObject(posStart, posEnd, iType, iHull, fcLinkFilter,heuristic)
	if !Exists() || table.IsEmpty(GetNodes(iType)) then return nil end
	local nodeStart = GetClosestNode(posStart, iType)
	local nodeEnd = GetClosestNode(posEnd, iType)
	local objAstar = astar.Create(nodeStart, nodeEnd, function(node)
		local tblNeigh = {}
		for k, v in pairs(node.links) do
			table.insert(tblNeigh, nodes[v.dest])
		end
		return pairs(tblNeigh)
	end, function(nodeCur, nodeNeigh, nodeStart, nodeTarget, heuristic, ...)
		for k, v in pairs(nodeCur.links) do
			if nodes[v.dest].pos == nodeNeigh.pos then
				if (v.type == 2 && nodeCur.pos.z < nodeNeigh.pos.z) || (iHull && !HullCanUsePath(v.move, iHull)) then
					return false
				end
			end
		end
		return !fcLinkFilter || fcLinkFilter(nodeCur, nodeNeigh)
	end, function(nodeA, nodeB)
		--local cost = (nodeB.pos.x -nodeA.pos.x)^2 +(nodeB.pos.y -nodeA.pos.y)^2 +(nodeB.pos.z -nodeA.pos.z)^2
		--return heuristic && heuristic(nodeA.pos,nodeB.pos,cost) || cost
		local cost = nodeA.pos:Distance(nodeB.pos)
		return heuristic && heuristic(nodeA.pos,nodeB.pos,cost) || cost
	end, function(nodeCur, nodeNeigh, nodeStart, nodeTarget, heuristic, ...)
		return 1
	end)
	return objAstar
end

local function HullAccessable(posStart, posEnd, hull)
	local tblTraces = {}
	local tblTrPos = {
		{start = Vector(0,0,(hull.max.z +hull.min.z) *0.5), endpos = Vector(0,0,(hull.max.z +hull.min.z) *0.5)},
		{start = Vector(0,0,hull.max.z), endpos = Vector(0,0,hull.max.z)},
		{start = Vector(0,0,hull.min.z), endpos = Vector(0,0,hull.min.z)},
		{start = Vector(hull.max.x,hull.max.y,(hull.max.z +hull.min.z) *0.5), endpos = Vector(hull.max.x,hull.max.y,(hull.max.z +hull.min.z) *0.5)},
		{start = Vector(hull.min.x,hull.min.y,(hull.max.z +hull.min.z) *0.5), endpos = Vector(hull.min.x,hull.min.y,(hull.max.z +hull.min.z) *0.5)},
		{start = Vector(hull.min.x,hull.min.y,hull.max.z), endpos = Vector(hull.max.x,hull.max.y,hull.max.z)},
		{start = Vector(hull.max.x,hull.max.y,hull.max.z), endpos = Vector(hull.min.x,hull.min.y,hull.max.z)},
		{start = Vector(hull.min.x,hull.min.y,hull.min.z), endpos = Vector(hull.max.x,hull.max.y,hull.min.z)},
		{start = Vector(hull.max.x,hull.max.y,hull.min.z), endpos = Vector(hull.min.x,hull.min.y,hull.min.z)},
		{start = Vector(hull.min.x,hull.min.y,hull.max.z), endpos = Vector(hull.min.x,hull.min.y,hull.min.z)},
		{start = Vector(hull.min.x,hull.min.y,hull.min.z), endpos = Vector(hull.min.x,hull.min.y,hull.max.z)},
		{start = Vector(hull.max.x,hull.max.y,hull.max.z), endpos = Vector(hull.max.x,hull.max.y,hull.min.z)},
		{start = Vector(hull.max.x,hull.max.y,hull.min.z), endpos = Vector(hull.max.x,hull.max.y,hull.max.z)}
	}

	for k, v in pairs(tblTrPos) do
		table.insert(tblTraces, util.TraceLine({start = posStart +v.start, endpos = posEnd +v.endpos, mask = MASK_NPCWORLDSTATIC}))
	end

	local tblTrPos = {hull.max, hull.min, Vector(hull.max.x, hull.max.y, hull.min.z), Vector(hull.min.x, hull.min.y, hull.max.z)}
	for k, v in pairs(tblTrPos) do
		table.insert(tblTraces, util.TraceLine({start = posStart +v, endpos = posEnd +v, mask = MASK_NPCWORLDSTATIC}))
		if k == 1 || k == 3 then
			table.insert(tblTraces, util.TraceLine({start = posStart +v, endpos = posEnd +tblTrPos[k +1], mask = MASK_NPCWORLDSTATIC}))
		else
			table.insert(tblTraces, util.TraceLine({start = posStart +v, endpos = posEnd +tblTrPos[k -1], mask = MASK_NPCWORLDSTATIC}))
		end
	end

	for k, v in pairs(tblTraces) do
		if v.Hit then return false end
	end
	return true
end

function AddLink(nodeIDStart, nodeIDEnd, iType, iForceHulls)
	local tblHulls = {
		HULL_HUMAN = {max = Vector(13, 13, 72), min = Vector(-13, -13, 0)},
		HULL_SMALL_CENTERED = {max = Vector(20, 20, 40), min = Vector(-20, -20, 0)},
		HULL_WIDE_HUMAN = {max = Vector(15, 15, 72), min = Vector(-15, -15, 0)},
		HULL_TINY = {max = Vector(12, 12, 24), min = Vector(-12, -12, 0)},
		HULL_WIDE_SHORT = {max = Vector(35, 35, 32), min = Vector(-35, -35, 0)},
		HULL_MEDIUM = {max = Vector(16, 16, 64), min = Vector(-16, -16, 0)},
		HULL_TINY_CENTERED = {max = Vector(8, 8, 8), min = Vector(-8, -8, 0)},
		HULL_LARGE = {max = Vector(40, 40, 100), min = Vector(-40, -40, 0)},
		HULL_LARGE_CENTERED = {max = Vector(38, 38, 76), min = Vector(-38, -38, 0)},
		HULL_MEDIUM_TALL = {max = Vector(18, 18, 100), min = Vector(-18, -18, 0)}
	}
	
	local nodeType = nodes[nodeIDStart].type
	if nodeType == 3 then
		for k, v in pairs(tblHulls) do
			v.max.z = v.max.z *0.5
			v.min.z = -v.max.z
		end
	end
	
	local tblHullIDs = {
		HULL_HUMAN = 1,
		HULL_SMALL_CENTERED = 2,
		HULL_WIDE_HUMAN = 4,
		HULL_TINY = 8,
		HULL_WIDE_SHORT = 16,
		HULL_MEDIUM = 32,
		HULL_TINY_CENTERED = 64,
		HULL_LARGE = 128,
		HULL_LARGE_CENTERED = 256,
		HULL_MEDIUM_TALL = 512
	}
	
	local nodeEnd = GetNodes(nodeType)[nodeIDEnd]
	local posEnd = nodeEnd.pos +Vector(0,0,3)
	local posStart = nodeEnd.pos +Vector(0,0,3)
	local iHullsAccessable = 0
	local forceHulls = iForceHulls || 0
	for k, v in pairs(tblHulls) do
		if forceHulls &tblHullIDs[k] == tblHullIDs[k] || HullAccessable(posStart, posEnd, v) then
			iHullsAccessable = iHullsAccessable +tblHullIDs[k]
		end
	end
	
	local tbl = nodeType == 2 && nodesGround || nodeType == 3 && nodesAir || nodeType == 4 && nodesClimb || nodesWater
	table.insert(tbl[nodeIDStart].links, {dest = nodeIDEnd, move = iHullsAccessable, type = iType})
	table.insert(tbl[nodeIDEnd].links, {dest = nodeIDStart, move = iHullsAccessable, type = iType})
end

function AddNode(pos, iType, iForceHulls)
	local iNodeID = 0
	for k, v in pairs(nodes) do
		if k > iNodeID then iNodeID = k end
	end
	iNodeID = iNodeID +1
	local links = {}
	
	local tblHulls = {
		HULL_HUMAN = {max = Vector(13, 13, 72), min = Vector(-13, -13, 0)},
		HULL_SMALL_CENTERED = {max = Vector(20, 20, 40), min = Vector(-20, -20, 0)},
		HULL_WIDE_HUMAN = {max = Vector(15, 15, 72), min = Vector(-15, -15, 0)},
		HULL_TINY = {max = Vector(12, 12, 24), min = Vector(-12, -12, 0)},
		HULL_WIDE_SHORT = {max = Vector(35, 35, 32), min = Vector(-35, -35, 0)},
		HULL_MEDIUM = {max = Vector(16, 16, 64), min = Vector(-16, -16, 0)},
		HULL_TINY_CENTERED = {max = Vector(8, 8, 8), min = Vector(-8, -8, 0)},
		HULL_LARGE = {max = Vector(40, 40, 100), min = Vector(-40, -40, 0)},
		HULL_LARGE_CENTERED = {max = Vector(38, 38, 76), min = Vector(-38, -38, 0)},
		HULL_MEDIUM_TALL = {max = Vector(18, 18, 100), min = Vector(-18, -18, 0)}
	}
	
	if iType == 3 then
		for k, v in pairs(tblHulls) do
			v.max.z = v.max.z *0.5
			v.min.z = -v.max.z
		end
	end
	
	local tblHullIDs = {
		HULL_HUMAN = 1,
		HULL_SMALL_CENTERED = 2,
		HULL_WIDE_HUMAN = 4,
		HULL_TINY = 8,
		HULL_WIDE_SHORT = 16,
		HULL_MEDIUM = 32,
		HULL_TINY_CENTERED = 64,
		HULL_LARGE = 128,
		HULL_LARGE_CENTERED = 256,
		HULL_MEDIUM_TALL = 512
	}
	
	local forceHulls = iForceHulls || 0
	for k, v in pairs(GetNodes(iType)) do
		if v.pos != pos && v.pos:Distance(pos) <= 320 then
			local tr = util.TraceLine({start = v.pos +Vector(0,0,3), endpos = pos +Vector(0,0,3), mask = MASK_NPCWORLDSTATIC})
			if !tr.Hit then
				local posStart = pos +Vector(0,0,3)
				local posEnd = v.pos +Vector(0,0,3)
				local iHullsAccessable = 0
				for k, v in pairs(tblHulls) do
					if iForceHulls &tblHullIDs[k] == tblHullIDs[k] || HullAccessable(posStart, posEnd, v) then
						iHullsAccessable = iHullsAccessable +tblHullIDs[k]
					end
				end
				table.insert(links, {dest = k, move = iHullsAccessable, type = 0})
				table.insert(v.links, {dest = iNodeID, move = iHullsAccessable, type = 0})
			end
		end
	end
	local node = {pos = pos, type = iType, zone = 0, yaw = 0, info = 0, links = links}
	if iType == 2 then nodesGround[iNodeID] = node
	elseif iType == 3 then nodesAir[iNodeID] = node
	elseif iType == 4 then nodesClimb[iNodeID] = node
	elseif iType == 5 then nodesWater[iNodeID] = node end
	nodes[iNodeID] = node
	return iNodeID
end

function RemoveNode(iNodeID)
	local iType = nodes[iNodeID].type
	nodes[iNodeID] = nil
	for k, v in pairs(nodes) do
		for _, link in pairs(v.links) do
			if link.dest == iNodeID then
				nodes[k].links[_] = nil
			end
		end
	end
	local tbl = iType == 2 && nodesGround || iType == 3 && nodesAir || iType == 4 && nodesClimb || nodesWater
	tbl[iNodeID] = nil
	for k, v in pairs(tbl) do
		for _, link in pairs(v.links) do
			if link.dest == iNodeID then
				tbl[k].links[_] = nil
			end
		end
	end
end

function RemoveLink(iNodeIDStart, iNodeIDEnd, iHullOnly)
	local iType = nodes[iNodeIDStart].type
	if !iHullOnly then
		if !iNodeIDEnd || iNodeIDStart == iNodeIDEnd then
			for k, v in pairs(nodes[iNodeIDStart].links) do
				for k, link in pairs(nodes[v.dest].links) do
					if link.dest == iNodeIDStart then
						table.remove(nodes[v.dest].links, k)
					end
				end
			end
			nodes[iNodeIDStart].links = {}
			return
		end
		for k, v in pairs(nodes[iNodeIDStart].links) do
			if v.dest == iNodeIDEnd then
				table.remove(nodes[iNodeIDStart].links, k)
				break
			end
		end
		for k, v in pairs(nodes[iNodeIDEnd].links) do
			if v.dest == iNodeIDStart then
				table.remove(nodes[iNodeIDEnd].links, k)
				break
			end
		end
		return
	end
	
	if !iNodeIDEnd || iNodeIDStart == iNodeIDEnd then
		for k, v in pairs(nodes[iNodeIDStart].links) do
			for k, link in pairs(nodes[v.dest].links) do
				if link.dest == iNodeIDStart then
					if v.move &iHullOnly == iHullOnly then
						nodes[v.dest].links[k].move = v.move -iHullOnly
					end
				end
			end
		end
		for k, v in pairs(nodes[iNodeIDStart].links) do
			if table.HasValue(math.SplitByPowerOfTwo(v.move), iHullOnly) then
				nodes[iNodeIDStart].links[k].move = v.move -iHullOnly
			end
		end
		return
	end
	for k, v in pairs(nodes[iNodeIDStart].links) do
		if v.dest == iNodeIDEnd then
			if v.move &iHullOnly == iHullOnly then
				nodes[iNodeIDStart].links[k].move = v.move -iHullOnly
			end
			break
		end
	end
	for k, v in pairs(nodes[iNodeIDEnd].links) do
		if v.dest == iNodeIDStart then
			if v.move &iHullOnly == iHullOnly then
				nodes[iNodeIDEnd].links[k].move = v.move -iHullOnly
			end
			break
		end
	end
end

function Save()
	local nodegraph = {nodes = {},links = {}}
	debug.sethook()
	for ID,node in pairs(nodes) do
		if(!node.persistent) then
			nodegraph.nodes[ID] = {
				pos = node.pos,
				type = node.type,
				yaw = node.yaw,
				info = node.info
			}
			for _, link in pairs(node.links) do
				table.insert(nodegraph.links,{ID,link.dest,link.move,link.type})
			end
		end
	end
	local bSuccess,data = pcall(glon.encode,nodegraph)
	if(!bSuccess) then
		MsgN("Unable to save nodegraph: '" .. data .. "'.")
		return
	end
	MsgN("Nodegraph saved successfully!")
	file.Write("nodegraph/" .. game.GetMap() .. ".txt",data)
end