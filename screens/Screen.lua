--[[pod_format="raw",created="2025-07-08 19:36:31",modified="2025-07-12 21:42:19",revision=6]]
Screen = {}
Screen.__index = Screen

function Screen:new(name)
	local self = setmetatable({}, Screen)
	
	assert(name ~= nil)
	self.name = name
	
	return self
end

function Screen:draw() end

function Screen:update() end

function Screen:gainedFocus() end

function Screen:lostFocus() end