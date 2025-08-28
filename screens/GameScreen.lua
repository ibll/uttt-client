--[[pod_format="raw",created="2025-07-10 00:20:37",modified="2025-08-03 21:57:07",revision=1999,xstickers={}]]
include"screens/Screen.lua"
include"libs/json.lua"

local function getCoordsFromIndex(lay, idx)
	if (lay == 0) return idx // 3, idx % 3
	
	local parent_idx = idx // 9
	local local_idx = idx % 9
	local local_row = local_idx // 3
	local local_col = local_idx % 3
	
	local parent_row, parent_col = getCoordsFromIndex(lay - 1, parent_idx)
	
	local final_row = 3*parent_row + local_row
	local final_col = 3*parent_col + local_col
	
	return final_row, final_col
end

local function getIndexFromCoords(lay, row, col)
	if (lay == 0) return 3*row + col
	
	local parent_row = row // 3
	local parent_col = col // 3
	local local_row = row % 3
	local local_col = col % 3
	local local_idx = 3*local_row + local_col
	
	local parent_idx = getIndexFromCoords(lay-1, parent_row, parent_col)
	
	return 9*parent_idx + local_idx
end

--local function secondsToHMS(seconds)
--	seconds = flr((seconds or 0) + 0.5)
--	local hours = math.floor(seconds / 3600)
--	seconds = seconds % 3600
--	local minutes = math.floor(seconds / 60)
--	seconds = seconds % 60
--	return string.format("%02d:%02d:%02d", hours, minutes, seconds)
--end

GameScreen = {}

setmetatable(GameScreen, Screen)
GameScreen.__index = GameScreen

function GameScreen:new(state)
	local self = setmetatable({}, GameScreen)
		
	assert(state != nil)
	
	self.cells = {}
	self.active_grids = {}
	self.selected = nil -- {layer, num}
	self.default_controller_cell = nil -- {layer, num}
	self.controller_cell = nil -- {layer, num}
	self.ready_to_flip = false
	
	self.game_id = nil
	self.board_depth = 0
	self.board_state = {}
	self.moves = 0
	self.start_time = nil
	self.end_time = nil
	self.my_piece = nil
	self.lmb = false
	
	self.toast_msg = nil
	self.toast_icon = nil
	
	self.col_map = {
		rand0 = flr(rnd(7)) + 1,
		rand1 = flr(rnd(6)) + 1,
		[0] = prefs.cross_col,
		[1] = prefs.nought_col,
		active = 8,
		hl = 9,
		null = 10,
	}
	-- prevent duplicate colour
	if (self.col_map.rand1 >= self.col_map.rand0) self.col_map.rand1 += 1

	self:updateState(state)
	
	return self
end

function GameScreen:draw(d, w, h, screenLerp)
	-- Handle animated dithering
	local dither = {
		0b01110111,
		0b11111111,
		0b11011101,
		0b11111111,
		0b01110111,
		0b11111111,
		0b11011101,
		0b11111111
	}
	local len = #dither
	local times = sin(tick/1000)*10 % len
	for i = 1, times do
		local last = dither[len]
		-- shift everything down
		for j = len, 2, -1 do
			dither[j] = dither[j-1]
		end
		dither[1] = last
	end
	
	-- Active Highlight
	for k, v in pairs(self.active_grids) do
		local x, y, s = table.unpack(self.cells[1][v])
		local col_flash = ((tick//30)-k) % (#self.active_grids + 1) != 0
		rectfill(x, y, x+s, y+s, colors[self.col_map["active"]][col_flash and 3 or 2])
		fillp()
	end
	
	-- Second-To-Top Level Pieces Backing
	local second_top_lvl = self.board_depth - 1
	if self.board_state[second_top_lvl] and self.board_depth > 1 then
		for celn, cel in pairs(self.board_state[self.board_depth - 1]) do
			layn = self.board_depth - 1
			celn = celn
			
			local i = self.cells[layn][celn+1]
			local x, y, size = unpack(i)
			local celcol = (prefs.random_col and type(cel) == "number") and "rand"..tostring(cel) or cel
			local col = colors[self.col_map[celcol]][3]
		
			rrectfill(x, y, size+1, size+1, 2, col)
		end
	end
	
	-- Hover Highlight
	if self.selected then
		if (not controller_active) window{cursor=self.board_depth > 3 and 0 or 1}
		local l, c = self.selected.layer, self.selected.num
		local x, y, s = unpack(self.cells[l][c])
		local played = self.board_state[l] and self.board_state[l][c - 1] != nil
		local col = colors[self.col_map["hl"]][3]
		if played and l == self.board_depth - 1 and self.board_depth > 1 then
			rrectfill(x, y, s+1, s+1, 2, col)
		else
			rectfill(x, y, x+s, y+s, col)
		end
	else
		if (not controller_active) window{cursor=1}
	end
	
	-- Pieces
	for layn, lay in pairs(self.board_state) do
		for celn, cel in pairs(lay) do
			if (tonumber(layn) >= self.board_depth) goto skipdrawpiece
			layn = tonumber(layn)
			celn = tonumber(celn)
			
			local p = 1
			local i = self.cells[layn][celn+1]
			local x, y, size = unpack(i)
			local is_border = layn >= self.board_depth - 1 and self.board_depth > 1
			
			local cs = self.selected
			local hl = cs and cs.layer == layn and cs.num - 1 == celn 
	
			local celcol = (prefs.random_col and type(cel) == "number") and "rand"..tostring(cel) or cel
			local cols = colors[self.col_map[hl and "hl" or celcol]]
			
			if cel == 1 and not is_border then
				circ(x + size/2, y + size/2, size/2 - p, cols[1])
			elseif cel == 0 and not is_border then
				line(x+p, y+p, x+size-p, y+size-p, cols[1]) --nw se
				line(x+p, y+size-p, x+size-p, y+p, cols[1]) --sw ne
			elseif cel == "null" and not is_border then
				line(x+p, y+size/2, x+size-p, y+size/2, cols[1])
			elseif is_border then
				fillp(unpack(dither))
				fillp(unpack(dither))

				rrectfill(x, y, size, size, 2, cols[2])
				fillp()
				rrect(x, y, size+1, size+1, 2, cols[1])
			end
			::skipdrawpiece::
		end
	end
	
	-- Grid Lines
	for layn = 1, self.board_depth do
		for celn, cel in pairs(self.cells[layn]) do
			local state_lay = self.board_state[layn]
			local state_cel = nil
			if (state_lay) state_cel = state_lay[celn-1]
			if not state_cel or layn >= self.board_depth - 1 then
				local i = self.cells[layn][celn+1]
				local x, y, size = unpack(cel)
				
				local col_map = {38, 37, 36, 35}
				local col = col_map[self.board_depth - layn + 1]
				
				line(x,          y+size/3,      x+size,     y+size/3,   col)
				line(x,          y+size*2/3,    x+size,     y+size*2/3, col)
				line(x+size/3,   y,             x+size/3,   y+size,     col)
				line(x+size*2/3, y,             x+size*2/3, y+size,     col)
			end
		end
	end
	
	-- UI
	
--	for i = 1, 2 do
--		local celcol = prefs.random_col and "rand"..tostring(i - 1) or i - 1
--		for j = 1, #colors[i] do
--			pal(colors[i][j], colors[self.col_map[celcol]][j])
--		end
--	end
--	
--	local info_w = 89
--	
--	rrectfill(8, 8, info_w, 25, 6, 33)
--	rrect    (8, 8, info_w, 25, 6, 32)
--	
--	local has_piece = self.my_piece and self.my_piece != "null"
--	local icons = { ["cross"] = 8, ["nought"] = 9, ["both"] = 10 }
--	
--	local player_i = has_piece and icons[self.my_piece] or 11
--	local player_t = has_piece and "Playing as " or "Spectating "
--	if (not has_piece and self.moves < 2) player_i = nil
--	if (not has_piece and self.moves < 2) player_t = "Place to join!"
--	
--	local player_w = getPrintSize(player_t)
--	local px, py = print(player_t, 10 + info_w/2 - player_w/2 - (player_i and 6 or 0), 17, 38)
--	if (player_i) spr(player_i, px, 16)
--	
--	local x, y = 8, 37
--	rrectfill(x, y, info_w, 84, 6, 33)
--	rrect    (x, y, info_w, 84, 6, 32)
--	for k, v in pairs({
--		{"room", self.game_id},
--		{"move", self.moves},
--		{"time", secondsToHMS((self.end_time or stat(86)) - (self.start_time or stat(86)))},
--	}) do
--		self:drawInfoLine(x+info_w/2 + 1, 8+y+(k-1)*25, v[1], v[2])
--	end
--	
--	self:draw(d, w, h)
--	
--	self.menu.y = -screenLerp * h
--	self.menu:draw_all()
--	
--	pal()
end

function GameScreen:update(focus_status, screen_pos)
	if (not focus_status) return
--	if (focus_status == "gaining" and not self.controller_cell) self:focusDefault()

	local mx, my, mb = mouse()
	local lmb = mb & (1 << 0) != 0
	local click = false
	if (lmb and not self.lmb) click = true
	self.lmb = lmb
	
	if controller_active then
		self:updateController()
		
		if self.ready_to_flip and not (btn(4)) then
			self.default_controller_cell = nil
			self.controller_focus_el = nil
		end
	else
		self:findMouseSelected(mx, my, screen_pos)
	end
	
	if (prefs.nought_col != self.col_map[1]) self.col_map[1] = prefs.nought_col
	if (prefs.cross_col != self.col_map[0]) self.col_map[0] = prefs.cross_col
	
	if (click and self.selected and self.selected.layer == 0) server:place(self.game_id, self.selected.num - 1)
end

function GameScreen:gainedFocus()
	game_ui:display(self.toast_msg, self.toast_icon, true)
	self:focusDefault()
end

function GameScreen:lostFocus()
	if (not self.disabled) return
	-- Delete Screen
	local index = screen_manager:getScreenBy(
		function(v) return v == self end
	)
	screen_manager:remove(index)
end


function GameScreen:remove()
	self.disabled = true
	
	local screen_idx = screen_manager:getIndex(self)
	local last = screen_idx == #screen_manager.screens
	local moving_up = screen_manager.screen_scroll_dir < 0
	
	if last or moving_up then
		screen_manager:up()
	else
		screen_manager:down()
	end
	
	del(prefs.games, self.game_id)
	savePrefs()
end

--[[GROUP:Server Updates]]

function GameScreen:updateState(payload)
	assert(self.game_id == nil or self.game_id == payload.game_id)
	self.game_id = payload.game_id
	
	self.board_state = {}
	self.moves = payload.moves
		
	if (payload.start_time) self.start_time = payload.start_time // 1000
	if (payload.end_time  ) self.end_time   = payload.end_time   // 1000
	self.board_depth = payload.board_depth
	self.my_piece = payload.client_piece
	
	self.controller_cell = nil
	self.cells = {}
	
	local size = 270
	local w, h = 480, 270
	local woff, hoff = (w - size) / 2, (h - size) / 2
	self:addGridLayer(self.board_depth, woff, hoff, size)
	
	for i = 0, self.board_depth do
		if payload.board_state[tostring(i)] then
			for celn, cel in pairs(payload.board_state[tostring(i)]) do
				self:place(i, tonumber(celn), cel)
			end
		end
	end
	
	self:setActiveGrids(payload.active_layer, payload.active_grid_num, payload.next_player_id)
end

function GameScreen:place(layer, cell_num, player)
	if (not self.start_time) self.start_time = stat(86)
	
	if (layer < self.board_depth - 1) self:clearBelowCell(layer, cell_num)
	
	if (not self.board_state[layer]) self.board_state[layer] = {}
	self.board_state[layer][cell_num] = player
	
	if tonumber(layer) >= self.board_depth then
		if (not self.end_time) end_time = stat(86)
		local piece = player == 0 and "Cross" or "Nought"
		if player == "null" then self:display("Draw!", 10)
		elseif player == self.my_piece then self:display("You win!")
		else self:display(piece .. " wins!", player == 0 and 8 or 9) end
	end
end

function GameScreen:setActiveGrids(layer, grid_num, next_piece)
	self.active_grids = {}
	self:makeGridActive(layer, grid_num)

	if layer and grid_num then
		self.default_controller_cell = {layer = layer - 1, num = grid_num*9 + 5}
		if self.controller_cell then
			self.controller_cell = {
				layer = self.default_controller_cell.layer,
				num = self.default_controller_cell.num
			}
		end
		
		if self.my_piece == next_piece and next_piece != null then
			self:display"Your turn!"
		elseif self.my_piece == "both" or (self.my_piece == "null" and self.moves > 1) then
			local piece_name = (next_piece:gsub("^%l", string.upper))
			self:display(piece_name .. "'s turn!", next_piece == "cross" and 8 or 9)
		elseif next_piece != "null" and self.moves > 1 then
			self:display()
		end
	else
		if (not self.end_time) self.end_time = stat(86)
		self.ready_to_flip = true
	end
end

--[[GROUP:Management]]

function GameScreen:addGridLayer(level, w, h, size)
	local too_small = self.board_depth - level > 4
	local border = too_small and 0 or flr(level * max(4-self.board_depth, 0.5))
	
	if (not self.cells[level]) self.cells[level] = {}
	add(self.cells[level], {w, h, size})
	
	if level > 0 then
		for i = 0, 2 do
			for j = 0, 2 do
				self:addGridLayer(level - 1, w+size*j//3 + border, h+size*i//3 + border, size//3 - border*2, size//3)
			end
		end
	end
end

function GameScreen:clearBelowCell(layer, grid_num)
	if layer <= 0 then return end
	local first_sub_cell = grid_num * 9
	for cell = 0, 8 do
		if (not self.board_state[layer-1]) self.board_state[layer-1] = {}
		self.board_state[layer-1][first_sub_cell + cell] = "cleared"
		if (layer - 1 > 0) self:clearBelowCell(layer - 1, first_sub_cell + cell)
	end
end

function GameScreen:makeGridActive(layer, grid_num)
	grid_num = tonumber(grid_num) -- dont like this check server code i think

	if layer == 1 then
		add(self.active_grids, grid_num + 1)
	elseif layer and grid_num then
		local first_sub_cell = grid_num * 9
		
		for cell = 0, 8 do
			if not
				(self.board_state[layer-1] and
				 self.board_state[layer-1][first_sub_cell+cell] != undefined)
			then
				self:makeGridActive(layer - 1, first_sub_cell + cell)
			end 
		end
	end
end

function GameScreen:drawInfoLine(x, y, title, content)
	local title_w = getPrintSize(title)
	print(title,   x - (title_w  //2), y, 36)
	local content_w = getPrintSize(content)
	print(content, x - (content_w//2), y + 10, 38)
end

function GameScreen:display(msg, icon)
	self.toast_msg = msg
	self.toast_icon = icon
	game_ui:display(msg, icon)
end

--[[GROUP:Inputs]]


function GameScreen:focusDefault()
	if (not self.default_controller_cell) return
	
	if (game_ui.menu.controller_focus_el) game_ui.menu.controller_focus_el = nil
	
	self.controller_cell = {
		layer = self.default_controller_cell.layer,
		num = self.default_controller_cell.num
	}
end

function GameScreen:updateController()	
	if not self.default_controller_cell then
		self.controller_cell = nil
		self.selected = nil
		return
	end
	if (not self.controller_cell) return
	
	local cs = self.controller_cell
	local l, c = cs.layer, cs.num - 1
	local rd = self.board_depth - l --recursive depth
	local lay_width = flr(3^rd + 0.5) - 1
	
	local row, col = getCoordsFromIndex(rd, c)
	
	if left() and col > 0 then
		cs.num = getIndexFromCoords(rd, row, col - 1) + 1
	elseif right() and col < lay_width then
		cs.num = getIndexFromCoords(rd, row, col + 1) + 1
	end
	if up() and row > 0 then
		cs.num = getIndexFromCoords(rd, row - 1, col) + 1
	elseif down() and row < lay_width then
		cs.num = getIndexFromCoords(rd, row + 1, col) + 1
	end
	
	if not self.cells[l][self.controller_cell.num] then
		self.controller_cell.num = c
	end
	
	if btnp(4) and cs and cs.layer == 0 then
		-- Ž place
		server:place(self.game_id, cs.num - 1)
	elseif btnp(4) and cs and cs.layer > 0 then
		-- Ž zoom in
		self.controller_cell = {
			layer = cs.layer - 1,
			num = (cs.num-1) * 9 + 5
		}
	elseif (btnp(5) or btnp(12)) and cs and cs.layer < self.board_depth - 1 then
		-- —/B zoom out
		self.controller_cell = {
			layer = cs.layer + 1,
			num = (cs.num-1) // 9 + 1
		}
	elseif (btnp(5) or btnp(12)) and cs and cs.layer == self.board_depth - 1 then
		-- —/B go to ui
		self.controller_cell = false
	elseif btnp(13) then
		-- Y refocus main cell
		if self.default_controller_cell.layer == self.controller_cell.layer
		and self.default_controller_cell.num == self.controller_cell.num
		then
			self.controller_cell = nil
		else
			self:focusDefault()
		end
	end
	
	self.selected = self.controller_cell
end

function GameScreen:findMouseSelected(mx, my, screen_pos)
	my += screen_pos*270

	local st, sb, sl, sr = 0, 270, 105, 375
	local range_f, range_l = 0, #self.cells[0]
	local thirds = (sb - st) / 3
	local length = flr((range_l - range_f) / 3 + 0.5)
	
	self.selected = nil
	
	while true do
		if my > st and my <= st+thirds then
			sb -= 2*thirds
			range_l -= 2*length
		elseif my > st+thirds and my <= st+2*thirds then
			st += thirds
			sb -= thirds
			range_f += length
			range_l -= length
		elseif my > sb-thirds and my <= sb then
			st += 2*thirds
			range_f += 2*length
		else
			return
		end
		
		length = flr(length/3 + 0.5)
		
		if mx > sl and mx <= sl+thirds then
			sr -= 2*thirds
			range_l -= 2*length
		elseif mx > sl+thirds and mx <= sl+2*thirds then
			sl += thirds
			sr -= thirds
			range_f += length
			range_l -= length
		elseif mx > sr-thirds and mx <= sr then
			sl += 2*thirds
			range_f += 2*length
		else
			return
		end

		if length <= 1 then
			self.selected = {layer = 0, num = range_l}
			if self.board_state["0"] then
				if self.board_state["0"][range_l-1] != nil then
					self.selected = nil
				end
			end
			return
		else
			local layer = flr(math.log(length)/math.log(9) + 0.5)
			local cell_num = flr(range_f / 9^(layer) + 0.5)
			if self.board_state[layer] then
				local l = self.board_state[layer]
				if (self.board_state[layer][cell_num] != nil) return
			end
		end
		
		length = flr(length/3 + 0.5)
		thirds /= 3
	end
end