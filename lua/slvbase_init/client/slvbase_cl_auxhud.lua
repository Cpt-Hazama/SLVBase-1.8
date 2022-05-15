hook.Add("InitPostEntity", "HLR_AUXPowers_InitFonts", function()
	surface.CreateFont("Coolvetica", ScrW() *0.015625, 400, true, false, "HLR_AUX_FONT1")
end)

local bShowHUD = true
usermessage.Hook("HLR_ShowAUXHud", function(um)
	bShowHUD = um:ReadBool()
end)

hook.Add("HUDPaint", "HLR_AUXPowers_HUDPaint", function()
	if !ValidEntity(LocalPlayer()) || !tobool(GetConVarNumber("sv_auxpowers")) || !bShowHUD then return end
	local w, h = ScrW(), ScrH()
	local bSprinting = LocalPlayer():KeyDown(IN_SPEED) && (LocalPlayer():KeyDown(IN_FORWARD) || LocalPlayer():KeyDown(IN_MOVELEFT) || LocalPlayer():KeyDown(IN_MOVERIGHT) || LocalPlayer():KeyDown(IN_BACK))
	local bUnderWater = LocalPlayer():WaterLevel() == 3
	local iHeight = 0.05833 *h
	if bSprinting then iHeight = iHeight +0.020833 *h end
	if bUnderWater then iHeight = iHeight +0.020833 *h end
	local iAuxPower = LocalPlayer():GetNetworkedInt("auxpower")
	if LocalPlayer():Alive() && (bSprinting || bUnderWater || iAuxPower < 100) then
		draw.RoundedBox(8, w *0.026875, h *0.89 -iHeight, w *0.15625, iHeight, Color(10,10,10,80))
		local iAuxScale = math.Round(iAuxPower *0.1)
		local col
		if iAuxScale > 1 then col = Color(255,255,0,200)
		else col = Color(255,0,0,200) end
		
		local posW = 0
		for i = 1, 10 do
			if i > iAuxScale then col.a = 50 end
			draw.RoundedBox(0.2, w *0.043 +posW, h *0.924 -iHeight, w *0.01, h *0.0075, col)
			posW = posW +w *0.0125
		end
		surface.SetFont("HLR_AUX_FONT1")
		col.a = 200
		draw.SimpleText("AUX POWER", "HLR_AUX_FONT1", w *0.077, h *0.91 -iHeight, col, 1, 1)
		if bUnderWater then draw.SimpleText("OXYGEN", "HLR_AUX_FONT1", w *0.068, h *0.95 -iHeight, col, 1, 1) end
		if bSprinting then draw.SimpleText("SPRINT", "HLR_AUX_FONT1", w *0.064, h *0.87, col, 1, 1) end
	end
	
	local iLightPower = LocalPlayer():GetNetworkedInt("flashlightpower")
	if LocalPlayer():FlashlightIsOn() || iLightPower < 100 then
		draw.RoundedBox(8, w *0.471875, h *0.9, w *0.05625, h *0.044166, Color(10,10,10,80))
		
		local col
		local iLightScale = math.Round(iLightPower *0.09)
		if iLightScale > 1 then col = Color(255,255,0,200) else col = Color(255,0,0,200) end
		
		local posW = 0
		for i = 1, 9 do
			if i > iLightScale then col.a = 50 end
			draw.RoundedBox(0, ScrW() *0.478 +posW, ScrH() *0.93, w *0.003125, h *0.0075, col)
			posW = posW +w *0.005
		end
	end
end)