--[[pod_format="raw",created="2025-07-08 15:09:00",modified="2025-07-26 11:58:31",revision=768,xstickers={}]]
include "libs/lerp.lua"

-- Juicy User Interface

jui = {}

--[[GROUP:Button]]
function jui.button(el)
	local height = el.height or 14
	local depth = el.depth or 2
	depth = abs(depth)
	height = height + depth
	local y = el.y or 0
	y = y - depth

	local button_setup = {
		x = el.x or 0,
		y = y,
		width = el.width or #el.label * 5 + 10, -- to do: calculate width with current font
		height = height,
		depth = depth,
		label = el.label or "[label]",
		cursor = "pointer",
		
		base_col = el.base_col or 6,
		shadow_col = el.shadow_col or 13,
		accent_col = el.accent_col or 1,
		text_col = el.text_col,
		active_col = el.active_col or 18,
		border_col = el.border_col,
		controller_col = el.controller_col or 16,
		indent_col = el.indent_col or 32,
		
		fire = el.fire or function() end,
		gap = el.gap or 2,
		disabled = el.disabled or false,
		sides = el.sides or nil,
		spam = el.spam or nil,
		start_down = nil,
		
		readyaim = false,
		readyagain = false,
		lift = el.lift or 0,
			
		draw = function(self)
			local hl = self.head.controller_focus_el == self and controller_active
	
			local w = self.width
			local h = self.height
			local c = self.depth
			local tw, th = getPrintSize(self.label)
			local offset = ceil(0 - (c * self.lift)) 
			-- Dynamic Depth
			local body_col = self.base_col
			local backdrop_col = self.shadow_col
			local accent_col = self.accent_col
			local text_col = self.text_col or self.accent_col
			local extra_crop = 0
			if hl then
				accent_col = self.controller_col
				text_col = self.controller_col
				end
			if offset > 0 then
				body_col = self.shadow_col
				backdrop_col = self.indent_col
				accent_col = self.active_col
				text_col = self.active_col
				extra_crop = offset
			end

			local b = (self.border_col and offset <= -c) and 1 or 0
			
			-- Button Edge / Shadow
			rrectfill(0, c,
						w, h - c,
						6, backdrop_col)
			-- Button Body
			rrectfill(0 + b, c + offset,
					   w - 2*b, h - c - extra_crop,
					   6, body_col)
			-- Depress Highlight
			if offset > 0 then
				rrectfill(extra_crop, c + 2*extra_crop,
							w - 2*extra_crop, h - c - 2*extra_crop,
							6, self.base_col)
			end
			-- Accent
			rrect(self.gap, self.gap + c + offset,
				   w - 2*self.gap, h - 2*self.gap - c,
				   6 - self.gap, accent_col)
			-- Text
			print(self.label,
				   w/2 - tw/2 + 1,
				   2 + c + (h-c)/2 - th/2 + offset,
				   text_col or accent_col)
			-- Border
			if self.border_col then
				local extra_gap = offset < 0 and 1 or 0
				clip(self.sx, self.sy + c + (offset >= 0 and 0 or 4) + extra_gap, w, h + offset + extra_gap)
				rrect(0, c, w, h - c, 6, self.border_col)
			end
		end,
		update = function(self, msg)
			if self.disabled then self.lift = 0 return end
	
			local hl = self.head.controller_focus_el == self and controller_active
			
			-- If selected by controller, o clicks down.
			if hl then
				self:highlight()
				if btn(4) then
					self:click()
				end
			end
			
			-- Cancel click when left button
			if (not msg.has_pointer) and (not hl) then
				self.readyaim = false
				-- fix button sticking when clicking then dragging out
				if self.lift < 0 then self.lift = self.lift + 0.2 end
			end
	
			-- Detect and fire on quick click, to avoid fast clicking just delaying a single fire
			if not self.readyagain and self.readyaim and not (self.lift <= -1) then
				self.readyagain = true
			elseif not self.readyaim then
				self.readyagain = false
			end
			
			if self.lift <= 1 and self.readyagain and self.readyaim then
				self.readyagain = false
				self.readyaim = false
				self.fire()
			end

			-- Allow button to pop up before trigger otherwise
			if self.lift >= 1 and self.readyaim then
				self.readyaim = false
				self.fire()
			end
			
			-- Reset held down timeout
			if self.lift > -1 then
				self.start_down = nil
			elseif self.start_down and tick > self.start_down + 30 then
				self.readyaim = false
			end
			
			-- slowly lift button unless clicked
			-- these values are kinda finicky and not easy to modify
			-- they're also dependent on the values below cause i'm dumb
			if self.lift >= 0.3 then
				self.lift = self.lift - 0.2
			elseif self.lift >= 0 then
				self.lift = 0
			end
			
		end,
		hover = function(self)
			if not controller_active then self:highlight() end
		end,
		highlight = function(self)
			if self.disabled then return end
	
			-- these values are kinda finicky and not easy to modify
			if self.lift <= 0.6 then
				self.lift = self.lift + 0.4
			else
				self.lift = 1.2
			end
		end,
		click = function(self)
			if self.disabled then return end
			if not self.start_down then self.start_down = tick end
			
			self.readyaim = true
			self.lift = -1
		end,
		release = function(self)
			if self.disabled then return end
			self.lift = -0.6
		end
	}
	
	return button_setup
end

--[[GROUP:Toggle]]

function jui.toggle(el)
	local height = el.height or 14
	local depth = el.depth or 2
	depth = abs(depth)
	height = height + depth
	local y = el.y or 0
	y = y - depth

	local toggle_setup = {
		x = el.x or 0,
		y = y,
		width = el.width or #el.label * 5 + 10, -- to do: calculate width with current font
		height = height,
		slider_width = el.slider_width or el.height,
		depth = depth,
		label = el.label or "",
		cursor = "pointer",
		
		base_col = el.base_col or 6,
		shadow_col = el.shadow_col or 13,
		accent_col = el.accent_col or 1,
		text_col = el.text_col,
		active_col = el.active_col or 18,
		controller_col = el.controller_col or 16,
		indent_col = el.indent_col or 32,
		pit_col = el.pit_col or 32,
		
		toggle_dur = el.toggle_dur or 20,
		target_tick = tick,
		
		state = el.state,
		pos = el.state and 1 or 0,
		fire = el.fire or function() end,
		gap = el.gap or 2,
		disabled = el.disabled or false,
		sides = el.sides or nil,
		spam = el.spam or nil,
		start_down = nil,
		
		readyaim = false,
		readyagain = false,
		lift = el.lift or 0,
			

		draw = function(self)
			local hl = self.head.controller_focus_el == self and controller_active
	
			local w = self.width
			local h = self.height
			local sw = self.slider_width
			local c = self.depth
			local tw, th = getPrintSize(self.label)
			local offset = min(0, ceil(0 - (c * self.lift)))
			-- Dynamic Depth
			local body_col = self.base_col
			local backdrop_col = self.shadow_col
			local accent_col = self.accent_col
			local text_col = self.text_col or self.accent_col
			local extra_crop = 0
			if hl then
				accent_col = self.controller_col
				text_col = self.controller_col
				end
			if offset > 0 then
				body_col = self.shadow_col
				backdrop_col = self.indent_col
				accent_col = self.active_col
				text_col = self.active_col
				extra_crop = offset
			end
			
			local target_pos = self.state and 1 or 0
			local perc =  1 - max(0, self.target_tick - tick)/self.toggle_dur
			self.pos = lerp(self.pos, target_pos, perc)
			
			local b = 1
			local slide_x = self.pos * (w - sw) + b + 0.5
			
			-- Depth
			rrectfill(0, c,
						 w, h - c,
						 6, self.indent_col)
			-- Track
			rrectfill(0, 2*c + b,
						 w, h - 2*c - b,
						 6, self.pit_col)
			-- Button Edge / Shadow
			if offset <= 0 then
				rrectfill(slide_x, c + b,
							sw - 2*b, h - c - extra_crop - 2*b,
							6, backdrop_col)
			end
			-- Button Body
			rrectfill(slide_x, c + offset + b,
					   sw - 2*b, h - c - extra_crop - 2*b,
					   6, body_col)
			-- Depress Highlight
			if offset > 0 then
				rrectfill(extra_crop + slide_x, c + 2*extra_crop + b,
							sw - 2*extra_crop - 2*b, h - c - 2*extra_crop - 2*b,
							6, self.base_col)
			end
			-- Accent
			rrect(self.gap + slide_x, self.gap + c + offset + b,
				   sw - 2*self.gap - 2*b, h - 2*self.gap - c - 2*b,
				   6 - self.gap,
					(offset < 0) and (self.state and 27 or 8) or (text_col or accent_col))
			-- Text
			print(self.label,
				   slide_x + sw/2 - tw/2 + 1,
				   2 + c + (h-c)/2 - th/2 + offset,
					(offset < 0) and (self.state and 27 or 8) or (text_col or accent_col))
			-- Border
			local extra_gap = offset < 0 and 1 or 0
			clip(self.sx, self.sy + c + (offset >= 0 and 0 or 6) + extra_gap, w, h + offset + extra_gap)
			rrect(0, c, w, h - c, 6, self.indent_col)
		end,
		update = function(self, msg)
			if self.disabled then self.lift = 0 return end
	
			local hl = self.head.controller_focus_el == self and controller_active
			
			-- If selected by controller, o clicks down.
			if hl then
				self:highlight()
				if btn(4) then
					self:click()
				end
			end
			
			-- Cancel click when left button
			if (not msg.has_pointer) and (not hl) then
				self.readyaim = false
				-- fix button sticking when clicking then dragging out
				if self.lift < 0 then self.lift = self.lift + 0.2 end
			end
	
			-- Detect and fire on quick click, to avoid fast clicking just delaying a single fire
			if not self.readyagain and self.readyaim and not (self.lift <= -1) then
				self.readyagain = true
			elseif not self.readyaim then
				self.readyagain = false
			end
			
			local moved = false
			local mx, _, mb = mouse()
			local lmb = mb & (1 << 0) ~= 0
			
			if (not lmb) self.mx = nil
			
			if self.state then
				moved = self.mx and mx < self.mx - 5
			else
				moved = self.mx and mx > self.mx + 5
			end
			
			if not controller_active and moved then
				-- prevent firing again when lifted up
				if (self.start_down) self.start_down -= 30
				-- set retrigger pos to halfway
				self.mx = self.x + self.width / 2
				-- make snap faster based on speed
				self.target_tick = tick + self.toggle_dur - abs(self.mx - mx) / 2
				
				self.state = not self.state
				self.fire(self.state)
			end
			
			if self.lift <= 1 and self.readyagain and self.readyaim then
				self.readyagain = false
				self.readyaim = false
				self.state = not self.state
				self.target_tick = tick + self.toggle_dur
				self.fire(self.state)
			end

			-- Allow button to pop up before trigger otherwise
			if self.lift >= 1 and self.readyaim then
				self.readyaim = false
				self.state = not self.state
				self.target_tick = tick + self.toggle_dur
				self.fire(self.state)
			end
			
			-- Reset held down timeout
			if self.lift > 0 then
				self.start_down = nil
			elseif self.start_down and tick > self.start_down + 30 then
				self.readyaim = false
			end
			
			-- slowly lift button unless clicked
			-- these values are kinda finicky and not easy to modify
			-- they're also dependent on the values below cause i'm dumb
			if self.lift >= 0.3 then
				self.lift = self.lift - 0.2
			elseif self.lift > 0 then
				self.lift = 0
			end
			
		end,
		hover = function(self)
			if not controller_active then self:highlight() end
		end,
		highlight = function(self)
			if self.disabled then return end
	
			-- these values are kinda finicky and not easy to modify
			if self.lift <= 0.6 then
				self.lift = self.lift + 0.4
			else
				self.lift = 1.2
			end
		end,
		click = function(self)
			if self.disabled then return end
			if not self.start_down then
				self.start_down = tick
				self.mx = mouse()
			end
			
			self.readyaim = true
			self.lift = -1
		end
	}
	
	return toggle_setup
end