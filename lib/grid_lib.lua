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

mods = {["hill"] = false,["bound"] = false,["notes"] = false,["loop"] = false,["playmode"] = false,[6] = false,["copy"] = false,["stop"] = false}
local modkeys = {"hill","bound","notes","loop","playmode",6,"copy","stop"}
function g.key(x,y,z)
  if x == 1 then
    if y >= 1 and y <= 4 and z == 1 then
      for i = 1,#modkeys do
        if i ~= y then
          mods[modkeys[i]] = false
        else
          mods[modkeys[y]] = not mods[modkeys[y]]
          mod_held = mods[modkeys[y]]
        end
      end
      if mod_held then
        ui.control_set = "edit"
        ui.menu_focus = y
      else
        ui.control_set = "play"
      end
    elseif y == 5 or y == 7 or y == 8 then
      for i = 1,#modkeys do
        if i ~= y then
          mods[modkeys[i]] = false
        else
          mods[modkeys[y]] = not mods[modkeys[y]]
          mod_held = mods[modkeys[y]]
        end
      end
      ui.control_set = "play"
      if not mods["copy"] and clipboard then
        clipboard = nil
        copied = nil
      end
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
    if z == 0 then
      if hills[x-1][y].playmode == "momentary" and hills[x-1].segment == y then
        stop(x-1)
        screen_dirty = true
        hills[x-1][y].perf_led = true
        grid_dirty = true
      end
    end
  elseif x > 1 and x <= 9 and mod_held then
    if mods["stop"] and z == 1 then
      stop(x-1)
    elseif mods["hill"] or mods["bound"] or mods["notes"] or mods["loop"] then
      ui.hill_focus = x-1
      hills[ui.hill_focus].screen_focus = y
    elseif mods["playmode"] and z == 0 then
      hills[x-1][y].playmode = hills[x-1][y].playmode == "momentary" and "latch" or "momentary"
    elseif mods["copy"] and z == 1 then
      print("copying...")
      if not clipboard then
        clipboard = _t.deep_copy(hills[x-1][y])
        copied = {x-1,y}
      else
        hills[x-1][y] = _t.deep_copy(clipboard)
        copied = nil
        clipboard = nil
      end
    end
  end
  if mod_held and not mods["stop"] and not mods["copy"] then
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
        if not mods["playmode"] and not mods["copy"] then
          if i-1 == ui.hill_focus and hills[ui.hill_focus].screen_focus == j then
            g:led(i,j,15)
          else
            if hills[i-1].segment == j then
              g:led(i,j,hills[i-1][j].perf_led and 10 or (hills[i-1][j].iterated and 6 or 8))
            else
              g:led(i,j,0)
            end
          end
          if mods["stop"] then
            if hills[i-1].segment == j then
              g:led(i,j,hills[i-1][j].perf_led and 15 or (hills[i-1][j].iterated and 6 or 15))
            else
              g:led(i,j,0)
            end
            -- g:led(i,j,hills[i-1].screen_focus == j and 15 or 4)
          end
        elseif not mods["playmode"] then
          if hills[i-1].segment == j then
            g:led(i,j,10)
          end
          if copied ~= nil then
            if copied[1] == i-1 and copied[2] == j then
              g:led(i,j,15)
            end
          end
        elseif mods["playmode"] then
          -- local display_level = 4
          if hills[i-1][j].playmode == "momentary" then
            display_level = 4
          else
            display_level = 15
          end
          g:led(i,j,display_level)
        end
      else
        if hills[i-1].segment == j then
          g:led(i,j,hills[i-1][j].perf_led and 15 or (hills[i-1][j].iterated and 6 or 8))
        else
          g:led(i,j,0)
        end
      end
    end
  end
  for i = 1,8 do
    g:led(1,i,mods[modkeys[i]] and 15 or 0)
  end
  if mod_held and not mods["playmode"] and not mods["stop"] and not mods["copy"] then
    g:led(14,8,dirs["L"] and 15 or 8)
    g:led(15,7,dirs["U"] and 15 or 8)
    g:led(15,8,dirs["D"] and 15 or 8)
    g:led(16,8,dirs["R"] and 15 or 8)
  end
  if mod_held and mods["copy"] then
    if not clipboard then
      for i = 12,14 do
        for j = 3,6 do
          if j == 3 or j == 6 then
            g:led(i,j,15)
          elseif (j == 4 or j == 5) and i == 12 then
            g:led(i,j,15)
          end
        end
      end
    elseif clipboard then
      for i = 12,14 do
        for j = 3,6 do
          if j == 3 or j == 5 then
            g:led(i,j,15)
          elseif j == 4 and (i == 12 or i == 14) then
            g:led(i,j,15)
          elseif j == 6 and i == 12 then
            g:led(i,j,15)
          end
        end
      end
    end
  end
  if mod_held and mods["playmode"] then

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