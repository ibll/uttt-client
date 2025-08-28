--[[pod_format="raw",created="2025-02-08 20:59:54",modified="2025-07-26 21:41:19",revision=913,xstickers={}]]
include "screens/Screen.lua"
include "libs/jui.lua"
include "screens/JoinScreen.lua"
include "screens/SettingsScreen.lua"

MenuScreen = {}

setmetatable(MenuScreen, Screen)
MenuScreen.__index = MenuScreen

function MenuScreen:new()
	local self = setmetatable({}, MenuScreen)
	
	self.menu = create_gui()
	self.default_focus = nil
	self.selecting_size = true
	self.buttons_init = false
	self.net_on = true

	-- TONS OF BUTTONS!!!

	-- default set
	self.start_button = jui.button{
		x = 160, y = 144,
		width = 160, height = 32,
		label = "New Room...",
		active_col = 25,
		depth = 4, gap = 4, lift = 1,
		sides = {d = "settings_button", l = "settings_button", r = "join_button"},
		fire = function() self:chooseSize() end,
	}
	self.settings_button = jui.button{
		x = 160, y = 180,
		width = 78, height = 32,
		label = "Settings",
		sides = {u = "start_button", l = "up_button", r = "join_button"},
		fire = function()
			local page = SettingsScreen:new()
			local loc = screen_manager:getIndex(self)
			screen_manager:focus(screen_manager:push(page, loc))
		end,
	}
	self.join_button = jui.button{
		x = 242, y = 180,
		width = 78, height = 32,
		label = "Join",
		active_col = 24,
		sides = {u = "start_button", l = "settings_button"},
		fire = function()
			local page = JoinScreen:new()
			local loc = screen_manager:getIndex(self)
			screen_manager:focus(screen_manager:push(page, loc))
		end, 
	}
	-- selecting size set
	self.cancel_start = jui.button{
		x = 160, y = 144,
		width = 160, height = 32,
		label = "Cancel...",
		active_col = 25,
		depth = 4, gap = 4, lift = 1,
		sides = {d = "start_2", l = "start_2", r = "start_inf"},
		fire = function() self:cancelChooseSize() end,
	}
	self.start_2 = jui.button{
		x = 160, y = 180,
		width = 51, height = 32,
		label = "Two",
		sides = {u = "cancel_start", l = "up_button", r = "start_3"},
		fire = function() server:start(2) end,
	}
	self.start_3 = jui.button{
		x = 215, y = 180,
		width = 50, height = 32,
		label = "Three",
		sides = {u = "cancel_start", l = "start_2", r = "start_inf"},
		fire = function() server:start(3) end,
	}
	self.start_inf = jui.button{
		x = 269, y = 180,
		width = 51, height = 32,
		label = "Endless",
		sides = {u = "cancel_start", l = "start_3"},
		fire = function() server:start(0) end,
	}
	
	self.down_button = jui.button{
		x = 8, y = 230, gap = 4,
		width = 43, height = 32,
		base_col = 33, shadow_col = 32,
		accent_col = 35, text_col = 38,
		border_col = 32, active_col = 39,
		label = "\x83",
		sides = {r = "up_button"},
		fire = function() screen_manager:down() end
	}
	self.menu:attach(self.down_button)
	
	self.up_button = jui.button{
		x = 54, y = 230, gap = 4,
		width = 43, height = 32,
		base_col = 33, shadow_col = 32,
		accent_col = 35, text_col = 38,
		border_col = 32, active_col = 39,
		label = "\x94",
		sides = {l = "down_button"},
		fire = function() screen_manager:up() end
	}
	self.menu:attach(self.up_button)

	-- Choose which set to show
	self:cancelChooseSize()

	return self
end

function MenuScreen:draw(d, w, h, screenLerp)
	sspr(
		1,
		0, 0, 96, 48,
		w/2 - 96, 16,
		192, 96
	)

	local netButtons = {
		self.start_button,
		self.join_button
	}

	if server:ready() then
		if not self.net_on then
			for _, v in pairs(netButtons) do
				v.lift = -1
				v.base_col = 6
				v.accent_col = 1
				v.disabled = false
			end
			self.net_on = true
		end
	else
		if self.net_on then
			for _, v in pairs(netButtons) do
				v.base_col = 21
				v.accent_col = 32
				v.disabled = true
			end
			
			if (self.selecting_size) self:cancelChooseSize()
			
			self.net_on = false
		end
	end	

	self.menu.y = -screenLerp * h
	self.menu:draw_all()
	print()
end

function MenuScreen:update(focus_status)
	if not focus_status then return
	elseif focus_status == "gaining" and self.menu.controller_focus_el then
		self.menu.controller_focus_el = nil
	end
	
	local ub = self.up_button
	if screen_manager:getIndex(self) <= 1 then
		if not ub.disabled then
			ub.disabled = true
			ub.base_col = 32
			ub.text_col = 35
			ub.accent_col = 34
		end
	else
		if ub.disabled then
			ub.disabled = false
			ub.base_col = 33
			ub.text_col = 38
			ub.accent_col = 35
		end
	end
	
	local db = self.down_button
	if screen_manager:getIndex(self) >= #screen_manager.screens then
		if not self.down_button.disabled then
			db.disabled = true
			db.base_col = 32
			db.text_col = 35
			db.accent_col = 34
		end
	else
		if self.down_button.disabled then
			db.disabled = false
			db.base_col = 33
			db.text_col = 38
			db.accent_col = 35
		end
	end
	
	self:updateController()
	self.menu:update_all()
end

function MenuScreen:gainedFocus()
	self:cancelChooseSize()
end

function MenuScreen:updateController()
	if (not controller_active) return
	
	if not self.menu.controller_focus_el then
		self.menu.controller_focus_el = self.default_focus
		return
	end
	
	local s = self.menu.controller_focus_el.sides or {}
	
	if (left() and s.l) self.menu.controller_focus_el = self[s.l]
	if (right() and s.r) self.menu.controller_focus_el = self[s.r]
	
	if up() then
		if s.u then
			self.menu.controller_focus_el = self[s.u]
		else
			screen_manager:up()
		end
	end
	
	if down() then
		if s.d then
			self.menu.controller_focus_el = self[s.d]
		else
			screen_manager:down()
		end
	end
	
	if btnp(13) or btnp(12) then
		if self.menu.controller_focus_el == self.default_focus then
			self.menu.controller_focus_el = self.down_button
		else
			self.menu.controller_focus_el = self.default_focus
		end
	end
		
	--if btn(4) then self.menu.controller_focus_el:click() end
end

function MenuScreen:chooseSize()
	if self.selecting_size then return end

	if self.buttons_init then
		self.start_button:detach()
		self.settings_button:detach()
		self.join_button:detach()
	end
	self.buttons_init = true
	
	self.menu:attach(self.cancel_start)
	self.menu:attach(self.start_2)
	self.menu:attach(self.start_3)
	self.menu:attach(self.start_inf)
	
	self.up_button.sides.u = "start_2"
	self.up_button.sides.r = "start_2"
	self.down_button.sides.u = "start_2"
	
	self.default_focus = self.cancel_start
	self.menu.controller_focus_el = nil
	self.selecting_size = true
end

function MenuScreen:cancelChooseSize()
	if not self.selecting_size then return end

	if self.buttons_init then
		self.cancel_start:detach()
		self.start_2:detach()
		self.start_3:detach()
		self.start_inf:detach()
	end
	self.buttons_init = true
		
	self.menu:attach(self.start_button)
	self.menu:attach(self.settings_button)
	self.menu:attach(self.join_button)
	
	self.up_button.sides.u = "settings_button"
	self.up_button.sides.r = "settings_button"
	self.down_button.sides.u = "settings_button"
		
	self.default_focus = self.start_button
	self.menu.controller_focus_el = nil
	self.selecting_size = false
end