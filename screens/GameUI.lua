--[[pod_format="raw",created="2025-07-26 22:18:42",modified="2025-07-27 20:14:44",revision=63,xstickers={}]]
include"libs/Toast.lua"

local function secondsToHMS(seconds)
	seconds = flr((seconds or 0) + 0.5)
	local hours = math.floor(seconds / 3600)
	seconds = seconds % 3600
	local minutes = math.floor(seconds / 60)
	seconds = seconds % 60
	return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

GameUI = {}
GameUI.__index = GameUI

function GameUI:new(name)
	local self = setmetatable({}, GameUI)
	
	self.menu = create_gui()
	self.toast = Toast:new()
	self.game = nil
	
	self.exit_button = jui.button{
		x = 8, y = 160, gap = 4,
		width = 89, height = 32,
		base_col = 33, shadow_col = 32,
		accent_col = 35, text_col = 38,
		border_col = 32, active_col = 39, 
		label = "Exit",
		sides = {  d = "code_button"},
		fire = function() self.game:remove() end
	}
	self.menu:attach(self.exit_button)
	
	self.code_button = jui.button{
		x = 8, y = 195, gap = 4,
		width = 89, height = 32,
		base_col = 33, shadow_col = 32,
		accent_col = 35, text_col = 38,
		border_col = 32, active_col = 39, 
		label = "Copy URL",
		sides = { u = "exit_button", d = "down_button"},
		fire = function()
			local str = "https://"..url.."/?room="..self.game.game_id
			set_clipboard(str)
			self.toast:display("Copied ".. str, 300)
		end
	}
	self.menu:attach(self.code_button)
	
	self.down_button = jui.button{
		x = 8, y = 230, gap = 4,
		width = 43, height = 32,
		base_col = 33, shadow_col = 32,
		accent_col = 35, text_col = 38,
		border_col = 32, active_col = 39,
		label = "\x83",
		sides = {u = "exit_button", r = "up_button"},
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
		sides = {u = "exit_button", l = "down_button"},
		fire = function() screen_manager:up() end
	}
	self.menu:attach(self.up_button)
	
	return self
end

function GameUI:draw(d, w, h, game, offset)
		for i = 1, 2 do
			local celcol = prefs.random_col and "rand"..tostring(i - 1) or i - 1
			for j = 1, #colors[i] do
				pal(colors[i][j], colors[game.col_map[celcol]][j])
			end
		end
		
		local info_w = 89
		
		rrectfill(8, 8, info_w, 25, 6, 33)
		rrect    (8, 8, info_w, 25, 6, 32)
		
		local has_piece = game.my_piece and game.my_piece != "null"
		local icons = { ["cross"] = 8, ["nought"] = 9, ["both"] = 10 }
		
		local player_i = has_piece and icons[game.my_piece] or 11
		local player_t = has_piece and "Playing as " or "Spectating "
		if (not has_piece and game.moves < 2) player_i = nil
		if (not has_piece and game.moves < 2) player_t = "Place to join!"
		
		local player_w = getPrintSize(player_t)
		local px, py = print(player_t, 10 + info_w/2 - player_w/2 - (player_i and 6 or 0), 17, 38)
		if (player_i) spr(player_i, px, 16)
		
		local x, y = 8, 37
		rrectfill(x, y, info_w, 84, 6, 33)
		rrect    (x, y, info_w, 84, 6, 32)
		for k, v in pairs({
			{"room", game.game_id},
			{"move", game.moves},
			{"time", secondsToHMS((game.end_time or stat(86)) - (game.start_time or stat(86)))},
		}) do
			game:drawInfoLine(x+info_w/2 + 1, 8+y+(k-1)*25, v[1], v[2])
		end
		
		self.menu.y = -offset
		self.menu:draw_all()
		self.toast:draw(d, w, h)
		
		pal()
end

function GameUI:update(game)
	self.game = game

	local db = self.down_button
	if screen_manager:getIndex(game) >= #screen_manager.screens then
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
	self.toast:update()
end

function GameUI:display(msg, icon, retrigger)
	self.toast:display(msg, math.huge, icon, retrigger or false)
end

function GameUI:updateController()
	if (self.game.controller_cell) self.menu.controller_focus_el = nil return
	if not self.menu.controller_focus_el then
		self.menu.controller_focus_el = self.code_button
		return
	end
	
	local s = self.menu.controller_focus_el.sides or {}

	if (left() and s.l) self.menu.controller_focus_el = self[s.l]

	if right() then
		if s.r then
			self.menu.controller_focus_el = self[s.r]
		else
			self.game:focusDefault()
		end
	end

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
	
	if (btnp(13) or btnp(5) or btnp(12)) self.game:focusDefault() return
end