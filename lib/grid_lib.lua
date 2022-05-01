local grid_lib = {}
local grid = util.file_exists(_path.code.."midigrid") and include "midigrid/lib/midigrid" or grid

g = grid.connect()

local dirs = {["L"] = false,["R"] = false,["U"] = false,["D"] = false}
held_dirs_clocks = {["L"] = nil,["R"] = nil,["U"] = nil,["D"] = nil}
held_dirs_iters = {["L"] = 0,["R"] = 0,["U"] = 0,["D"] = 0}

active_voices = {}
for i = 1,16 do
  active_voices[i] = {}
  for j = 1,8 do
    active_voices[i][j] = false
  end
end

function grid_lib.pattern_execute(data)
  if data.event == "start" then
    _a.start(data.x,data.y,true)
    active_voices[data.id][data.x] = true
    screen_dirty = true
    hills[data.x][data.y].perf_led = true
    grid_dirty = true
  elseif data.event == "stop" and hills[data.x][data.y].playmode == "momentary" then
    stop(data.x,true)
    active_voices[data.id][data.x] = false
    screen_dirty = true
    hills[data.x][data.y].perf_led = false
    grid_dirty = true
  end
end

grid_pattern = {}
for i = 1,16 do
  grid_pattern[i] = pt.new()
  grid_pattern[i].process = grid_lib.pattern_execute
end

function grid_lib.handle_grid_pat(i,alt)
  if not alt then
    if grid_pattern[i].rec == 1 then -- if we're recording...
      grid_pattern[i]:rec_stop() -- stop recording
      grid_pattern[i]:start() -- start playing
    elseif grid_pattern[i].count == 0 then -- otherwise, if there are no events recorded..
      grid_pattern[i]:rec_start() -- start recording
    elseif grid_pattern[i].play == 1 then -- if we're playing...
      grid_lib.stop_pattern_playback(i)
    else -- if by this point, we're not playing...
      grid_pattern[i]:start() -- start playing
    end
  else
    grid_pattern[i]:rec_stop() -- stops recording
    grid_pattern[i]:stop() -- stops playback
    for j = 1,#active_voices[i] do
      if active_voices[i][j] then
        stop(j,true)
        active_voices[i][j] = false
      end
    end
    grid_pattern[i]:clear() -- clears the pattern
  end
end

function grid_lib.stop_pattern_playback(i)
  grid_pattern[i]:stop() -- stop playing
  for j = 1,#active_voices[i] do
    if active_voices[i][j] then
      stop(j,true)
      active_voices[i][j] = false
    end
  end
end

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

mods = {["hill"] = false,["bound"] = false,["notes"] = false,["loop"] = false,["playmode"] = false,["copy"] = false,[7] = false,["alt"] = false}
local modkeys = {"hill","bound","notes","loop","playmode","copy",7,"alt"}
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
        if ui.control_set ~= "song" then
          ui.control_set = "edit"
        end
        ui.menu_focus = y
      else
        if ui.control_set ~= "song" then
          ui.control_set = "play"
        end
      end
    elseif y == 5 or y == 6 or y == 8 then
      for i = 1,#modkeys do
        if i ~= y then
          mods[modkeys[i]] = false
        else
          mods[modkeys[y]] = not mods[modkeys[y]]
          mod_held = mods[modkeys[y]]
        end
      end
      if ui.control_set ~= "song" then
        ui.control_set = "play"
      end
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
      _a.start(x-1,y,true)
      hills[x-1].screen_focus = y
      screen_dirty = true
      hills[x-1][y].perf_led = true
      grid_dirty = true
      for i = 1,16 do
        grid_pattern[i]:watch(
          {
            ["event"] = "start",
            ["x"] = x-1,
            ["y"] = y,
            ["id"] = i
          }
        )
      end
    end
    if z == 0 then
      if hills[x-1][y].playmode == "momentary" and hills[x-1].segment == y then
        stop(x-1,true)
        screen_dirty = true
        -- hills[x-1][y].perf_led = true
        hills[x-1][y].perf_led = false
        grid_dirty = true
      end
      for i = 1,16 do
        grid_pattern[i]:watch(
          {
            ["event"] = "stop",
            ["x"] = x-1,
            ["y"] = y,
            ["id"] = i
          }
        )
      end
    end
  elseif x > 1 and x <= 9 and mod_held then
    if mods["alt"] and z == 1 then
      stop(x-1,true)
    elseif mods["hill"] or mods["bound"] or mods["notes"] or mods["loop"] then
      ui.hill_focus = x-1
      hills[ui.hill_focus].screen_focus = y
    elseif mods["playmode"] and z == 0 then
      hills[x-1][y].playmode = hills[x-1][y].playmode == "momentary" and "latch" or "momentary"
    elseif mods["copy"] and z == 1 then
      if not clipboard then
        print("copied...")
        clipboard = _t.deep_copy(hills[x-1][y])
        copied = {x-1,y}
      else
        print("pasted!")
        hills[x-1][y] = _t.deep_copy(clipboard)
        copied = nil
        clipboard = nil
      end
    end
  elseif x>=13 and y<=4 and z == 1 then
    local target = (x-12)+(4*(y-1))
    grid_lib.handle_grid_pat(target,mods.alt)
    grid_dirty = true
  end
  if mod_held and not mods["alt"] and not mods["copy"] then
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
          if mods["alt"] then
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
  if mod_held and not mods["playmode"] and not mods["alt"] and not mods["copy"] then
    g:led(14,8,dirs["L"] and 15 or 8)
    g:led(15,7,dirs["U"] and 15 or 8)
    g:led(15,8,dirs["D"] and 15 or 8)
    g:led(16,8,dirs["R"] and 15 or 8)
  end
  if mod_held and mods["copy"] then
    if not clipboard then
      for i = 12,14 do
        for j = 5,8 do
          if j == 5 or j == 8 then
            g:led(i,j,15)
          elseif (j == 6 or j == 7) and i == 12 then
            g:led(i,j,15)
          end
        end
      end
    elseif clipboard then
      for i = 12,14 do
        for j = 5,8 do
          if j == 5 or j == 7 then
            g:led(i,j,15)
          elseif j == 6 and (i == 12 or i == 14) then
            g:led(i,j,15)
          elseif j == 8 and i == 12 then
            g:led(i,j,15)
          end
        end
      end
    end
  end
  if mod_held and mods["playmode"] then

  end
  for i = 1,16 do
    local led_level
    if grid_pattern[i].count == 0 and grid_pattern[i].rec == 0 then
      led_level = 3
    elseif grid_pattern[i].rec == 1 then
      led_level = 10
    elseif grid_pattern[i].play == 1 then
      led_level = 15
    else
      led_level = 8
    end
    g:led(index_to_grid_pos(i,4)[1]+12,index_to_grid_pos(i,4)[2],led_level)
  end
  g:refresh()
end

function start_dir_clock(dir,n,d)
  if mods["hill"] and n == 3 then
    d = d * -1
  end
  _e.parse(n,d)
  held_dirs_clocks[dir] = clock.run(
    function()
      while true do
        clock.sleep(held_dirs_iters[dir] <= 5 and 0.15 or (held_dirs_iters[dir] <= 15 and 0.1 or (held_dirs_iters[dir] <= 30 and 0.05 or 0.01)))
        _e.parse(n,d)
        held_dirs_iters[dir] = held_dirs_iters[dir]+1
      end
    end
  )
  dirs[dir] = true
end

function stop_dir_clock(dir)
  if held_dirs_clocks[dir] then
    clock.cancel(held_dirs_clocks[dir])
    held_dirs_iters[dir] = 0
  end
  dirs[dir] = false
end

return grid_lib