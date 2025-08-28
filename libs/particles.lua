--[[pod_format="raw",created="2025-07-16 21:28:26",modified="2025-07-17 23:57:32",revision=44,xstickers={}]]
Particle = {}
Particle.__index = Particle

function Particle:new(el)
	local self = setmetatable({}, Particle)
	el = el or {}
	
	self.x, self.y = el.x, el.y
	self.dx, self.dy = el.dx, el.dy
	self.col = el.col or 10
	
	return self
end

ParticleManager = {}
ParticleManager.__index = ParticleManager

function ParticleManager:new(el)
	local self = setmetatable({}, ParticleManager)
	el = el or {}
	
	self.particles = {}
	self.gravity = el.gravity or 1
	self.damping = el.damping or 0.8
	
	return self
end

function ParticleManager:update()
	for k = #self.particles, 1, -1 do
    local p = self.particles[k]
		p.x += p.dx
		p.y += p.dy
		p.dx *= self.damping
		p.dy += self.gravity
		if (p.y >= 1000) deli(self.particles, k)
		::particleskip::
	end
end

function ParticleManager:draw()
	for _, p in pairs(self.particles) do
		--pset(p.x, p.y, p.col)
		circfill(p.x, p.y, rnd(2), p.col)
	end
end

function ParticleManager:insert(p)
	add(self.particles, p)
end