include('shared.lua')

local iHealth = 0
usermessage.Hook("HLR_Possessor_PossessionStart", function(um)
	local name = um:ReadString()
	local iHealthMax = um:ReadShort()
	iHealth = um:ReadShort()
	hook.Add("HUDPaint", "HLR_Possessor_HUDPaint", function()
		local w, h = ScrW(), ScrH()
		surface.SetFont("HLR_AUX_FONT1")
		local iSizeText = surface.GetTextSize(name)
		local iSizeHealthMax = iSizeText
		local iSizeHealthMin = w *0.05
		if iSizeHealthMax < iSizeHealthMin then iSizeHealthMax = iSizeHealthMin end
		local iSizeHealth = (iSizeHealthMax /iHealthMax) *iHealth
		iSizeHealth = iSizeHealth +w *0.00375
		iSizeHealthMax = iSizeHealthMax +w *0.00375
		local iSizeBoxBG = iSizeHealthMax +w *0.015
		
		draw.RoundedBox(8, w *0.5 -iSizeBoxBG *0.5, h *0.025, iSizeBoxBG, h *0.044166, Color(10,10,10,150))
		draw.SimpleText(name, "HLR_AUX_FONT1", w *0.5, h *0.0425, Color(255,255,255,255), 1, 1)
		
		if iHealth <= 0 then return end
		draw.RoundedBox(4, w *0.5 -iSizeHealthMax *0.5, h *0.0525, iSizeHealthMax, h *0.008333, Color(10,10,10,200))
		draw.RoundedBox(4, w *0.5 -iSizeHealthMax *0.5, h *0.0525, iSizeHealth, h *0.008333, Color(255,20,20,255))
	end)
end)

usermessage.Hook("HLR_Possessor_UpdateHealth", function(um)
	iHealth = um:ReadLong()
end)

usermessage.Hook("HLR_Possessor_PossessionEnd", function(um)
	hook.Remove("HUDPaint", "HLR_Possessor_HUDPaint")
end)

function ENT:Draw()
end
