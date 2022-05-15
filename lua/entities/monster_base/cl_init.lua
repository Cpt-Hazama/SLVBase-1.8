include('shared.lua')

ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:Draw()
	self.Entity:DrawModel()
end

function ENT:DrawTranslucent()
end

function ENT:BuildBonePositions(NumBones, NumPhysBones)
end

function ENT:SetRagdollBones(bIn)
	self.m_bRagdollSetup = bIn
end

function ENT:DoRagdollBone(PhysBoneNum, BoneNum)
end

local matTrace = Material("trails/laser.vmt")
local matSprite = Material("sprites/blueglow2.vmt")
usermessage.Hook("slv_dbg_path",function(um)
	local numNodes = um:ReadShort()
	local nodes = {}
	local vecOffset = Vector(0,0,20)
	for i = 1,numNodes do
		table.insert(nodes,um:ReadVector() +vecOffset)
	end
	if(numNodes == 0) then return end
	local col = Color(255,0,0,255)
	local colSprite = Color(0,0,255,255)
	hook.Add("RenderScreenspaceEffects","ai_debug_drawpath", function()
		cam.Start3D(EyePos(),EyeAngles())
			for i = 1,numNodes do
				if(i > 1) then
					render.SetMaterial(matTrace)
					render.DrawBeam(nodes[i -1],nodes[i],60,1,1,col)
				end
				render.SetMaterial(matSprite)
				render.DrawSprite(nodes[i],80,80,colSprite)
			end
		cam.End3D()
	end)
end)