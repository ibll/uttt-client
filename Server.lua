--[[pod_format="raw",created="2025-07-09 21:58:31",modified="2025-07-26 23:21:49",revision=375,xstickers={}]]
include "screens/GameScreen.lua"
include "screens/MenuScreen.lua"

Server = {}
Server.__index = Server

function Server:new(url)
	local self = setmetatable({}, Server)
	
	self.url = url
	self.sock = socket(self.url)
	self.tried_init = false
	self.pending_join = {}
	self.focus_next = false
	self.prev_err = ""
	
	return self
end

function Server:update()
	-- If no sock disconnects, try a new connection
	if not self:ready() then
		if tick % 200 == 0 then
			printh"Attempting to connect..."
			self.sock = socket(self.url)
			self.tried_init = false
		end
		return
	end
	
	-- Establish client identity
	if not self.tried_init then
		local payload = {
			type = "init",
			connection_id = prefs.connection_id
		}
		self.sock:write(json.fromtable(payload).."\n")
		self.tried_init = true
	end

	-- LISTEN FOR MESSAGES

	local incoming = self.sock:read()
	if (not incoming or incoming == nil) return
	
	local msgs = split(incoming, "\r\n")
	for _, msg in pairs(msgs) do
		if (msg == "") return
	
		local success, payload = pcall(json.totable, self.prev_err..msg, true)
	
		if not success then
			success, payload = pcall(json.totable, msg, true)
			if not success then
				printh("Incomplete/problem packet: " .. self.prev_err..msg)
				self.prev_err = self.prev_err..msg
			else
				printh("Discarding previous bad packets")
				self.prev_err = ""
			end
		elseif self.prev_err != "" then
			printh("Problem packet resolved")
			self.prev_err = ""
		end
		
		if (not payload) return
		
		if payload.type == "prepare_client" then
			self:_prepareClient(payload)
		elseif payload.type == "update_state" then
			self:_updateState(payload)		
		elseif payload.type == "display" then
			self:_display(payload)
		elseif payload.type == "piece_update" then
			self:_pieceUpdate(payload)
		elseif payload.type == "register_piece" then
			self:_registerPiece(payload)
		end
	end
end

--[[GROUP: STATUS]]

function Server:ready()
	if not self.sock then return false end
	return self.sock:status() == "ready"
end

--[[GROUP: INCOMING]]

function Server:_prepareClient(payload)
	local newtext = prefs.connection_id == payload.connection_id and "" or "new "
	prefs.connection_id = payload.connection_id
	savePrefs()
	printh("Established client with "..newtext.."connection ID " .. prefs.connection_id)
	
	if (prefs.games and #prefs.games > 0) printh("Asking to reconnect to "..#prefs.games.." game(s)")
	for _, v in pairs(prefs.games or {}) do
		self:join(v, true)
	end
end

function Server:_updateState(payload)
	if (not payload.game_id) return
	
	local existing_idx, existing_screen = screen_manager:getScreenBy(
		function(v) return v.game_id and v.game_id == payload.game_id end
	)
	
	if payload.nonexistant then
		if (existing_screen) existing_screen:remove()
		del(prefs.games, payload.game_id)
		savePrefs()
		return
	end
	
	local focus = del(self.pending_join, payload.game_id) != nil
	if (not focus and self.focus_next) focus = true self.focus_next = false

	if existing_screen then
		existing_screen:updateState(payload)
		if focus then
			screen_manager:focus(existing_idx)
			existing_screen:focusDefault()
		end
	else
		printh("Joining game " .. payload.game_id .. " with size " .. payload.board_depth or "unknown")
	
		local page = GameScreen:new(payload)
		local menuPageIdx = screen_manager:getScreenBy(
			function(v) return getmetatable(v) == MenuScreen end
		)
		
		if (not prefs.games) prefs.games = {}
		if count(prefs.games, payload.game_id) == 0 then
			add(prefs.games, payload.game_id)
			savePrefs()
		end
		
		local new_screen_idx = screen_manager:push(page, menuPageIdx + 1)
		local refocus = prefs.auto_focus and prefs.last_focused == payload.game_id
		if focus or refocus then
			screen_manager:focus(new_screen_idx)
			page:focusDefault()
		end
	end
end

function Server:_display(payload)
	local cur_screen = screen_manager:getScreen()
	if type(cur_screen.display) == "function" then
		cur_screen:display(payload.content)
	end
end

function Server:_pieceUpdate(payload)
	local idx, screen = screen_manager:getScreenBy(
		function(v) return v.game_id and v.game_id == payload.game_id end
	)
	
	screen:setActiveGrids(payload.active_layer, payload.active_grid_num, payload.next_piece);
	for _, piece in pairs(payload.pieces) do
		screen:place(piece.cell_layer, piece.cell_number, piece.piece)
	end
	
	screen.moves = payload.moves
end

function Server:_registerPiece(payload)
	local idx, screen = screen_manager:getScreenBy(
		function(v) return v.game_id and v.game_id == payload.game_id end
	)
	screen.my_piece = payload.piece
end

--[[GROUP: OUTGOING]]

function Server:write(tbl)
	self.sock:write(json.fromtable(tbl).."\n")
end

function Server:start(depth)
	self.focus_next = true
	self:write{ type = "start", size = depth }
end

function Server:join(game_id, automatic)
	if (not automatic) add(self.pending_join, game_id)
	self:write{ type = "join", game_id = game_id, automatic = automatic }
end

function Server:place(game_id, cell_num)
	self:write{ type = "place", game_id = game_id, cell_num = cell_num }
end