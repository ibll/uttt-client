--[[pod_format="raw",created="2025-07-25 18:32:31",modified="2025-07-30 20:32:38",revision=394,xstickers={}]]
include "screens/Screen.lua"
include "libs/jui.lua"
include "libs/json.lua"

SettingsScreen = {}

setmetatable(SettingsScreen, Screen)
SettingsScreen.__index = SettingsScreen

--[[GROUP:ScreenManager]]

function SettingsScreen:new()
	local self = setmetatable({}, SettingsScreen)
	
	self.menu = create_gui()
	self.default_focus = nil
	self.buttons_init = false

	local cross_cols = self:genColButtons(120, 94-20, 240, 18, {
		id = "cross", 
		d = "selected_nought_col",
		l = "up_button",
	})
	for k, v in pairs(cross_cols) do self.menu:attach(v) end

	local nought_cols = self:genColButtons(120, 134-20, 240, 18, {
		id = "nought",
		u = "selected_cross_col",
		d = "random_col_toggle",
		l = "up_button",
	})
	for k, v in pairs(nought_cols) do self.menu:attach(v) end
	
	self.random_col_toggle = jui.toggle{
		x = 332, y = 164-20,
		width = 28, height = 16,
		active_col = 18, pit_col = 33,
		sides = {u = "selected_nought_col", d = "refocus_toggle", l = "up_button"},
		state = prefs.random_col,
		fire = function(s) prefs.random_col = s savePrefs() end
	}
	self.menu:attach(self.random_col_toggle)
	
	self.refocus_toggle = jui.toggle{
		x = 332, y = 204-20,
		width = 28, height = 16,
		active_col = 18, pit_col = 33,
		sides = {u = "random_col_toggle", l = "up_button"},
		state = prefs.auto_focus,
		fire = function(s) prefs.auto_focus = s savePrefs() end
	}
	self.menu:attach(self.refocus_toggle)
	
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
		disabled = true,
		base_col = 32, shadow_col = 32,
		accent_col = 34, text_col = 34,
		border_col = 32, active_col = 39,
		label = "\x94",
		sides = {l = "down_button"},
		fire = function() screen_manager:up() end
	}
	self.menu:attach(self.up_button)
	
	self.default_focus = self["cross_col_"..prefs.cross_col]

	return self
end

function SettingsScreen:draw(d, w, h, screenLerp)
	self.menu.y = -screenLerp * h
	self.menu:draw_all()
	
	print("Cross colour", 120, 80-20, 38)
	print("Nought colour", 120, 120-20, 38)
	print("Randomise colours (overrides above)", 120, 170-20, 38)
	line(110, 194-20, 370, 194-20, 38)
	print("Refocus previous game on app start", 120, 210-20, 38)
end

function SettingsScreen:update(focus_status)
	if not focus_status then return
	elseif focus_status == "gaining" and self.menu.controller_focus_el then
		self.menu.controller_focus_el = nil
	end
	
	self:updateController()
	self.menu:update_all()
end

function SettingsScreen:lostFocus()
	-- Delete Screen
	screen_manager:remove(screen_manager:getIndex(self))
end

--[[GROUP:Other]]

function SettingsScreen:updateController()
	if (not controller_active) return
	
	if not self.menu.controller_focus_el then
		self.menu.controller_focus_el = self.default_focus
		return
	end
	
	local s = self.menu.controller_focus_el.sides or {}
	
	if (left() and s.l) self.menu.controller_focus_el = self[s.l]
	if (right() and s.r) self.menu.controller_focus_el = self[s.r]
	
	if up() then

		if s.u == "selected_nought_col" then
			self.menu.controller_focus_el = self["nought_col_"..prefs.nought_col]
		elseif s.u == "selected_cross_col" then
			self.menu.controller_focus_el = self["cross_col_"..prefs.cross_col]
		elseif s.u then
			self.menu.controller_focus_el = self[s.u]
		else
			screen_manager:up()
		end
	end
	
	if down() then
		if s.d == "selected_nought_col" then
			self.menu.controller_focus_el = self["nought_col_"..prefs.nought_col]
		elseif s.d == "selected_cross_col" then
			self.menu.controller_focus_el = self["cross_col_"..prefs.cross_col]
		elseif s.d then
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

function SettingsScreen:genColButtons(x, y, w, h, el)
	el = el or {}
	
	local id = el.id or ""
	local output = {}
	local gap = el.gap or 3
	local num = 7
	local keyw = (w - (num - 2 - 1) * gap) / num
	local overflow = (keyw * num + gap * (num - 1)) - w
	x -= overflow // 2
	
	for ck = 1, num do
		local cv = colors[ck]
		local d = prefs[id .. "_col"] == ck

		local sides = {}
		if ck > 1    then sides.l = id.."_col_" .. ck-1 else sides.l = el.l end
		if ck < num then sides.r = id.."_col_" .. ck+1 else sides.r = el.r end
		sides.u = el.u
		sides.d = el.d
	
		self[id.."_col_" .. ck] = jui.button{
			id = id,
			x = (ck-1)*(keyw+gap) + x, y = y,
			width = keyw, height = h,
			label = string.upper(ck),
			base_col = cv[d and 3 or 1], accent_col = d and 32 or cv[3], active_col = 32,
			shadow_col = cv[3], controller_col = 7,
			sides = sides,
			fire = function()
			
				local prevck = prefs[id.."_col"]
				local prev = output[prevck]
				prev.disabled = false
				prev.base_col = colors[prevck][1]
				prev.accent_col = colors[prevck][3]
				
				local self = output[ck]
				self.disabled = true
				self.base_col = cv[3]
				self.accent_col = 32
				
				prefs[id.."_col"] = ck
				savePrefs()
				
			end,
			disabled = d,
		}
		
		table.insert(output, self[id.."_col_" .. ck])
	end
	
	return output
end