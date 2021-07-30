local grid_lib = {}
local grid = util.file_exists(_path.code.."midigrid") and include "midigrid/lib/midigrid" or grid

g = grid.connect()

local dirs = {["L"] = false,["R"] = false,["U"] = false,["D"] = false}
held_dirs = {["L"] = nil,["R"] = nil,["U"] = nil,["D"] = nil}

function grid_lib.init()
  clock.run(function()
    while true do
      clock.sleep(1/15)
      if grid_dirty then
        grid_redraw()
        grid_dirty = false
        for i = 1,8 do
          for j = 1,8 do
            if hills[i][j].perf_led then
              hills[i][j].perf_led = false
            end
          end
        end
      end
    end
  end)
  grid_dirty = true
end

local mods = {["hill"] = false,["bound"] = false,["notes"] = false,["loop"] = false,[5] = false,[6] = false,[7] = false,["stop"] = false}
local modkeys = {"hill","bound","notes","loop",5,6,7,"stop"}
function g.key(x,y,z)
  if x == 1 then
    if y >= 1 and y <= 4 then
      mod_held = z == 1 and true or false
      mods[modkeys[y]] = z == 1 and true or false
      if z == 1 then
        ui.control_set = "edit"
        ui.menu_focus = y
      else
        ui.control_set = "play"
      end
    elseif y == 8 then
      mod_held = z == 1 and true or false
      mods[modkeys[y]] = z == 1 and true or false
    end
    grid_dirty = true
    screen_dirty = true
  end
  if x > 1 and x <= 9 and not mod_held then
    if z == 1 then
      _a.one_shot(x-1,y)
      hills[x-1].screen_focus = y
      screen_dirty = true
      hills[x-1][y].perf_led = true
      grid_dirty = true
    end
  elseif x > 1 and x <= 9 and mod_held then
    if mods["stop"] and z == 1 then
      stop(x-1)
    elseif mods["hill"] or mods["bound"] or mods["notes"] or mods["loop"] then
      ui.hill_focus = x-1
      hills[ui.hill_focus].screen_focus = y
    end
  end
  if mod_held and not mods["stop"] then
    if x == 14 and y == 8 then
      if z == 1 then
        start_dir_clock("L",2,-1)
      elseif z == 0 then
        stop_dir_clock("L")
      end
    elseif x == 15 and y == 8 then
      if z == 1 then
        start_dir_clock("D",3,-1)
      elseif z == 0 then
        stop_dir_clock("D")
      end
    elseif x == 16 and y == 8 then
      if z == 1 then
        start_dir_clock("R",2,1)
      elseif z == 0 then
        stop_dir_clock("R")
      end
    elseif x == 15 and y == 7 then
      if z == 1 then
        start_dir_clock("U",3,1)
      elseif z == 0 then
        stop_dir_clock("U")
      end
    end
  end
  grid_dirty = true
  screen_dirty = true
end

function long_press(dir)
  if dir == "L" then
    _e.parse(2,-1)
  end
end

function grid_redraw()
  g:all(0)
  for i = 2,9 do
    for j = 1,8 do
      if mod_held then
        if hills[i-1].segment == j then
          g:led(i,j,hills[i-1][j].perf_led and 10 or (hills[i-1][j].iterated and 6 or 8))
        else
          g:led(i,j,4)
        end
        g:led(i,j,hills[i-1].screen_focus == j and 15 or 4)
      else
        if hills[i-1].segment == j then
          g:led(i,j,hills[i-1][j].perf_led and 15 or (hills[i-1][j].iterated and 6 or 8))
        else
          g:led(i,j,4)
        end
      end
    end
  end
  for i = 1,8 do
    g:led(1,i,mods[modkeys[i]] and 15 or 0)
  end
  if mod_held and not mods["stop"] then
    g:led(14,8,dirs["L"] and 15 or 8)
    g:led(15,7,dirs["U"] and 15 or 8)
    g:led(15,8,dirs["D"] and 15 or 8)
    g:led(16,8,dirs["R"] and 15 or 8)
  end
  g:refresh()
end

function start_dir_clock(dir,n,d)
  _e.parse(n,d)
  held_dirs[dir] = clock.run(
    function()
      while true do
        clock.sleep(0.15)
        _e.parse(n,d)
      end
    end
  )
  dirs[dir] = true
end

function stop_dir_clock(dir)
  if held_dirs[dir] then
    clock.cancel(held_dirs[dir])
  end
  dirs[dir] = false
end

return grid_lib