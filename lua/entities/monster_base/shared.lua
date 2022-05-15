ENT.Base = "base_entity"
ENT.Type = "ai"

ENT.PrintName		= ""
ENT.Author = "Silverlan"
ENT.Contact = "Silverlan@gmx.de"
ENT.Information		= ""
ENT.Purpose			= ""
ENT.Instructions	= ""

ENT.Spawnable = false
ENT.AdminSpawnable = false

ENT.AutomaticFrameAdvance = false

function ENT:OnRemove()
end

function ENT:PhysicsCollide(data, physobj)
end

function ENT:PhysicsUpdate(physobj)
end

function ENT:SetAutomaticFrameAdvance(bUsingAnim)
	self.AutomaticFrameAdvance = bUsingAnim
end
