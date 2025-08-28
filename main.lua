--[[pod_format="raw",created="2025-07-07 02:21:51",modified="2025-07-26 22:22:22",revision=1156,xstickers={}]]
--include"/dev/profiler.lua"
--profile.enabled(true,true)

-- Ultimate Tic-Tac-Toe
-- Client for uttt.ibll.dev
-- by ibll

include"libs/json.lua"
include"Server.lua"
include"screens/ScreenManager.lua"
include"screens/MenuScreen.lua"
include"screens/GameUI.lua"

printh""
printh"Launching UTTT..."

tick = 0
controller_active = false
colors = {
	{42, 44, 46}, -- red
	{43, 45, 47}, -- blue
	{53, 55, 57}, -- pink
	{50, 51, 63}, -- teal
	{52, 54, 56}, -- orange
	{59, 61, 40}, -- green
	{58, 60, 62}, -- purple
	
	{61, 40, 41}, -- highlight
	{49, 48, 39}, -- active
	{38, 36, 35}, -- ties
}
screen_manager = ScreenManager:new()
game_ui = GameUI:new()
url = "uttt.ibll.dev"
server = Server:new("tcp://"..url..":3001")

local pref_loc = "/appdata/uttt.pod"
prefs = fetch(pref_loc)
if (not prefs) prefs = {}
if (not prefs.cross_col) prefs.cross_col = 1
if (not prefs.nought_col) prefs.nought_col = 2

local mx, my = 0, 0

function _init()
	local fname = "/desktop/title.png"
	store(fname,get_spr(1))

	-- set pallette
	fetch("pal/0.pal"):poke(0x5000)
	-- some colour thing for fillp i think
	poke(0x550b,0x3f)
	palt()
	screen_manager:push(MenuScreen:new())
end

function _update()
--	profile("_update")
	tick = tick + 1

	local nmx,nmy,mouse_b = mouse()
	local mouse_moved = false
	if abs(nmx-mx) > 5 or abs(nmy-my) > 5 then	
		mouse_moved = true
	end
	mx, my = nmx, nmy

	if (left() or right() or up() or down()) and not controller_active then
		controller_active = true
		window{cursor = 0}
	elseif (mouse_b > 0 or mouse_moved) and controller_active then
		controller_active = false
		window{cursor = 1}
	end

	server:update()
	screen_manager:update()
	if controller_active then
		window{cursor = 0}
	end
--	profile("_update")
end

function _draw()
--	profile("_draw")

	local d = get_display()
	local w = d:width()
	local h = d:height()
	
	cls(34)

	screen_manager:draw(d, w, h)
	
	camera()

	if not server:ready() then
		rectfill(0, 0, w, 10, 6)
		local toggle = flr(tick/10)%2 == 0
		print((toggle and " ˜" or " ™") .. "Connecting to server...", 0, 2, toggle and 8 or 24)
	end
--	profile("_draw")
	--profile.draw()
end

--[[GROUP: GLOBAL]]

function savePrefs(tbl)
	store(pref_loc, tbl or prefs)
end

function getPrintSize(str)
    local ww, hh = print(tostr(str), -10000, -10000)
    ww += 10000
    hh += 10000
    return ww, hh
end

function left () return btnp(0) or btnp(8)  or keyp"h" end
function right() return btnp(1) or btnp(9)  or keyp"l" end
function up   () return btnp(2) or btnp(10) or keyp"k" end
function down () return btnp(3) or btnp(11) or keyp"j" end