local grid_lib = {}

function gridInit()
  ui_hill_focus = 1

  toggles = {overdub = false, loop = false, duplicate = false, copy = false, link = false}

  grid_data_blink = 0
  grid_loop_point_blink = 0
  grid_dirty = true
  grid_lib_redraw = clock.run(function()
    while true do
      clock.sleep(1/30)
      grid_data_blink = util.wrap(grid_data_blink + 1,1,15)
      grid_loop_point_blink = util.wrap(grid_loop_point_blink + 3,1,15)
      if grid_dirty or overdubbing_pattern then
        grid_redraw()
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

  pattern_links = {}
  grid_pattern = {}
  grid_overdub_state = {}
  active_voices = {}

  es = {}
  patterned_es = {}
  for i = 1,number_of_hills do
    es[i] = {x = {}, y = {}, legato = false}
    patterned_es[i] = {x = {}, y = {}}
  end

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
      active_voices[j] = {}
      for k = 1,number_of_hills do
        active_voices[i][k] = false
      end
    end
  end

end

function index_to_grid_pos(val,columns)
  local x = math.fmod(val-1,columns)+1
  local y = math.modf((val-1)/columns)+1
  return {x,y}
end

function grid_redraw()
  grid_dirty = false
  g:all(0)
  for i = 1+1,number_of_hills+1 do
    _i = i-1
    for j = 1,8 do
      if not hills[_i].highway and hills[_i].segment == j then
        g:led(i,j,hills[_i][j].perf_led and 15 or (hills[_i][j].iterated and 6 or 8))
      elseif hills[_i].highway and track[_i].active_hill == j then
        g:led(i,j,track[_i][j].playing and 15 or 10)
      else
        if hills[_i].highway then
          g:led(i,j,#track[_i] >= j and 6 or 0)
        else
          g:led(i,j,0)
        end
      end
    end
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

  -- ES:
  local i = ui_hill_focus
  for x = 2,8 do
    if x-1 == i then
      g:led(x,9,15)
    else
      g:led(x,9,5)
    end
  end
  for x = 2,6 do
    for y =10,14 do
      if es[i].x == x and es[i].y == y-7 then
        g:led(x,y,15)
      elseif patterned_es[i].x == x and patterned_es[i].y == y-7 then
        g:led(x,y,12)
      else
        g:led(x,y,2)
        if params:string('hill_'..i..'_iso_quantize') == 'no' then
          local note_index = ((((7-(y-7))*5) + (x-1)-1))%12 -- 0-base
          if hills[i].note_intervals[note_index] ~= nil then
            g:led(x,y,8)
          end
        else
          local note_index = ((((7-(y-7))*5) + (x-1)))
          if hills[i].note_ocean[note_index] % 12 == 0 then
            g:led(x,y,8)
          end
        end
      end
    end
  end
  g:led(2,15,util.round(util.linlin(-4,0,15,4,params:get('hill_'..i..'_iso_octave'))))
  g:led(3,15,util.round(util.linlin(0,4,4,15,params:get('hill_'..i..'_iso_octave'))))

  g:led(1,16,mods.alt and 15 or 5)
  g:refresh()
end

function grid_lib.key(x,y,z)
  if x > 1 and x <= number_of_hills+1 and y <= 8 then
    if z == 1 then
      _a.start(x-1,y,true)
      hills[x-1].screen_focus = y
      hills[x-1][y].perf_led = true
      for i = 1,16 do
        local table_to_record =
        {
          ["event"] = "start",
          ["x"] = x-1,
          ["y"] = y,
          ["id"] = i
        }
        write_pattern_data(i,table_to_record,true)
      end
    elseif z == 0 then
      if hills[x-1].segment == y then
        stop(x-1,true)
      end
      hills[x-1][y].perf_led = false
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
  elseif x == 1 and y == 16 then
    mods.alt = z == 1
  elseif y > 8 then
    grid_lib.earthsea_press(x,y,z)
  end
  grid_dirty = true
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
    grid_dirty = true
  elseif data.event == "snapshot_restore" then
    local mod_idx = 0
    if params:string('pattern_'..(data.id)..'_snapshot_mod_restore') == 'yes' then
      mod_idx = data.mod_index
    end
    _snapshots.route_funnel(data.x,data.y,mod_idx)
    if data.x == 'delay' or data.x == 'feedback' or data.x == 'main' then
      snapshots[data.x].focus = data.y
    else
      hills[data.x].snapshot.focus = data.y
    end
  elseif data.event == "es" then
    -- print("dan, you haven't made room for this yet")
    local i = data.hill_i
    local j = data.hill_j
    local played_index = (((7-data.y)*5) + (data.x-1)-1)
    if params:string('hill_'..i..'_iso_quantize') == 'yes' then
      force_note(i,j,hills[i].note_ocean[played_index+1] + (12 * data.octave))
    else
      force_note(i,j,(params:get('hill '..i..' base note') + played_index) + (12 * data.octave))
    end
    patterned_es[i].x = data.x
    patterned_es[i].y = data.y
  elseif data.event == "trig_flip" then
    local i = data.hill_i
    local j = data.hill_j
    local _page = data.hill_page
    local focused_set = data.track_focus == "main" and track[i][j][_page] or track[i][j][_page].fill
    _htracks.change_trig_state(focused_set,data.step,data.state, i, j, _page)
  elseif data.event == "midi_trig" then
    if data.legato then
      params:set('hill_'..data.hill..'_legato', 1)
    else
      params:set('hill_'..data.hill..'_legato', 0)
    end
    if hills[data.hill].highway then
      _htracks.tick(data.hill)
    else
      local j = data.hill
      local k = data.segment
      if hills[j][k].note_num.pool[hills[j][k].index] ~= nil then
        pass_note(j,k,hills[j][k],hills[j][k].note_num.pool[hills[j][k].index],hills[j][k].index,0)
      end
      hills[j][k].index = util.wrap(hills[j][k].index + 1, hills[j][k].low_bound.note,hills[j][k].high_bound.note)
    end
  else
    if data.voice ~= nil then
      if params:string('voice_model_'..data.voice) == data.model then
        prms.send_to_engine(data.voice, data.param, data.value)
      end
    end
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

  for j = 1,16 do
    if pattern_links[i][j] then
      if grid_pattern[j].play == 1 then
        grid_lib.stop_pattern_playback(j)
      end
    end
  end

  grid_dirty = true
end

function write_pattern_data(i,data_table,from_current)
  if grid_pattern[i].rec == 1 and grid_pattern[i].step == 0 then
    grid_pattern[i]:rec_start()
    if not grid_pattern[i].event[1] then
      grid_pattern[i].event[1] = {}
    end
    local current_count = 1
    if from_current then
      current_count = #grid_pattern[i].event[1] + 1
    end
    grid_pattern[i].event[1][current_count] = data_table
    grid_pattern[i].count = 1
  else
    grid_pattern[i]:watch(data_table)
  end
end

function grid_lib.earthsea_press(x,y,z)
  -- change voice focus:
  if y == 9 and z == 1 and x <= 8 and x >= 1 then
    ui_hill_focus = x-1
  end
  local i = ui_hill_focus
  local j = hills[ui_hill_focus].screen_focus
  if y >=10 and y<=14 and x>=2 and x<=6 and z == 1 then
    es[i].x = x
    es[i].y = y - 7
    local midi_notes = hills[i].note_ocean
    local played_index = (((7-es[i].y)*5) + (es[i].x-1)-1)
    local played_note;
    if params:string('hill_'..i..'_iso_quantize') == 'yes' then
      played_note = hills[i].note_ocean[played_index+1] + (12 * params:get('hill_'..i..'_iso_octave'))
    else
      played_note = (params:get('hill '..i..' base note') + played_index) + (12 * params:get('hill_'..i..'_iso_octave'))
    end
    -- print(played_index+1, played_note)
    force_note(i,nil,played_note)
    -- end
    for k = 1,16 do
      local table_to_record =
      {
        ["event"] = "es",
        ["x"] = es[i].x,
        ["y"] = es[i].y,
        ["id"] = k,
        ["hill_i"] = i,
        ["hill_j"] = j,
        ["octave"] = params:get('hill_'..i..'_iso_octave'),
        -- ["legato"] = params:get('hill_'..i..'_legato') == 1
      }
      write_pattern_data(k,table_to_record,false)
    end
  elseif y >=10 and y<=14 and x>=2 and x<=6 and z == 0 then
    local nx = x
    local ny = y - 7
    local midi_notes = hills[i].note_ocean
    local played_index = (((7-ny)*5) + (nx-1)-1)
    local played_note;
    if params:string('hill_'..i..'_iso_quantize') == 'yes' then
      played_note = hills[i].note_ocean[played_index+1] + (12 * params:get('hill_'..i..'_iso_octave'))
    else
      played_note = (params:get('hill '..i..' base note') + played_index) + (12 * params:get('hill_'..i..'_iso_octave'))
    end
    local ch = params:get("hill "..i.." MIDI note channel")
    MIDI:note_off(played_note,0,ch)
  elseif x >= 2 and x <= 3 and y == 15 and z == 1 then
    params:delta('hill_'..i..'_iso_octave',x == 2 and -1 or 1)
  end
  if z == 1 then
    grid_dirty = true
  end
end

return grid_lib