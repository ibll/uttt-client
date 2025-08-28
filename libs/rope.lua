--[[pod_format="raw",created="2025-07-14 19:57:03",modified="2025-07-18 00:00:26",revision=31,xstickers={}]]
local function dist(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

Point = {}
Point.__index = Point

function Point:new(x, y, pinned)
	local self = setmetatable({}, Point)
	
	self.x = x
	self.y = y
	self.oldx = x
	self.oldy = y
	
	self.chunks = {}
	
	self.hasPin = pinned or false
	self.grabbed = false
	
	return self
end

function Point:dist(x, y)
	return dist(self.x, self.y, x, y)
end

RopeChunk = {}
RopeChunk.__index = RopeChunk

function RopeChunk:new(a, b, length, col)
	local self = setmetatable({}, RopeChunk)
	
	self.a = a
	self.b = b
	self.length = length
	self.col = col or 6
	
	add(self.a.chunks, self)
	add(self.b.chunks, self)
	
	return self
end

function RopeChunk:cut()
	del(self.a.chunks, self)
	del(self.b.chunks, self)
	self = nil
end

Rope = {}
Rope.__index = Rope

function Rope:new(x1, y1, x2, y2, el)
	local self = setmetatable({}, Rope)
	el = el or {}
	
	self.x1 = x1
	self.y1 = y1
	self.x2 = x2
	self.y2 = y2
	self.numChunks = el.sections or 20
	self.length = el.length or dist(x1, y1, x2, y2) / 2
	self.defaultLength = self.length/self.numChunks
	self.points = {}
	self.chunks = {}
	self.gravity = el.gravity or 0.5
	self.damping = el.damping or 0.99
	self.iterations = el.iterations or 3
	self.strength = el.strength or math.huge
	self.onCut = el.onCut
	
	local stepx = (x2 - x1) / (self.numChunks + 1)
	local stepy = (y2 - y1) / (self.numChunks + 1)
	for i = 1, self.numChunks + 1 do
		local pin = i == 1 or i == self.numChunks + 1
		add(
			self.points,
			Point:new(x1 + i * stepx, y1 + i * stepy, pin)
		)
	end
	
	for i = 1, self.numChunks do
		add(
			self.chunks,
			RopeChunk:new(self.points[i], self.points[i + 1], self.defaultLength, el.col)
		)
	end
	
	return self
end

function Rope:update()
	for _, p in pairs(self.points) do
		if not (p.hasPin or p.grabbed or #p.chunks > 2) then
			local vx = (p.x - p.oldx) * self.damping
			local vy = (p.y - p.oldy) * self.damping
			p.oldx = p.x
			p.oldy = p.y
			p.x += vx
			p.y += vy + self.gravity
		end
	end
	
	for i = 1, self.iterations do
		self:solve(i)
	end
	
	for i = #self.chunks, 1, -1 do
		local c = self.chunks[i]
		if c.a:dist(c.b.x, c.b.y) > c.length * self.strength then
			local chunk = c
			deli(self.chunks, i)
			c:cut()
			if (type(self.onCut) == "function") self.onCut(self, c.a, c.b)
		end
	end
end

function Rope:solve(it)
	for _, c in pairs(self.chunks) do
		local p1, p2 = c.a, c.b
		local dx = p2.x - p1.x
		local dy = p2.y - p1.y
		local d = sqrt(dx*dx + dy*dy)
		
		if (d < 0.001) return
		
		local diff = c.length - d
		local percent = diff / d / 2
		local offX = dx * percent
		local offY = dy * percent
		
		if (not (p1.hasPin or p1.grabbed)) p1.x -= offX p1.y -= offY	
		if (not (p2.hasPin or p2.grabbed)) p2.x += offX p2.y += offY
	end
end

function Rope:draw()
	for k, v in pairs(self.chunks) do
		line(v.a.x, v.a.y, v.b.x, v.b.y, v.col)
	end
end