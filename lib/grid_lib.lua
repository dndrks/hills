local grid_lib = {}
local grid = util.file_exists(_path.code.."midigrid") and include "midigrid/lib/midigrid" or grid

g = grid.connect()

local dirs = {["L"] = false,["R"] = false,["U"] = false,["D"] = false}
held_dirs_clocks = {["L"] = nil,["R"] = nil,["U"] = nil,["D"] = nil}
held_dirs_iters = {["L"] = 0,["R"] = 0,["U"] = 0,["D"] = 0}

active_voices = {}
for i = 1,16 do
  active_voices[i] = {}
  for j = 1,number_of_hills do
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
    if params:string("hill "..data.x.." sample momentary") == "yes" then
      _ca.stop_sample('sample'..params:get("hill "..data.x.." sample slot"))
    end
    grid_dirty = true
  elseif data.event == "snapshot_restore" then
    _snapshots.route_funnel(data.x,data.y,snapshots.mod.index,"time")
    if data.x == 'delay' or data.x == 'reverb' or data.x == 'main' then
      snapshots[data.x].focus = data.y
    else
      hills[data.x].snapshot.focus = data.y
    end
  end
end

grid_pattern = {}
grid_overdub_state = {}
overdubbing_pattern = false
overdub_toggle = false
duplicate_toggle = false
copy_toggle = false
pattern_clipboard = {event = {}, time = {}, count = 0}

for i = 1,16 do
  grid_pattern[i] = pt.new(i)
  grid_pattern[i].process = grid_lib.pattern_execute
  grid_overdub_state[i] = false
  grid_pattern[i].overdub_action =
    function(id,state)
      grid_overdub_state[id] = state
      overdubbing_pattern = false
      for j = 1,16 do
        if grid_pattern[j].overdub == 1 then
          overdubbing_pattern = true
          break
        end
      end
    end
end

function grid_lib.handle_grid_pat(i,alt)
  if not overdub_toggle and not loop_toggle and not duplicate_toggle and not copy_toggle and not alt then
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
  elseif alt then
    grid_pattern[i]:rec_stop() -- stops recording
    grid_pattern[i]:stop() -- stops playback
    for j = 1,#active_voices[i] do
      if active_voices[i][j] then
        stop(j,true)
        active_voices[i][j] = false
      end
    end
    grid_pattern[i]:clear() -- clears the pattern
  elseif overdub_toggle then
    grid_pattern[i]:set_overdub(grid_pattern[i].overdub == 0 and 1 or 0)
  elseif duplicate_toggle then
    grid_pattern[i]:duplicate()
  elseif loop_toggle then
    grid_pattern[i].loop = grid_pattern[i].loop == 1 and 0 or 1
  elseif copy_toggle then
    if #pattern_clipboard.event == 0 and grid_pattern[i].count > 0 then
      pattern_clipboard.event = grid_pattern[i].deep_copy(grid_pattern[i].event)
      pattern_clipboard.time = grid_pattern[i].deep_copy(grid_pattern[i].time)
      pattern_clipboard.count = grid_pattern[i].count
    elseif #pattern_clipboard.event > 0 then
      grid_pattern[i].event = grid_pattern[i].deep_copy(pattern_clipboard.event)
      grid_pattern[i].time = grid_pattern[i].deep_copy(pattern_clipboard.time)
      grid_pattern[i].count = pattern_clipboard.count
      for events = 1,grid_pattern[i].count do
        grid_pattern[i].event[events].id = i
      end
      pattern_clipboard.event = {}
      pattern_clipboard.time = {}
      pattern_clipboard.count = 0
    end
  end
end

function grid_lib.stop_pattern_playback(i)
  grid_pattern[i]:stop() -- stop playing
  for j = 1,#active_voices[i] do
    if active_voices[i][j] then
      stop(j,true)
      _ca.stop_sample('sample'..params:get("hill "..i.." sample slot"))
      active_voices[i][j] = false
    end
  end
  grid_dirty = true
end

function grid_lib.init()
  clock.run(function()
    while true do
      clock.sleep(1/30)
      if grid_dirty or overdubbing_pattern then
        grid_redraw()
        grid_dirty = false
        for i = 1,number_of_hills do
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

mods = {["hill"] = false,["bound"] = false,["notes"] = false,["loop"] = false,["playmode"] = false,["copy"] = false,["snapshots"] = false,["snapshots_extended"] = false,["alt"] = false}
local modkeys = {"hill","bound","notes","loop","playmode","copy","snapshots","alt"}

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
    elseif y == 5 or y == 6 then
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
    elseif y == 7 and z == 1 then
      if not mods['alt'] then
        for i = 1,#modkeys do
          if i ~= y then
            if modkeys[i] ~= "alt" then
              mods[modkeys[i]] = false
            end
          else
            mods[modkeys[y]] = not mods[modkeys[y]]
            if not mods["alt"] then
              mod_held = mods[modkeys[y]]
            end
          end
        end
        if ui.control_set ~= "song" then
          ui.control_set = "play"
        end
        if not mods["copy"] and clipboard then
          clipboard = nil
          copied = nil
        end
        if not mods['snapshots'] then
          mods['snapshots_extended'] = false
        end
      else
        mods["snapshots_extended"] = not mods["snapshots_extended"]
        if mods['snapshots_extended'] and not mods['snapshots'] then
          mods['snapshots'] = true
        end
      end
    end
    if y == 8 then
      for i = 1,#modkeys do
        if i ~= y then
          if modkeys[i] ~= "snapshots" then
            mods[modkeys[i]] = false
          end
        else
          mods[modkeys[y]] = not mods[modkeys[y]]
          if not mods["snapshots"] then
            mod_held = mods[modkeys[y]]
          end
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
  if x > 1 and x <= number_of_hills+1 and not mod_held then
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
      if params:string("hill "..(x-1).." sample momentary") == "yes" then
        _ca.stop_sample('sample'..params:get("hill "..(x-1).." sample slot"))
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
  elseif x > 1 and x <= number_of_hills+1 and mod_held then
    if mods["alt"] and z == 1 and not mods.snapshots then
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
    elseif mods["snapshots"] and not mods['snapshots_extended'] then
      x = x - 1
      if z == 1 then
        if tab.count(snapshots[x][y]) == 0 then
          hills[x].snapshot.saver_clock = clock.run(_snapshots.save_to_slot,x,y)
          hills[x].snapshot.focus = y
        elseif not mods.alt then
          _snapshots.route_funnel(x,y,snapshots.mod.index,"time")
          hills[x].snapshot.focus = y
        else
          hills[x].snapshot.saver_clock = clock.run(_snapshots.save_to_slot,x,y)
        end
      else
        if hills[x].snapshot.saver_clock ~= nil then
          clock.cancel(hills[x].snapshot.saver_clock)
        end
      end
      if z == 1 and tab.count(snapshots[x][y]) > 0 then
        for i = 1,16 do
          grid_pattern[i]:watch(
            {
              ["event"] = "snapshot_restore",
              ["x"] = x,
              ["y"] = y,
              ["id"] = i
            }
          )
        end
      end
    elseif mods['snapshots_extended'] then
      local fx = {'delay','reverb','main'}
      x = x - 1
      local x = fx[x]
      if z == 1 then
        if tab.count(snapshots[x][y]) == 0 then
          snapshots[x].saver_clock = clock.run(_snapshots.save_to_slot,x,y)
          snapshots[x].focus = y
        elseif not mods.alt then
          _snapshots.route_funnel(x,y,snapshots.mod.index,"time")
          snapshots[x].focus = y
        else
          snapshots[x].saver_clock = clock.run(_snapshots.save_to_slot,x,y)
        end
      else
        if snapshots[x].saver_clock ~= nil then
          clock.cancel(snapshots[x].saver_clock)
        end
      end
      if z == 1 and tab.count(snapshots[x][y]) > 0 then
        for i = 1,16 do
          grid_pattern[i]:watch(
            {
              ["event"] = "snapshot_restore",
              ["x"] = x,
              ["y"] = y,
              ["id"] = i
            }
          )
        end
      end
    end
  elseif x>=13 and y<=4 and z == 1 then
    local target = (x-12)+(4*(y-1))
    grid_lib.handle_grid_pat(target,mods.alt)
  elseif x == 12 and y == 5 then
    overdub_toggle = z == 1 and true or false
  elseif x == 12 and y == 6 then
    loop_toggle = z == 1 and true or false
  elseif x == 12 and y == 7 then
    duplicate_toggle = z == 1 and true or false
  elseif x == 12 and y == 8 then
    copy_toggle = z == 1 and true or false
  end
  if mod_held and not mods["alt"] and not mods["copy"] and not mods["snapshots"] then
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
  elseif mod_held and (mods["snapshots"] or mods['snapshots_extended']) then
    if x >=14 then
      if z == 1 then
        if y == 7 then
          snapshots.mod.index = x - 13
        elseif y == 8 then
          snapshots.mod.index = (x+3) - 13
        end
      else
        snapshots.mod.index = 0
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
  for i = 1+1,number_of_hills+1 do
    for j = 1,8 do
      if mod_held then
        if not mods["playmode"] and not mods["copy"] and not mods["snapshots"] then
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
        elseif mods["copy"] then
          if hills[i-1].segment == j then
            g:led(i,j,10)
          end
          if copied ~= nil then
            if copied[1] == i-1 and copied[2] == j then
              g:led(i,j,15)
            end
          end
        elseif mods["playmode"] then
          local display_level;
          if hills[i-1][j].playmode == "momentary" then
            display_level = 4
          else
            display_level = 15
          end
          g:led(i,j,display_level)
        elseif mods["snapshots"] and not mods['snapshots_extended'] then
          local display_level;
          if i-1 < number_of_hills+1 then
            if tab.count(snapshots[i-1][j]) == 0 then
              display_level = 3
            else
              if hills[i-1].snapshot.focus == j then
                display_level = 12
              else
                display_level = 6
              end
            end
            g:led(i,j,display_level)
          end
        elseif mods['snapshots_extended'] then
          local display_level;
          local fx = {'delay','reverb','main'}
          if i-1 < 4 then
            if tab.count(snapshots[fx[i-1]][j]) == 0 then
              display_level = 3
            else
              if snapshots[fx[i-1]].focus == j then
                display_level = 12
              else
                display_level = 6
              end
            end
            g:led(i,j,display_level)
          end
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
  if mod_held and not mods["playmode"] and not mods["alt"] and not mods["copy"] and not mods["snapshots"] then
    g:led(14,8,dirs["L"] and 15 or 8)
    g:led(15,7,dirs["U"] and 15 or 8)
    g:led(15,8,dirs["D"] and 15 or 8)
    g:led(16,8,dirs["R"] and 15 or 8)
  elseif mod_held and mods["snapshots"] then
    for i = 14,16 do
      g:led(i,7,snapshots.mod.index == (i - 13) and 15 or 6)
      g:led(i,8,snapshots.mod.index == ((i+3) - 13) and 15 or 6)
    end
  end
  
  g:led(12,5,overdub_toggle and 15 or 6)
  g:led(12,6,loop_toggle and 15 or 6)
  g:led(12,7,duplicate_toggle and 15 or 6)
  g:led(12,8,copy_toggle and 15 or 6)

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

  if copy_toggle then
    if #pattern_clipboard.event == 0 then
      for i = 14,16 do
        for j = 5,8 do
          if j == 5 or j == 8 then
            g:led(i,j,15)
          elseif (j == 6 or j == 7) and i == 14 then
            g:led(i,j,15)
          end
        end
      end
    elseif #pattern_clipboard.event > 0 then
      for i = 14,16 do
        for j = 5,8 do
          if j == 5 or j == 7 then
            g:led(i,j,15)
          elseif j == 6 and (i == 14 or i == 16) then
            g:led(i,j,15)
          elseif j == 8 and i == 14 then
            g:led(i,j,15)
          end
        end
      end
    end
  elseif duplicate_toggle then
    for i = 14,16 do
      for j = 5,8 do
        if (j == 5 and (i == 14 or i == 15)) or (j == 8 and (i == 14 or i == 15)) then
          g:led(i,j,15)
        elseif (j == 6 or j == 7) then
          if i == 14 or i == 16 then
            g:led(i,j,15)
          end
        end
      end
    end
  elseif overdub_toggle then
    for i = 14,16 do
      for j = 5,8 do
        if j == 5 or j == 8 then
          g:led(i,j,15)
        elseif (j == 6 or j == 7) then
          if i == 14 or i == 16 then
            g:led(i,j,15)
          end
        end
      end
    end
  elseif loop_toggle then
    for i = 14,16 do
      for j = 5,8 do
        if j == 8 then
          g:led(i,j,15)
        else
          if i == 14 then
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
    elseif grid_pattern[i].play == 1 and grid_pattern[i].overdub == 0 then
      led_level = 15
    else
      if grid_pattern[i].overdub == 1 then
        -- led_level = 15 - (util.round(clock.get_beats() % 4)*3)
        led_level = 15 - util.round((util.round(clock.get_beats() % 4,0.5) * 3))
      else
        led_level = 8
      end
    end
    if loop_toggle then
      led_level = grid_pattern[i].loop == 1 and 12 or 3
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