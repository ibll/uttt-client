--[[pod_format="raw",created="2025-07-12 17:55:54",modified="2025-07-26 10:18:15",revision=1033,xstickers={}]]
include "screens/Screen.lua"
include "libs/jui.lua"
include "libs/json.lua"
include "libs/lerp.lua"
include "libs/rope.lua"
include "libs/particles.lua"

JoinScreen = {}

setmetatable(JoinScreen, Screen)
JoinScreen.__index = JoinScreen

local function randomNormal(mean, std_dev)
    mean = mean or 0
    std_dev = std_dev or 1
    
    -- Sum 12 uniform random numbers and subtract 6
    -- This gives mean=0, std_dev
    local sum = 0
    for i = 1, 12 do
        sum = sum + math.random()
    end
    
    local normal = sum - 6
    return normal * std_dev + mean
end

--[[GROUP:Screenmanager]]

function JoinScreen:new()
	local self = setmetatable({}, JoinScreen)
	
	self.menu = create_gui()
	self.particle_manager = ParticleManager:new{ gravity = 0.25 }
	self.default_focus = nil
	self.vowel_keyboard = true
	self.str = ""
	
	self.display_msg = ""
	self.display_time = 400
	self.display_target = 0
	
	self.jitter_amt = 0
	self.jitter_time = 40
	self.jitter_reset_target = tick
	
	self.exit_jitter = 0
	
	self.cables = nil
	self.pins = {}
	self.grabbedPoint = nil
	
	local c = {
		{"b", "c", "d", "f", "g"},
		{"h", "j", "k", "m", "n"},
		{"r", "s", "t", "y", "z"}
	}
	local v = {
		{"a", "e", "i", "o", "u"}
	}
	local grid_prefs = {l = "key_exit", r = "key_bs", gap = 2}
	-- some of these are fucked, uh need to fix that function but who cares
	self.consonants = self:generateKeyGrid(c, 151, 124+28, 178, 77, grid_prefs)
	self.vowels = self:generateKeyGrid(v, 151, 120.5, 178, 24, grid_prefs)
	for k, v in pairs(self.consonants) do self.menu:attach(v) end
	for k, v in pairs(self.vowels) do self.menu:attach(v) end
	
	-- Sides tables for these are updated in
	-- setConsonants and setVowels
	self.key_exit = jui.button{
		x = 60, y = 112,
		width = 48, height = 32,
		label = "Exit", depth = 4,
		base_col = 21, accent_col = 10, active_col = 14,
		shadow_col = 32, controller_col = 7,
		fire = function() screen_manager:down() end,
	}
	self.key_bs = jui.button{
		x = 332, y = 132,
		width = 48, height = 32,
		label = "Delete", spam = true,
		base_col = 21, accent_col = 10, active_col = 14,
		shadow_col = 32, controller_col = 7, indent_col = 21,
		fire = function() self:bs() self.menu.controller_focus_el = self.key_bs end,
	}
	
	self.menu:attach(self.key_exit)
	self.menu:attach(self.key_bs)
	
	-- Default to consonant keyboard
	self:setConsonants()

	return self
end

function JoinScreen:draw(d, w, h, screenLerp)
	-- Cables and particles exist in display space, not page space
	camera()
	
	if self.cables then
		for k, v in pairs(self.cables) do
			v:draw()
		end
	end
	
	self.particle_manager:draw()

	-- Other elements should be in page space
	camera(0, screenLerp * h)

	-- Panel display
	rectfill(160, 80, 320, 112, 32)
	local j = self.jitter_amt
	
	-- Top line
	local tl = 162 + j
	tl = print("JOIN GAME", tl, 83, 11)
	tl = print(":", tl, 83, (tick // 60 % 2 == 0) and 6 or 7)
	tl = print(self.str, tl, 83, 11)
	tl = print(#self.str < 6 and "_" or "", tl, 83, (tick // 60 % 2 == 0) and 6 or 7)
	tl = print(string.rep("_", 5 - #self.str), tl, 83, 11)
	if tick <= self.display_target then
		local last_seconds = tick >= self.display_target - self.display_time / 3
		local flash = last_seconds and tick // 15 % 2 == 0
		print(string.sub(self.display_msg, 1, 31) , 162+j, 102, flash and 14 or 8)
	end
	
	spr(3, 54 + self.exit_jitter, 106 + self.exit_jitter) -- Exit panel
	spr(4, 144, 60) -- Keypad panel
	spr(tick//30 % 2 == 0 and 5 or 6, 340, 114) -- Lights

	rectfill(160, 147, 320, 148, 21) 

	-- GUI doesn't automatically follow camera, so force that
	self.menu.y = -screenLerp * h
	self.menu:draw_all()

end

function JoinScreen:update(focused, screenLerp)
	if not server:ready() then
		self.disabled = true
		screen_manager:down()
	end

	-- Reduce jitter
	self.jitter_amt = lerp(self.jitter_amt, 0, 1 - math.max(0, (self.jitter_reset_target - tick) / self.jitter_time))
	
	-- Jitter flimsy exit panel
	self.exit_jitter = math.log(math.abs(self.jitter_amt) + 1) / math.log(3)
	if not self.key_exit.og_x then
		self.key_exit.og_x = self.key_exit.x
		self.key_exit.og_y = self.key_exit.y
	end
	self.key_exit.x = self.exit_jitter + self.key_exit.og_x
	self.key_exit.y = self.exit_jitter + self.key_exit.og_y

	-- We want the rope physics to escape the screen manager.
	-- Sucky solution but it works
	local pinh = -screenLerp * get_display():height()

	-- Don't want to create ropes in new() because new isn't
	-- Aware of height. Rope starting position needs to be accurate
	-- to prevent goofy physics snapping.
	if not self.cables then
		-- Add pinh here for the actual position to have offset
		self.cables = {
			Rope:new(100, 166 + pinh, 143, 200 + pinh, {
				length = 125, col = 10,
				permaPins = true, gravity = 0.25,
				strength = 5, iterations = 3, damping = 0.95,
				onCut = function(r, p1, p2) self:snipExit(r, p1, p2) end
			}),
			Rope:new(90, 145 + pinh, 143, 190 + pinh, {
				length = 125, col = 8,
				permaPins = true, gravity = 0.25,
				strength = 5, iterations = 3, damping = 0.95,
				onCut = function(r, p1, p2) self:snipExit(r, p1, p2) end
			})
		}
		
		self.pins = {
			self.cables[1].points[1],
			self.cables[1].points[#self.cables[1].points],
			self.cables[2].points[1],
			self.cables[2].points[#self.cables[2].points],
		}
		
		-- remove pinh in oldy on pinned points because that stores
		-- the non-screen-aware position for pinned points.
		for _, v in pairs(self.pins) do
			v.oldy -= pinh
		end
	end

	-- Figure out when to grab cables
	if (focused) self:grabRopes()

	-- Make pin ends follow screen movement
	for _, v in pairs(self.pins) do
		v.x = v.oldx + self.exit_jitter
		v.y = v.oldy + pinh + self.exit_jitter
	end
	
	-- Update effects
	for _, v in pairs(self.cables) do
	
		v:update()
		
		-- Spark continually but occassionally if cut
		if v.snipped and rnd(1) < 0.05 then
			local last_point_connected = v.chunks[#v.chunks].b == v.points[#v.points]
			local p = nil
			
			-- last point only has one neighbour, so we have to ignore
			-- it when finding the cut unless it's our only option
			local i = #v.points - (last_point_connected and 1 or 0)
			while p == nil and i > 1 do
				if (#v.points[i].chunks < 2) p = v.points[i]
				i -= 1
			end
			
			local cols = {7, 10, 9, 25, 31}
			local part = Particle:new{
				x = p.x, y = p.y,
				dx = randomNormal(0, 2),
				dy = randomNormal(0, 2),
				col = cols[flr(rnd(#cols))],
			}
			self.particle_manager:insert(part)
		end
	end
	self.particle_manager:update()
	
	-- IMPORTANT: FURTHER ONLY WHEN FOCUSED
	if (not focused) return

	-- Submit code when long enough
	if #self.str >= 6 then
		server:join(self.str)
		self.str = ""
		self.jitter_amt = 10
	end
	
	-- X acts as backspace shortcut
	if btnp(5) then
		-- When clicking bs with O, its fire function automatically
		-- refocuses it. When hovering and clicking X, we want to
		-- keep it focused.
		local refocus_bs = false
		if (self.menu.controller_focus_el == self.key_bs) refocus_bs = true
		
		self:bs()
		self.key_bs.lift = -1
		if (refocus_bs) self.menu.controller_focus_el = self.key_bs
	end

	self:updateController()
	self.menu:update_all()
end

function JoinScreen:lostFocus()
	-- Delete Screen
	screen_manager:remove(screen_manager:getIndex(self))
end

--[[GROUP:Typing]]

function JoinScreen:letter(l)
	self.str = self.str .. l
	if self.vowel_keyboard then
		self:setConsonants()
	else
		self:setVowels()
	end
	self:jitter()
end

function JoinScreen:bs()
	if (self.str == "") return
	self.str = string.sub(self.str, 1, -2)
	if self.vowel_keyboard then
		self:setConsonants()
	else
		self:setVowels()
	end
	self:jitter()
end

function JoinScreen:generateKeyGrid(tbl, x, y, w, h, prefs)
	prefs = prefs or {}
	local gap = prefs.gap or 4
	local output = {}

	local rows = #tbl
	local keyh = (h - (rows - 1) * gap) / rows
	
	for rk, rv in pairs(tbl) do
		-- rows
		local cols = #(tbl[1])	
		local keyw = (w - (cols - 1) * gap) / cols
		
		for ck, cv in pairs(rv) do
			--cols
			
			local sides = {}
			if rk > 1    then sides.u = "key_" .. tbl[rk - 1][ck] else sides.u = prefs.u end
			if rk < rows then sides.d = "key_" .. tbl[rk + 1][ck] else sides.d = prefs.d end
			if ck > 1    then sides.l = "key_" .. tbl[rk][ck - 1] else sides.l = prefs.l end
			if ck < cols then sides.r = "key_" .. tbl[rk][ck + 1] else sides.r = prefs.r end
		
			self["key_" .. cv] = jui.button{
				x = (ck-1)*(keyw+gap) + x, y = (rk-1)*(keyh+gap) + y,
				width = keyw, height = keyh,
				label = string.upper(cv),
				base_col = 21, accent_col = 10, active_col = 14,
				shadow_col = 32, controller_col = 7,
				sides = sides,
				fire = function() self:letter(cv) end,
			}
			
			table.insert(output, self["key_" .. cv])
		end
	end
	
	return output
end

function JoinScreen:setVowels()
	if (self.vowel_keyboard) return
	
	for k, v in pairs(self.consonants) do
		v.disabled = true
		v.base_col = 32
		v.accent_col = 5
	end
	
	for k, v in pairs(self.vowels) do
	v.disabled = false
	v.base_col = 21
	v.accent_col = 10
	end
		
	self.key_exit.sides = {u = "key_a", d = "key_a", r = "key_a"}
	self.key_bs.sides = {u = "key_u", d = "key_u", l = "key_u"}
	
	self.default_focus = self.key_i
	self.menu.controller_focus_el = nil
	self.vowel_keyboard = true
end

function JoinScreen:setConsonants()
	if (not self.vowel_keyboard) return
	for k, v in pairs(self.vowels) do
		v.disabled = true
		v.base_col = 32
		v.accent_col = 5
	end
	
	for k, v in pairs(self.consonants) do
		v.disabled = false
		v.base_col = 21
		v.accent_col = 10
	end
	
	self.key_exit.sides = {d = "key_h", r = "key_b"}
	self.key_bs.sides = {d = "key_n", l = "key_g"}
		
	self.default_focus = self.key_k
	self.menu.controller_focus_el = nil
	self.vowel_keyboard = false
end


--[[GROUP:Misc]]

function JoinScreen:grabRopes()
	local mx, my, mb = mouse()
	local lmb = mb & (1 << 0) ~= 0
	
	local closeDistance = 10
	local closestPoint = nil
	local minDistance = math.huge
	
	for _, r in ipairs(self.cables) do
		for _, p in ipairs(r.points) do
			local d = p:dist(mx, my)
			
			if (p.hasPin) goto jumpskip
			if (d > closeDistance) goto jumpskip
			if (d < minDistance) minDistance=d closestPoint=p
			
			::jumpskip::
		end
	end
	
	local hovering = closestPoint and not grabbedPoint
	
	if hovering and lmb then
		hovering = false
		grabbedPoint = closestPoint
		grabbedPoint.grabbed = true
	elseif not lmb and grabbedPoint then
		grabbedPoint.grabbed = false
		grabbedPoint = nil
	end
	
	if grabbedPoint then
		window{cursor = --[[pod_type="gfx"]]unpod("b64:bHo0ACYAAAAoAAAA8QBweHUAQyAQEATwVkGQAQcCAHFwEUcBcAFXBACAgAE3AaAx8CY=")}
		grabbedPoint.x = mx
		grabbedPoint.y = my
	elseif hovering then
		window{cursor = --[[pod_type="gfx"]]unpod("b64:bHo0ADsAAAA6AAAA8QxweHUAQyAQEATwOAGwIQcBAAFwARcRBwEHAXAGAPALBwFgAQABNwFgAQcRNwFwAVcBgAE3AaAx8CY=")}
	else
		window{cursor = 1}
	end
end

function JoinScreen:display(msg)
	self.display_msg = msg
	self.display_target = tick + self.display_time
end

function JoinScreen:jitter()
	local amt = 4
	self.jitter_amt = rnd(amt*2) - amt
	self.jitter_reset_target = tick + self.jitter_time
end

function JoinScreen:updateController()
	if (not controller_active) return
	
	if not self.menu.controller_focus_el then
		self.menu.controller_focus_el = self.default_focus
		return
	end
	
	local s = self.menu.controller_focus_el.sides or {}
	
	if (left()  and s.l) self.menu.controller_focus_el = self[s.l]
	if (right()  and s.r) self.menu.controller_focus_el = self[s.r]
	if (up() and s.u) self.menu.controller_focus_el = self[s.u]	
	if (down() and s.d) self.menu.controller_focus_el = self[s.d]
	if btnp(13) or btnp(12) then
		if self.menu.controller_focus_el == self.default_focus then
			self.menu.controller_focus_el = self.key_exit
		else
			self.menu.controller_focus_el = self.default_focus
		end
	end
end

function JoinScreen:snipExit(r, p1, p2)
	--self.key_exit.disabled = true
	self.key_exit.base_col = 32
	self.key_exit.accent_col = 5
	self.key_exit.active_col = 24
	self.key_exit.controller_col = 8
	self.disabled = true
	
	if r and not r.snipped then
		r.snipped = true
		for i = 1, 10 + rnd(10) do
			local p = rnd(2) < 1 and p1 or p2
			local cols = {7, 10, 9, 25, 31}
			local part = Particle:new{
				x = p.x, y = p.y,
				dx = randomNormal(0, 5),
				dy = randomNormal(0, 5),
				col = cols[flr(rnd(#cols))],
			}
			self.particle_manager:insert(part)
		end
	end
end