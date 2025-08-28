--[[pod_format="raw",created="2025-07-09 20:07:44",modified="2025-07-27 20:08:12",revision=514,xstickers={}]]
include"libs/lerp.lua"
include"screens/MenuScreen.lua"

ScreenManager = {}
ScreenManager.__index = ScreenManager

function ScreenManager:new()
	local self = setmetatable({}, ScreenManager)

	-- How long it takes to switch screens
	self.SCREEN_ANIM = 240
	-- How far into the animation can you retrigger mouse scroll
	self.SCREEN_SCROLL_CLICK = 0.8
	
	self.screens = {}
	self.screen = 1
	self.screen_lerp = self.screen
	self.screen_lerp_perc = 1
	self.screen_dur = 0
	self.screen_scroll_dir = 0
	self.last_focused_screen = 1
	
	self.wrap = false
	
	return self
end

function ScreenManager:draw(d, w, h)
	camera()

	for k, v in ipairs(self.screens) do
		local screen_pos = self.screen_lerp - k
		if screen_pos > -1 and screen_pos < 1 then
			camera(0, (self.screen_lerp - k) * h)
			v:draw(d, w, h, self.screen_lerp - k)
		end
	end
	
	local menu_idx = self:getScreenBy(function(s) return getmetatable(s) == MenuScreen end)
	if self.screen_lerp > menu_idx then
		local game = self:getScreen(flr(self.screen_lerp))
		if (not game.game_id) game = self:getScreen(menu_idx + 1)
		
		local offset = 0
		if (self.screen_lerp - menu_idx < 1) offset = (self.screen_lerp - menu_idx - 1) * h
		camera(0, offset)
		
		game_ui:draw(d, w, h, game, offset)
	end
	
	camera()
	
	if (self.screen_dur > 0) self:drawScrollIndicator(w, h)
end

function ScreenManager:update()
	local _,_,_,_,wheel_y = mouse()

	local default_nav = self.screens[self.screen].default_nav == true
	local scroll_ready = self.screen_lerp_perc >= self.SCREEN_SCROLL_CLICK

	if btnp(14) or (not_custom_nav and up()) or (wheel_y >= 1 and (scroll_ready or self.screen_scroll_dir == 1)) then
		self:up()
	end
	
	if btnp(15) or (not_custom_nav and down()) or (wheel_y <= -1 and (scroll_ready or self.screen_scroll_dir == -1)) then
		self:down()
	end
	
	if (self.screen_dur > 0) self.screen_dur -= 1
	
	self.screen_lerp     = lerp(self.screen_lerp    , self.screen, 1 - self.screen_dur/self.SCREEN_ANIM)
	self.screen_lerp_perc = lerp(self.screen_lerp_perc, 1          , 1 - self.screen_dur/self.SCREEN_ANIM)

	if self.screen_lerp_perc > 0.9975 then
		self.screen_lerp_perc = 1
		self.screen_lerp = self.screen
--		self.screen_dur = 0
	end
	
	if self.screen_lerp >= self.last_focused_screen + 1 or
	   self.screen_lerp <= self.last_focused_screen - 1 then
		self.screens[self.last_focused_screen]:lostFocus()
		self.last_focused_screen = self.screen
	end

	for k, v in ipairs(self.screens) do
		local screen_pos = self.screen_lerp - k
		if screen_pos > -1 and screen_pos < 1 then
			local focus_status = false
			if k == self.screen_lerp then focus_status = "full"
			elseif k == self.screen then focus_status = "gaining"
			end
			v:update(focus_status, screen_pos)
		end
	end
	
	local menu_idx = self:getScreenBy(function(s) return getmetatable(s) == MenuScreen end)
	if self.screen_lerp > menu_idx then
		local game = self:getScreen()
		if (not game.game_id) game = self:getScreen(menu_idx + 1)
		game_ui:update(game)
	end
end

--[[GROUP:Management]]

function ScreenManager:up()
	local new_screen_index = self.screen
	if self.screen <= 1 then
		if (self.wrap) new_screen_index = #self.screens
	else
		new_screen_index = self.screen - 1
	end
	
	self.screen_scroll_dir = -1
	
	self:focus(new_screen_index)
end

function ScreenManager:down()
	local new_screen_index = self.screen
	if self.screen >= #self.screens then
		if (self.wrap) new_screen_index = 1
	else
		new_screen_index = self.screen + 1
	end
	
	self.screen_scroll_dir = 1
	self:focus(new_screen_index)
end

function ScreenManager:push(screen, index)
	local i = index or #self.screens + 1
	table.insert(self.screens, i, screen)
	if index and index <= self.screen then
		self.screen += 1
		self.screen_lerp += 1
	end
	return i
end

function ScreenManager:remove(index)
	table.remove(self.screens, index)
	
	if index <= self.screen then
		if (self.screen > 1) self.screen -= 1
		self.screen_lerp -= 1
	end
	
	if index <= self.last_focused_screen then
		self.last_focused_screen -= 1
	end
end

function ScreenManager:focus(new_screen_index)
	-- Don't refocus an already focused or disabled screen!
	if (self.screen == new_screen_index or self.screens[new_screen_index].disabled) return

	self.screen = new_screen_index
	self.screen_lerp_perc = 0
	self.screen_dur = self.SCREEN_ANIM
	
	local s = self:getScreen()
	if s.game_id then
		prefs.last_focused = s.game_id
	else
		prefs.last_focused = nil
	end
	savePrefs()
	
	s:gainedFocus()
end

function ScreenManager:getScreen(idx)
	return self.screens[idx or self.screen]
end

function ScreenManager:getIndex(screen)
	return self:getScreenBy(function(s) return s == screen end)
end

function ScreenManager:getScreenBy(func)
	for k, v in pairs(self.screens) do
		if (func(v)) return k, v
	end
	return
end

--[[GROUP:Visual]]

function ScreenManager:drawScrollIndicator(w, h)
	local bar_w = 7
	local bar_h = 27
	local bar_p = 8
	local dot_space = 5
	local cols = {[0] = 39, 49, 21}
	
	clip(w-bar_p-bar_w, bar_p, bar_w, bar_h)
	rrectfill(w-bar_p-bar_w, bar_p, bar_w, bar_h, 1, 33)
	
	for scr_idx, scr in pairs(self.screens) do
		local offset = abs(scr_idx - self.screen)
		if offset <= #cols then
			local col = cols[offset]
			circfill(w-bar_p-ceil(bar_w/2), bar_p + bar_h//2 + (scr_idx)*dot_space - self.screen_lerp*dot_space, 0, col)
		end
	end 
	
	rrect    (w-bar_p-bar_w, bar_p, bar_w, bar_h, 1, 32)
	clip()
end