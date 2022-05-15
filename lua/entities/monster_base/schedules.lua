function ENT:RunAI(strExp)
	if self:KnockedDown() then return true end
	if !self:IsPossessed() then
		local act = self:GetMovementActivity()
		if self.actCMove then
			if act != self.actCMove then
				if self.CurrentSchedule != self.customMoveSched then
					self.actCMove = nil
					return self:RunAI(strExp)
				end
				self:SetMovementActivity(self.actCMove)
			end
		elseif act == ACT_WALK then self:SetMovementActivity(self:GetWalkActivity())
		elseif act == ACT_RUN then self:SetMovementActivity(self:GetRunActivity()) end
	end
	if self.m_actArrival && self:IsMoving() && self:GetArrivalActivity() != self.m_actArrival then
		self:SetArrivalActivity(self.m_actArrival)
	else
		local act = self:GetIdleActivity()
		if(act != ACT_IDLE) then
			self:SetArrivalActivity(act)
			self:SetArrivalSpeed(1000)
		end
	end
	if self:IsRunningBehavior() || self:DoingEngineSchedule() then return true end
	if self.CurrentSchedule then self:DoSchedule(self.CurrentSchedule) end
	if !self.m_bAIInitialized then
		if self.m_tbOnAIInit then
			for _, fc in ipairs(self.m_tbOnAIInit) do
				fc()
			end
		end
		self.m_bAIInitialized = true
	end
	if !self.CurrentSchedule || self.CurrentSchedule.bForceSelSched then self:SelectSchedule() end
	self:MaintainActivity()
end

function ENT:StartSchedule(schedule)
	if(self.m_moveTo && !schedule.Move) then
		if(!self.m_moveTo.interrupt) then return end
		if(!schedule.Move) then self.m_moveTo = nil end
	end
	self.CurrentSchedule = schedule
	self.CurrentTaskID = 1
	self:SetTask(schedule:GetTask(1))
	if(schedule.ArrivalSpeed) then self:SetArrivalSpeed(schedule.ArrivalSpeed) end
end

function ENT:GetScheduleName(schd)
	schd = schd || self.CurrentSchedule
	return schd && schd.Name || ""
end

function ENT:ScheduleFinished()
	self.CurrentSchedule 	= nil
	self.CurrentTask 		= nil
	self.CurrentTaskID 		= nil
end

function ENT:SetTask(task)
	self.CurrentTask = task
	self.bTaskComplete = false
	self.TaskStartTime = CurTime()
	
	self:StartTask(self.CurrentTask)
	if(self.CurrentSchedule && self.CurrentSchedule.ArrivalSpeed) then self:SetArrivalSpeed(self.CurrentSchedule.ArrivalSpeed) end
end

function ENT:NextTask(schedule)
	if !schedule || !self then return end
	self.CurrentTaskID = self.CurrentTaskID +1
	
	if self.CurrentTaskID > schedule:NumTasks() then
		self:ScheduleFinished(schedule)
		return
	end
	self:SetTask(schedule:GetTask(self.CurrentTaskID))	
end

function ENT:StartTask(task)
	task:Start(self)
end

function ENT:RunTask(task)
	if !task || !self then return end
	task:Run(self)
end

function ENT:TaskTime()
	return CurTime() -self.TaskStartTime
end

function ENT:OnTaskComplete()
	self.bTaskComplete = true
end

function ENT:TaskFinished()
	return self.bTaskComplete
end

function ENT:StartEngineTask(iTaskID, TaskData)
end

function ENT:RunEngineTask(iTaskID, TaskData)
end

function ENT:StartEngineSchedule(scheduleID)
	self:ScheduleFinished()
	self.bDoingEngineSchedule = true
end
function ENT:EngineScheduleFinish() self.bDoingEngineSchedule = nil end
function ENT:DoingEngineSchedule() return self.bDoingEngineSchedule end

