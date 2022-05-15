TOOL.Name = "Nodegraph Tool"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.AddToMenu = false

if CLIENT then
	TOOL.ClientConVar["type"] = 0
	language.Add("Tool_hlr_nodegraph_create_name", "Nodegraph Tool")
	language.Add("Tool_hlr_nodegraph_create_desc", "")
	language.Add("Tool_hlr_nodegraph_create_0", "Left-Click to create a node where you're looking at / Remove the node you're looking at, Right-Click to create a node at your position, + for changing the link type (Bots only).")
	
	concommand.Add("cl_hlr_nodegraph_tool_checkreload", function(pl,cmd,args)
		hook.Add("Think", "hlr_nodegraph_tool_checkreload", function()
			local pl = LocalPlayer()
			if !ValidEntity(pl) then return end
			if !pl:KeyDown(IN_RELOAD) then
				RunConsoleCommand("hlr_nodegraph_tool_reloadreleased")
				hook.Remove("Think", "hlr_nodegraph_tool_checkreload")
			end
		end)
	end)
end

function TOOL:LeftClick(trace)
	if CLIENT || self:GetClientNumber("type") == 0 then return end
	self:GetOwner():ConCommand("cl_hlr_nodegraph_nodes_tool_primary")
end

function TOOL:RightClick(trace)
	if CLIENT then return end
	local iType = self:GetClientNumber("type")
	if iType == 0 then return end
	local cmdNode
	if iType == 2 then cmdNode = "ground"
	elseif iType == 3 then cmdNode = "air"
	elseif iType == 4 then cmdNode = "climb"
	else cmdNode = "water" end
	self:GetOwner():ConCommand("cl_hlr_nodegraph_nodes_" .. cmdNode .. "_add 2")
end

function TOOL:Reload(trace)
	if CLIENT || self.Weapon.bFrozen || self:GetClientNumber("type") == 0 then return end
	local iType = self:GetClientNumber("type")
	if iType != 3 && iType != 5 then
		self:GetOwner():ConCommand("cl_hlr_nodegraph_nodes_tool_reload")
		return
	end
	self.Weapon.bFrozen = true
	self:GetOwner():Freeze(true)
	local owner = self:GetOwner()
	concommand.Add("hlr_nodegraph_tool_reloadreleased", function(pl,cmd,args)
		if pl != owner then return end
		concommand.Remove("hlr_nodegraph_tool_reloadreleased")
		pl:Freeze(false)
		self.Weapon.bFrozen = false
	end)
	self:GetOwner():ConCommand("cl_hlr_nodegraph_tool_checkreload")
end

function TOOL:Holster()
	if self.Weapon.bFrozen then
		pl:Freeze(false)
		self.Weapon.bFrozen = false
		concommand.Remove("hlr_nodegraph_tool_reloadreleased")
	end
end