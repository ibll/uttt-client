--[[pod_format="raw",created="2025-07-23 00:54:14",modified="2025-07-30 20:33:07",revision=66,xstickers={}]]
## [Planned]

- In game tutorial
- Maybe fix backend as well for non-endless 1 size boards
	- Low prior. cause you can't even make these w/o console commands
- Change host server
- Join game keyboard input
- Web player socket warning
- Industrial background art
- Decorative bits and bobs to play with
- Rehaul of controller page nav?
	- Based around right bumper
	- Pop in animation like the rain world map if held without input
	- RB + LS/d-pad for moving up and down
	- RB + RS for screen selection radial???
	- otherwise, RB + RS to reorder games?
	- RB + LB to quick access menu

## [0.6-beta] 2025-07-30

- Made game ui static when scrolling through multiple games
- Added copy url button to games
- Added up/down buttons to settings and menu screen
- Adjusted height of settings controls

## [0.5-beta] 2025-07-26

- Added settings page
	- Piece colour selection
	- Auto reconnect on restart
- Added page scroll indicator
- Added vim binds (HJKL) for navigation
- Fixed visual problem in regular 1-layer tic-tac-toe rendering

## [0.3-alpha] 2025-07-24

- Added bumpers + Q/E to navigate screens
- Added right stick / WASD input for all left stick inputs
- Added timeout when holding gui button for too long
- Added in-game controller support
	- A to zoom in or place
	- X/B to zoom out or go to menu
	- Y to focus default cell or toggle exit focus
- Added extra join screen controller inputs
	- Y/B to focus default button or toggle exit focus
- Added auto-focus previously focused game on restart
- Added player peice/role indicator
- Button to exit game focuses next in scroll direction, not just up
- Moving down to choose a game size now favours size 2
- Changed game timer to display in a readable format
- Fixed timer being incorrect on rejoin
- Fixed toast showing player turn instead of who won when reconnecting

## [0.2-alpha] 2025-07-22

- Added turn and win indicator to games
- Added game auto-reconnect on restart
- Added button to leave a game
- Added move counter
- Added partially working game timer