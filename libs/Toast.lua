--[[pod_format="raw",created="2025-07-20 17:07:15",modified="2025-07-27 02:57:05",revision=327,xstickers={}]]
Toast = {}
Toast.__index = Toast

function Toast:new()
	local self = setmetatable({}, Toast)
	
	self.DEFAULT_DURATION = math.huge
	self.DEFAULT_FADE_TIME = 30
	self.DEFAULT_FADE_STAGES = 10
	self.QUICK_SPEED = 180
	self.TOO_FEW_STAGES_TO_ANIMATE = 4
	self.BORDER = 1
	self.PADDING = 6
	self.MARGIN = 8
	
	self.message = nil
	self.text = nil
	self.icon = nil
	self.perma_mesage = nil
	self.perma_icon = nil
	self.message_time = tick - self.QUICK_SPEED
	self.before_update_message_time = self.message_time
	self.expire_time = nil
	self.fade_time = self.DEFAULT_FADE_TIME
	self.stages = {}
	
	return self
end

function Toast:draw(d, w, h)
	if (not self.text) return

	tw, th = getPrintSize(self.text)
	tw -= 1
	local icon_w = self.icon and 9 + self.PADDING - 2 or 0
	local x = w - tw - self.MARGIN - 2*self.PADDING - 2*self.BORDER - icon_w
	local y = h - th - self.MARGIN - 2*self.PADDING - 2*self.BORDER
	local w = tw + 2*self.PADDING + 2*self.BORDER + icon_w
	local h = th + 2*self.PADDING + 2*self.BORDER
	rrectfill(x, y, w, h, 6, 33)
	rrect(x, y, w, h, 6, 32)
	spr(self.icon, x + self.PADDING + 1, y + self.PADDING + 2)
	print(self.text, x + self.PADDING + self.BORDER + (self.icon and 2 or 1) + icon_w, y + self.PADDING + self.BORDER + 2, 38)
end

function Toast:update()
	local since_display = tick - self.message_time
	local diff = self.fade_time // #self.stages
	if since_display >= self.fade_time and self.message != self.text then
		self.text = self.message
	elseif since_display < self.fade_time then
		self.text = self.stages[min((since_display)//diff + 1, #self.stages)]
	end
	
	if (self.expire_time and tick > self.expire_time) self:display(self.perma_message, math.huge, self.perma_icon)
	if (self.before_update_message_time != self.message_time) self.before_update_message_time = self.message_time
end

--[[GROUP:Other]]

function Toast:display(message, duration, icon, force_retrigger)
	if (message == "") message = nil
	duration = duration or self.DEFAULT_DURATION
	
	if (self.message == message and not force_retrigger) self.expire_time = tick + duration return
	self.message = message
	
	self.icon = icon
	self.stages = {}
	self.fade_time = self.DEFAULT_FADE_TIME
	local fade_stages = self.DEFAULT_FADE_STAGES
	
	if message then
		-- Glitch In
		
		-- Don't want to do the full animation every single time.
		-- When it's spammed, we want to make it more quick and
		-- graceful, or not animate at all.
		
		-- Also, if we one message overrides another in the same
		-- update tick, don't count that as a retrigger. It didn't
		-- even affect the animation!
		local diff = tick - self.before_update_message_time
		
		if diff < self.QUICK_SPEED then
			self.fade_time = max(ceil((diff/self.QUICK_SPEED) * self.DEFAULT_FADE_TIME), 1)
			fade_stages = max(ceil((diff/self.QUICK_SPEED) * self.DEFAULT_FADE_STAGES), 1)
		end
		
		if fade_stages < self.TOO_FEW_STAGES_TO_ANIMATE and not force_retrigger then
			self.fade_time = 0
			fade_stages = 1
		end
	
		local remaining_message = message
		for i = fade_stages, 1, -1 do
			self.stages[i] = remaining_message
			remaining_message = clipMessage(remaining_message, self.DEFAULT_FADE_STAGES)
		end
		
	elseif self.text then
		-- Glitch Out
		-- This one's okay because you can't really spam removal.
		self.fade_time /= 2
		fade_stages /= 2
		
		local remaining_message = self.text
		
		for i = 1, fade_stages do
			self.stages[i] = remaining_message
			remaining_message = clipMessage(remaining_message, fade_stages)
		end

	end
	
	self.message_time = tick
	if duration and duration != math.huge and message then
		self.expire_time = tick + duration
	elseif duration == math.huge then
		self.perma_message = message
		self.perma_icon = icon
	end
end

function clipMessage(remaining_message, num_stages)
	local random_idx = flr(rnd(#remaining_message - 1)) + 2;
	local to_remove = max(1, (#remaining_message) // max(num_stages - 1, 1))

	local min_slice = max(1, random_idx - to_remove)
	local max_slice = min(#remaining_message, random_idx + to_remove)

	return string.sub(remaining_message, 1, min_slice) .. string.sub(remaining_message, max_slice)
end
