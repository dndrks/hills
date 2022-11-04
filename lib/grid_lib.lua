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

iter_link_held = {0,0}
iter_link_source = {}
function iter_link(p_voice, p_hill, c_voice, c_hill)
  if hills[p_voice].iter_links[p_hill][c_voice] == c_hill then
    hills[p_voice].iter_links[p_hill][c_voice] = 0
  else
    hills[p_voice].iter_links[p_hill][c_voice] = c_hill
  end
end

function grid_lib.pattern_execute(data)
  if data.event == "start" then
    _a.start(data.x,data.y,true)
    active_voices[data.id][data.x] = true
    screen_dirty = true
    hills[data.x][data.y].perf_led = true
    grid_dirty = true
  elseif data.event == 'start with reset' then
    hills[data.x][data.y].index = hills[data.x][data.y].low_bound.note
    hills[data.x][data.y].step = hills[data.x][data.y].note_timestamp[hills[data.x][data.y].index] -- reset
    _a.start(data.x,data.y,true)
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
    local mod_idx = 0
    if params:string('pattern_'..(data.id)..'_snapshot_mod_restore') == 'yes' then
      mod_idx = data.mod_index
    end
    _snapshots.route_funnel(data.x,data.y,mod_idx)
    if data.x == 'delay' or data.x == 'reverb' or data.x == 'main' then
      snapshots[data.x].focus = data.y
    else
      hills[data.x].snapshot.focus = data.y
    end
  else
    if data.voice ~= nil then
      if params:string('voice_model_'..data.voice) == data.model then
        prms.send_to_engine(data.voice, data.param, data.value)
      end
    end
  end
end

grid_data_entry = false
data_entry_steps = {}
for i = 1,10 do
  data_entry_steps[i] = {}
end

grid_conditional_entry = false
conditional_entry_steps = {}
for i = 1,10 do
  conditional_entry_steps[i] = {}
end

grid_pattern = {}
grid_overdub_state = {}
overdubbing_pattern = false
toggles = {overdub = false, loop = false, duplicate = false, copy = false, link = false}
pattern_clipboard = {event = {}, time = {}, count = 0}
pattern_link_source = 0
pattern_links = {}
pattern_link_clocks = {}
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
  grid_pattern[i].start_callback = function()
    for j = 1,16 do
      if pattern_links[i][j] then
        if grid_pattern[j].rec == 0 and #grid_pattern[j].event > 0 then
          if grid_pattern[j].play == 1 then
            grid_pattern[j].step = 0
          else
            grid_pattern[j]:start()
          end
        end
      end
    end
  end
  pattern_links[i] = {}
  for j = 1,16 do
    pattern_links[i][j] = false
  end
end

function grid_lib.handle_grid_pat(i,alt)
  if not toggles.overdub and not toggles.loop and not toggles.duplicate and not toggles.copy and not toggles.link and not alt then
    if grid_pattern[i].rec == 1 then -- if we're recording...
      grid_pattern[i]:rec_stop() -- stop recording
      grid_pattern[i]:start() -- start playing
    elseif grid_pattern[i].count == 0 then -- otherwise, if there are no events recorded..
      if params:string('pattern_'..i..'_start_rec_at') == 'when engaged' then
        grid_pattern[i]:rec_start() -- start recording
        if not grid_pattern[i].event[1] then
          grid_pattern[i].event[1] = {}
        end
        grid_pattern[i].event[1][1] = {
          ['event'] = 'ignore'
        }
      else
        grid_pattern[i].rec = 1
      end
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
  elseif toggles.overdub then
    grid_pattern[i]:set_overdub(grid_pattern[i].overdub == 0 and 1 or 0)
  elseif toggles.duplicate then
    grid_pattern[i]:duplicate()
  elseif toggles.loop then
    grid_pattern[i].loop = grid_pattern[i].loop == 1 and 0 or 1
  elseif toggles.copy then
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
  elseif toggles.link then
  end
end

function grid_lib.stop_pattern_playback(i)
  grid_pattern[i]:stop() -- stop playing
  for j = 1,#active_voices[i] do
    if active_voices[i][j] then
      stop(j,true)
      _ca.stop_sample('sample'..params:get("hill "..j.." sample slot"))
      active_voices[i][j] = false
    end
  end

  for j = 1,16 do
    if pattern_links[i][j] then
      if grid_pattern[j].play == 1 then
        grid_lib.stop_pattern_playback(j)
      end
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

mods = {["hill"] = false,["bound"] = false,["notes"] = false,["loop"] = false,["playmode"] = false, ['playmode_extended'] = false, ["copy"] = false,["snapshots"] = false,["snapshots_extended"] = false,["alt"] = false}
local modkeys = {"hill","bound","notes","loop","playmode","copy","snapshots","alt"}

local function is_toggle_state_off()
  if not toggles.overdub and not toggles.loop and not toggles.duplicate and not toggles.copy and not toggles.link then
    return true
  else
    return false
  end
end

local function enable_toggle(target)
  local turn_off = false
  if toggles[target] then
    turn_off = true
  end
  for k,v in pairs(toggles) do
    toggles[k] = false
  end
  if not turn_off then
    toggles[target] = true
  end
end

function g.key(x,y,z)
  if x == 1 and not mods['hill'] then
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
    elseif (y == 5 or y == 6) and z == 1 then
      for i = 1,#modkeys do
        if i ~= y then
          mods[modkeys[i]] = false
        else
          mods[modkeys[y]] = not mods[modkeys[y]]
          mod_held = mods[modkeys[y]]
          if mods['playmode'] == false then
            mods['playmode_extended'] = false
          end
        end
      end
      -- if ui.control_set ~= "song" then
      --   ui.control_set = "play"
      -- end
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
              if mods['snapshots'] == false then
                mods['snapshots_extended'] = false
              end
            end
          end
        end
        -- if ui.control_set ~= "song" then
        --   ui.control_set = "play"
        -- end
        if not mods["copy"] and clipboard then
          clipboard = nil
          copied = nil
        end

      else

      end
    end
    if y == 8 then
      for i = 1,#modkeys do
        if i ~= y then
          if modkeys[i] ~= "snapshots"
          and modkeys[i] ~= "playmode"
          and modkeys[i] ~= "copy" then
            mods[modkeys[i]] = false
          end
        else
          mods[modkeys[y]] = z == 1 and true or false
          -- mods[modkeys[y]] = not mods[modkeys[y]]
          if not mods["snapshots"] and not mods['playmode'] and not mods['copy'] then
            mod_held = mods[modkeys[y]]
          end
        end
      end
      -- if ui.control_set ~= "song" then
      --   ui.control_set = "play"
      -- end
      if not mods["copy"] and clipboard then
        clipboard = nil
        copied = nil
      end
    end
    grid_dirty = true
    screen_dirty = true
  elseif x == 1 and mods['hill'] then
    if y == 1 and z == 1 then
      mods['hill'] = not mods['hill']
      if not mods['hill'] then
        mod_held = false
      end
    elseif y > 2 and y <= 6 then
      grid_lib.highway_press(x,y,z)
    end
  end
  if x > 1 and x <= number_of_hills+1 and not mod_held then
    if z == 1 then
      if hills[x-1].highway == false then
        _a.start(x-1,y,true)
      else
        _htracks.stop_playback(x-1)
        track[x-1].active_hill = y
        _htracks.start_playback(x-1)
        print('start and stop')
      end
      hills[x-1].screen_focus = y
      screen_dirty = true
      hills[x-1][y].perf_led = true
      grid_dirty = true
      for i = 1,16 do
        if grid_pattern[i].rec == 1 and grid_pattern[i].step == 0 then
          grid_pattern[i]:rec_start()
          if not grid_pattern[i].event[1] then
            grid_pattern[i].event[1] = {}
          end
          local current_count = #grid_pattern[i].event[1]
          grid_pattern[i].event[1][current_count+1] = {
            ["event"] = "start",
            ["x"] = x-1,
            ["y"] = y,
            ["id"] = i
          }
        else
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
    end
    if z == 0 then
      if hills[x-1][y].playmode == "momentary" and hills[x-1].segment == y then
        if hills[x-1].highway == false then
          stop(x-1,true)
        else
          _htracks.stop_playback(x-1)
        end
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
    if mods["alt"] and z == 1 and not mods.snapshots and not mods.playmode then
      if hills[x-1][y].playmode == 'latch' then
        stop(x-1,true)
      elseif params:string('hill '..(x-1)..' reset at stop') == 'no' then
        hills[x-1][y].index = hills[x-1][y].low_bound.note
        hills[x-1][y].step = hills[x-1][y].note_timestamp[hills[x-1][y].index] -- reset
        _a.start(x-1,y,true)
        hills[x-1].screen_focus = y
        screen_dirty = true
        hills[x-1][y].perf_led = true
        grid_dirty = true
        for i = 1,16 do
          if grid_pattern[i].rec == 1 and grid_pattern[i].step == 0 then
            grid_pattern[i]:rec_start()
            if not grid_pattern[i].event[1] then
              grid_pattern[i].event[1] = {}
            end
            local current_count = #grid_pattern[i].event[1]
            grid_pattern[i].event[1][current_count+1] = {
              ["event"] = "start with reset",
              ["x"] = x-1,
              ["y"] = y,
              ["id"] = i
            }
          else
            grid_pattern[i]:watch(
              {
                ["event"] = "start with reset",
                ["x"] = x-1,
                ["y"] = y,
                ["id"] = i
              }
            )
          end
        end
      end
    elseif mods["alt"] and z == 0 and not mods.snapshots and not mods.playmode then
      stop(x-1,true)
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
    elseif mods["bound"] or mods["notes"] or mods["loop"] then
      ui.hill_focus = x-1
      hills[ui.hill_focus].screen_focus = y
    elseif mods['hill'] then
      grid_lib.highway_press(x,y,z)
    elseif mods["playmode"] and z == 1 then
      if mods['playmode_extended'] then
        if #iter_link_source == 0 then
          iter_link_source[1] = x-1
          iter_link_source[2] = y
          iter_link_held[1] = x-1
          iter_link_held[2] = y
        else
          iter_link(iter_link_source[1],iter_link_source[2],x-1,y)
        end
      else
        if mods['alt'] then
          hills[x-1][y].playmode = hills[x-1][y].playmode == "momentary" and "latch" or "momentary"
        else
          hills[x-1][y].mute = not hills[x-1][y].mute
        end
      end
    elseif mods['playmode'] and z == 0 then
      if mods['playmode_extended'] then
        if x-1 == iter_link_held[1] then
          iter_link_held = {0,0}
        end
        if #iter_link_source ~= 0 and iter_link_held[1] == 0 then
          iter_link_source = {}
        end
      end
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
    elseif not snapshot_overwrite_mod then
      if (mods["snapshots"] and not mods['snapshots_extended']) or (mods['snapshots'] and mods['snapshots_extended']) then
        local fx = {'delay','reverb','main'}
        local which_focus = (mods["snapshots"] and not mods['snapshots_extended']) and 'snapshots' or 'snapshots_extended'
        x = x - 1
        
        local _snap;
        if x <= 7 and which_focus ~= 'snapshots_extended' then
          local d_voice = params:string('voice_model_'..x)
          _snap = snapshots[x][d_voice]
        elseif x <= 10 and which_focus ~= 'snapshots_extended' then
          local d_voice = 'sample'..x-7
          _snap = snapshots[x][d_voice]
        elseif which_focus == 'snapshots_extended' then
          _snap = snapshots[fx[x]]
        end

        local x = which_focus == 'snapshots_extended' and fx[x] or x
        local which_type = which_focus == 'snapshots' and hills[x].snapshot or snapshots[x]
        
        if z == 1 then
          if tab.count(_snap[y]) == 0 then
            which_type.saver_clock = clock.run(_snapshots.save_to_slot,x,y)
            which_type.focus = y
          elseif not mods.alt then
            _snapshots.route_funnel(x,y,snapshots.mod.index)
            which_type.focus = y
          else
            which_type.saver_clock = clock.run(_snapshots.save_to_slot,x,y)
          end
        else
          if which_type.saver_clock ~= nil then
            clock.cancel(which_type.saver_clock)
          end
        end
        if z == 1 and tab.count(_snap[y]) > 0 then
          for i = 1,16 do
            if grid_pattern[i].rec == 1 and grid_pattern[i].step == 0 then
              grid_pattern[i]:rec_start()
              if not grid_pattern[i].event[1] then
                grid_pattern[i].event[1] = {}
              end
              grid_pattern[i].event[1][1] = {
                ["event"] = "snapshot_restore",
                ["x"] = x,
                ["y"] = y,
                ["id"] = i,
                ['mod_index'] = snapshots.mod.index
              }
            else
              grid_pattern[i]:watch(
                {
                  ["event"] = "snapshot_restore",
                  ["x"] = x,
                  ["y"] = y,
                  ["id"] = i,
                  ['mod_index'] = snapshots.mod.index
                }
              )
            end
          end
        end
      end
    elseif snapshot_overwrite_mod then
      local fx = {'delay','reverb','main'}
      local which_focus = (mods["snapshots"] and not mods['snapshots_extended']) and 'snapshots' or 'snapshots_extended'
      x = x - 1
      local _snap, _snapover;
      if  x <= 7 and which_focus ~= 'snapshots_extended' then
        local d_voice = params:string('voice_model_'..x)
        _snap = snapshots[x][d_voice]
        _snapover = snapshot_overwrite[x][d_voice]
      elseif x <= 10 and which_focus ~= 'snapshots_extended' then
        local d_voice = 'sample'..x-7
        _snap = snapshots[x][d_voice]
        _snapover = snapshot_overwrite[x][d_voice]
      elseif which_focus == 'snapshots_extended' then
        _snap = snapshots[fx[x]]
        _snapover = snapshot_overwrite[fx[x]]
      end
      if z == 1 then
        if tab.count(_snap[y]) ~= 0 then
          _snapover[y] = not _snapover[y]
        end
      end
    end
  elseif x>=13 and y<=4 then
    local target = (x-12)+(4*(y-1))
    if grid_pattern[target].count == 0 then
      if z == 0 then
        grid_lib.handle_grid_pat(target,mods.alt)
      end
    else
      if z == 1 then
        grid_lib.handle_grid_pat(target,mods.alt)
      end
    end
    if z == 1 and toggles.link then
      if pattern_link_source == 0 then
        pattern_link_source = target
      else
        if params:string('pattern_'..pattern_link_source..'_link_'..target) == 'no' then
          params:set('pattern_'..pattern_link_source..'_link_'..target,2)
        else
          params:set('pattern_'..pattern_link_source..'_link_'..target,1)
        end
      end
    elseif z == 0 and toggles.link then
      if pattern_link_source == target then
        pattern_link_source = 0
      end
    end

  elseif x == 12 and y == 5 and z == 1 then
    enable_toggle('overdub')
  elseif x == 12 and y == 6 and z == 1 then
    enable_toggle('loop')
  elseif x == 12 and y == 7 and z == 1 then
    enable_toggle('duplicate')
  elseif x == 12 and y == 8 and z == 1 then
    enable_toggle('copy')
  elseif x == 13 and y == 8 and z == 1 then
    enable_toggle('link')
    pattern_link_source = 0
  elseif x == 12 and y == 2 and z == 1 and (mods["snapshots"] or mods["snapshots_extended"]) then
    snapshot_overwrite_mod = not snapshot_overwrite_mod
  elseif x == 12 and y == 1 and z == 1 and mods['snapshots'] then
    mods["snapshots_extended"] = not mods["snapshots_extended"]
  elseif x == 16 and y == 8 and z == 1 and mods['playmode'] then
    mods['playmode_extended'] = not mods['playmode_extended']
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
  elseif mod_held and mods["snapshots"] and is_toggle_state_off() then
    if x >= 15 then
      if z == 1 then
        if y == 6 then
          snapshots.mod.index = x - 14
        elseif y == 7 then
          snapshots.mod.index = (x + 2) - 14
        elseif y == 8 then
          snapshots.mod.index = (x + 4) - 14
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

function grid_lib.highway_press(x,y,z)
  -- change voice focus:
  if y == 1 and z == 1 and x <= 11 then
    ui.hill_focus = x-1
  -- change pattern focus:
  elseif y == 2 and z == 1 and (x > 1 and x <= 9) then
    hills[ui.hill_focus].screen_focus = x-1
  -- enter steps
  elseif y <= 6 and z == 1 and (x >= 1 and x <= 8) then
    local i = ui.hill_focus
    local j = hills[ui.hill_focus].screen_focus
    local min_max = {{1,32},{33,64},{65,96},{97,128}}
    local pos = ((y - 3) * 8) + x
    local pressed_step = pos + ((highway_ui.seq_page[i] - 1) * 32)
    if not grid_data_entry and not grid_conditional_entry then
      track[i][j].ui_position = pressed_step
      track[i][j].trigs[pressed_step] = not track[i][j].trigs[pressed_step]
    elseif grid_data_entry then
      if not tab.contains(data_entry_steps[i], pressed_step) then
        track[i][j].ui_position = pressed_step
        data_entry_steps[i][#data_entry_steps[i]+1] = pressed_step
        _fkprm.voice_focus = i
        _fkprm.hill_focus = j
        _fkprm.step_focus = pressed_step
      else
        table.remove(data_entry_steps[i],tab.key(data_entry_steps[i],pressed_step))
      end
    elseif grid_conditional_entry then
      if not tab.contains(conditional_entry_steps[i], pressed_step) then
        track[i][j].ui_position = pressed_step
        conditional_entry_steps[i][#conditional_entry_steps[i]+1] = pressed_step
        _fkprm.voice_focus = i
        _fkprm.hill_focus = j
        _fkprm.step_focus = pressed_step
      else
        table.remove(conditional_entry_steps[i],tab.key(conditional_entry_steps[i],pressed_step))
      end
    end
  -- grid lock mode:
  elseif y == 8 and x == 8 and z == 1 then
    grid_data_entry = not grid_data_entry
    if not grid_data_entry then
      data_entry_steps[ui.hill_focus] = {}
      _fkprm.flip_from_fkprm()
    else
      _fkprm.flip_to_fkprm(ui.control_set,true)
    end
  elseif y == 8 and x == 2 and z == 1 then
    grid_conditional_entry = not grid_conditional_entry
    if not grid_conditional_entry then
      conditional_entry_steps[ui.hill_focus] = {}
      -- _fkprm.flip_from_fkprm()
    else
      -- _fkprm.flip_to_fkprm(ui.control_set,true)
    end
  end
end

function grid_redraw()
  g:all(0)
  for i = 1,8 do
    g:led(1,i,mods[modkeys[i]] and 15 or 0)
  end
  for i = 1+1,number_of_hills+1 do
    for j = 1,8 do
      if mod_held then
        if not mods["playmode"] and not mods["copy"] and not mods["snapshots"]
        and not mods['hill'] then
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
          if mods['playmode_extended'] then
            if iter_link_held[1] == i-1 then
              g:led(i,iter_link_held[2],15)
              for k = 1,#hills[iter_link_held[1]].iter_links[iter_link_held[2]] do
                if hills[iter_link_held[1]].iter_links[iter_link_held[2]][k] ~= 0 then
                  g:led(k+1,hills[iter_link_held[1]].iter_links[iter_link_held[2]][k],10)
                end
              end
            elseif iter_link_held[1] == 0 then
              for k = 1,#hills[i-1].iter_links[j] do
                if hills[i-1].iter_links[j][k] ~= 0 then
                  g:led(i,j,6)
                  break
                end
              end
            end
          else
            if mods['alt'] then
              if hills[i-1][j].playmode == "momentary" then
                display_level = 4
              else
                display_level = 15
              end
            else
              display_level = hills[i-1][j].mute and 2 or 10
            end
            g:led(i,j,display_level)
          end
        elseif mods['hill'] then
          if not hills[i-1].highway then
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
            end
          else
            grid_lib.draw_highway(i-1)
          end
        elseif snapshot_overwrite_mod then

          if mods["snapshots"] then
            local display_level;
            local fx = {'delay','reverb','main'}
            local extension_limit = mods['snapshots_extended'] and 4 or number_of_hills+1
            local _snap, _snapover;

            if i-1 <= 7 then
              local d_voice = params:string('voice_model_'..i-1)
              _snap = snapshots[i-1][d_voice]
              _snapover = snapshot_overwrite[i-1][d_voice]
            elseif i - 1 <= 10 then
              local d_voice = 'sample'..(i-8)
              _snap = snapshots[i-1][d_voice]
              _snapover = snapshot_overwrite[i-1][d_voice]
            else
              print('else2?')
              _snap = snapshots[i-1]
              _snapover = snapshot_overwrite[i-1]
            end
            if i-1 < extension_limit then
              if mods['snapshots_extended'] and snapshot_overwrite[fx[i-1]][j] or _snapover[j] then
                display_level = 15
              else
                if tab.count(mods['snapshots_extended'] and snapshots[fx[i-1]][j] or _snap[j]) ~= 0 then
                  if (mods['snapshots_extended'] and snapshots[fx[i-1]].focus or hills[i-1].snapshot.focus) == j then
                    display_level = 8
                  else
                    display_level = 5
                  end
                else
                  display_level = 1
                end
              end
              g:led(i,j,display_level)
            end
          end

        elseif not snapshot_overwrite_mod then
          if mods["snapshots"] then
            local display_level;
            local fx = {'delay','reverb','main'}
            local extension_limit = mods['snapshots_extended'] and 4 or number_of_hills+1
            if i-1 < extension_limit then
              local _snap,d_voice;
              if i-1 <= 7 then
                d_voice = params:string('voice_model_'..i-1)
                _snap = snapshots[i-1][d_voice]
              elseif i-1 <= 10 then
                d_voice = 'sample'..(i-8)
                _snap = snapshots[i-1][d_voice]
              else
                print('else?')
                _snap = snapshots[i-1]
              end
              if tab.count(mods['snapshots_extended'] and snapshots[fx[i-1]][j] or _snap[j]) == 0 then
                display_level = 3
              else
                if (mods['snapshots_extended'] and snapshots[fx[i-1]].focus or hills[i-1].snapshot.focus) == j then
                  display_level = 12
                else
                  display_level = 6
                end
              end
              g:led(i,j,display_level)
            end
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
  if mod_held and not mods["playmode"] and not mods["alt"] and not mods["copy"] and not mods["snapshots"] then
    g:led(14,8,dirs["L"] and 15 or 8)
    g:led(15,7,dirs["U"] and 15 or 8)
    g:led(15,8,dirs["D"] and 15 or 8)
    g:led(16,8,dirs["R"] and 15 or 8)
  elseif mod_held and mods["snapshots"] and is_toggle_state_off() then
    for i = 15,16 do
      g:led(i,6,snapshots.mod.index == (i - 14) and 15 or 6)
      g:led(i,7,snapshots.mod.index == (i - 12) and 15 or 6)
      g:led(i,8,snapshots.mod.index == (i - 10) and 15 or 6)
    end
  end
  
  g:led(12,5,toggles.overdub and 15 or 6)
  g:led(12,6,toggles.loop and 15 or 6)
  g:led(12,7,toggles.duplicate and 15 or 6)
  g:led(12,8,toggles.copy and 15 or 6)
  g:led(13,8,toggles.link and 15 or 6)

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

  if toggles.copy then
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
  elseif toggles.duplicate then
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
  elseif toggles.overdub then
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
  elseif toggles.loop then
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
  elseif toggles.link then
    g:led(14,5,15)
    g:led(16,6,15)
    g:led(14,7,15)
    g:led(16,8,15)
  end

  if mods['playmode'] then
    g:led(16,8,mods['playmode_extended'] and 15 or 4)
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
    if toggles.loop then
      led_level = grid_pattern[i].loop == 1 and 12 or 3
    elseif toggles.link and pattern_link_source > 0 then
      led_level = pattern_links[pattern_link_source][i] and 12 or 3
    end
    g:led(index_to_grid_pos(i,4)[1]+12,index_to_grid_pos(i,4)[2],led_level)
  end

  -- g:led(index_to_grid_pos(pattern_link_source,4)[1]+12,index_to_grid_pos(pattern_link_source,4)[2],15)

  if mods['snapshots'] or mods['snapshots_extended'] then
    g:led(12,1,mods['snapshots_extended'] and 15 or 6)
    g:led(12,2,snapshot_overwrite_mod and 15 or 6)
  end
  
  g:refresh()
end

function grid_lib.draw_highway(i)
  local focused = hills[i].screen_focus
  local _active = track[i][focused]
  local focused_set = _active.focus == 'main' and _active or _active.fill
  local _hui = highway_ui
  local epos = _active.ui_position
  
  -- draw top row hill selector
  g:led(i+1,1,i == ui.hill_focus and 15 or 4)

  -- draw steps + sequence selector
  if ui.hill_focus == i then
    local min_max = {{1,32},{33,64},{65,96},{97,128}}
    local lvl = 5
    local flipped_entry_steps = tab.invert(grid_data_entry and data_entry_steps[i] or conditional_entry_steps[i])
    for display_range = min_max[_hui.seq_page[focused]][1], min_max[_hui.seq_page[focused]][2] do
      if display_range <= _active.end_point and display_range >= _active.start_point then
        if _active.step == display_range and track[i].active_hill == focused then
          lvl = 10
        else
          lvl = 5
        end
      else
        lvl = 2
      end
      if grid_data_entry or grid_conditional_entry then
        if flipped_entry_steps[display_range] ~= nil then
          lvl = 15
        else
          if _active.trigs[display_range] then
            lvl = 5
          else
            if _active.step == display_range and _active.playing then
              lvl = 0
            else
              lvl = 2
            end
          end
        end
      else
        if _active.trigs[display_range] then
          if _active.step == display_range and _active.playing then
            lvl = 0
          else
            lvl = 15
          end
        end
      end
      g:led(_hsteps.index_to_grid_pos(display_range,8)[1], _hsteps.index_to_grid_pos(display_range,8)[2]+2,lvl)
    end
    for j = 1,8 do
      g:led(j+1, 2, focused == j and 15 or 4)
      if track[i].active_hill == j and track[i].active_hill ~= focused then
        g:led(j+1, 2, 10)
      end
    end
  end

  -- draw grid_lock:
  g:led(8,8,grid_data_entry and 15 or 5)
  g:led(2,8,grid_conditional_entry and 15 or 5)

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
        screen_dirty = true
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