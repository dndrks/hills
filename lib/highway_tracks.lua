local track_actions = {}

track = {}

track_clock = {}

track_paste_style = 1

local function wrap(n, min, max)
  if max >= min then
    local y = n
    local d = max - min + 1
    while y > max do
      y = y - d
    end
    while y < min do
      y = y + d
    end
    return y
  else
    error("max needs to be greater than min")
  end
end

track_paramset = paramset.new()
local track_retrig_lookup = 
{
  1/64,
  1/48,
  1/40,
  1/32,
  1/24,
  1/16,
  1/12,
  1/10,
  1/8,
  1/6,
  1/5,
  3/16,
  1/4,
  5/16,
  1/3,
  3/8,
  1/2,
  2/3,
  3/4,
  1,
  4/3,
  1.5,
  2,
  8/3,
  3,
  4,
  5,
  6,
  8,
  10,
  12,
  16,
  24,
  32,
  40,
  48,
  64
}

function track_actions.init(target)
  track[target] = {}
  track[target].active_hill = 1
  track[target].seed_prob = 100
  for hill_count = 1,8 do
    track[target][hill_count] = {}
    track[target][hill_count].playing = false
    track[target][hill_count].pause = false
    track[target][hill_count].hold = false
    track[target][hill_count].enabled = false
    track[target][hill_count].time = 1/4
    track[target][hill_count].step = 1
    track[target][hill_count].ui_position = 1
    track[target][hill_count].ui_page = 1
    
    track[target][hill_count].notes = {}
    track[target][hill_count].chord_degrees = {}
    track[target][hill_count].velocities = {}
    track[target][hill_count].trigs = {}
    track[target][hill_count].lock_trigs = {}
    track[target][hill_count].prob = {}
    track[target][hill_count].micro = {}
    track[target][hill_count].er = {pulses = 0, steps = 16, shift = 0}
    track[target][hill_count].last_condition = false
    track[target][hill_count].conditional = {}
    track[target][hill_count].conditional.cycle = 0
    track[target][hill_count].conditional.A = {}
    track[target][hill_count].conditional.B = {}
    track[target][hill_count].conditional.mode = {}
    track[target][hill_count].conditional.retrig_clock = nil
    track[target][hill_count].conditional.retrig_count = {}
    track[target][hill_count].conditional.retrig_time = {}
    track[target][hill_count].conditional.retrig_slope = {}
    track[target][hill_count].focus = "main"
    track[target][hill_count].fill =
    {
      ["notes"] = {},
      ["chord_degrees"] = {},
      ["velocities"] = {},
      ["trigs"] = {},
      ["lock_trigs"] = {},
      ["prob"] = {},
      ['er'] = {pulses = 0, steps = 16, shift = 0},
      ["conditional"] = {
        ["A"] = {},
        ["B"] = {},
        ["mode"] = {},
        ["retrig_count"] = {},
        ["retrig_time"] = {},
        ["retrig_slope"] = {}
      }
    }
    for i = 1,128 do
      track[target][hill_count].notes[i] = 1
      track[target][hill_count].chord_degrees[i] = 1
      track[target][hill_count].velocities[i] = 127
      track[target][hill_count].trigs[i] = false
      track[target][hill_count].lock_trigs[i] = false
      track[target][hill_count].prob[i] = 100
      track[target][hill_count].conditional.A[i] = 1
      track[target][hill_count].conditional.B[i] = 1
      track[target][hill_count].conditional.mode[i] = "A:B"
      track[target][hill_count].conditional.retrig_count[i] = 0
      track[target][hill_count].micro[i] = 0
      track_paramset:add_option("track_retrig_time_"..target.."_"..hill_count..'_'..i,"",
      {
        '1/64',
        '1/48',
        '1/40',
        '1/32',
        '1/24',
        '1/16',
        '1/12',
        '1/10',
        '1/8',
        '1/6',
        '1/5',
        '3/16',
        '1/4',
        '5/16',
        '1/3',
        '3/8',
        '1/2',
        '2/3',
        '3/4',
        '1',
        '4/3',
        '1.5',
        '2',
        '8/3',
        '3',
        '4',
        '5',
        '6',
        '8',
        '10',
        '12',
        '16',
        '24',
        '32',
        '40',
        '48',
        '64'
      },
      13)
      track_paramset:set_action("track_retrig_time_"..target.."_"..hill_count..'_'..i, function(x)
        track[target][hill_count].conditional.retrig_time[i] = track_retrig_lookup[x]
      end)

      track_paramset:add_option("track_fill_retrig_time_"..target.."_"..hill_count..'_'..i,"",
      {
        '1/64',
        '1/48',
        '1/40',
        '1/32',
        '1/24',
        '1/16',
        '1/12',
        '1/10',
        '1/8',
        '1/6',
        '1/5',
        '3/16',
        '1/4',
        '5/16',
        '1/3',
        '3/8',
        '1/2',
        '2/3',
        '3/4',
        '1',
        '4/3',
        '1.5',
        '2',
        '8/3',
        '3',
        '4',
        '5',
        '6',
        '8',
        '10',
        '12',
        '16',
        '24',
        '32',
        '40',
        '48',
        '64'
      },
      13)
      track_paramset:set_action("track_fill_retrig_time_"..target.."_"..hill_count..'_'..i, function(x)
        track[target][hill_count].fill.conditional.retrig_time[i] = track_retrig_lookup[x]
      end)
      track[target][hill_count].conditional.retrig_time[i] = track_retrig_lookup[track_paramset:get("track_retrig_time_"..target.."_"..hill_count..'_'..i)]
      track[target][hill_count].conditional.retrig_slope[i] = 0
      
      track[target][hill_count].fill.notes[i] = 1
      track[target][hill_count].fill.chord_degrees[i] = 1
      track[target][hill_count].fill.velocities[i] = 127
      track[target][hill_count].fill.trigs[i] = false
      track[target][hill_count].fill.lock_trigs[i] = false
      track[target][hill_count].fill.prob[i] = 100
      track[target][hill_count].fill.conditional.A[i] = 1
      track[target][hill_count].fill.conditional.B[i] = 1
      track[target][hill_count].fill.conditional.mode[i] = "A:B"
      track[target][hill_count].fill.conditional.retrig_count[i] = 0
      track[target][hill_count].fill.conditional.retrig_time[i] = track_retrig_lookup[track_paramset:get("track_fill_retrig_time_"..target.."_"..hill_count..'_'..i)]
      track[target][hill_count].fill.conditional.retrig_slope[i] = 0
    end

    track[target][hill_count].gate = {}
    track[target][hill_count].gate.active = false
    track[target][hill_count].gate.prob = 0
    track[target][hill_count].swing = 50
    track[target][hill_count].mode = "fwd"
    track[target][hill_count].start_point = 1
    track[target][hill_count].end_point = 16
    track[target][hill_count].down = 0
    track[target][hill_count].loop = true
    if hill_count == track[target].active_hill then
      track_clock[target] = clock.run(track_actions.iterate,target)
    end
  end
end

-- function track_actions.find_index(tab,el)
--   local rev = {}
--   for k,v in pairs(tab) do
--       rev[v]=k
--   end
--   return rev[el]
-- end

function track_actions.add(target, value)
  local _active = track[target][track[target].active_hill]
  if _active.hold then
    table.insert(_active.notes, value)
    _active.end_point = #_active.notes
  end
end

function track_actions.enable(target,state)
  track[target][track[target].active_hill].enabled = state
end

function track_actions.toggle(state,target)
  local i = target
  if state == "start" then
    track_actions.start_playback(i)
  elseif state == "stop" then
    track_actions.stop_playback(i)
  end
end

function track_actions.start_playback(i)
  local j = track[i].active_hill
  local track_start =
  {
    ["fwd"] = track[i][j].start_point - 1
  , ["bkwd"] = track[i][j].end_point + 1
  , ["pend"] = track[i][j].start_point
  , ["rnd"] = track[i][j].start_point - 1
  }
  track[i][j].step = track_start[track[i][j].mode]
  track[i][j].pause = false
  track[i][j].playing = true
  if track[i][j].mode == "pend" then
    track_direction[i] = "negative"
  end
  -- TODO: fix up later! this needs to be wrapped in transport logic
  -- local external_transport = false
  -- for i = 1,16 do
  --   if params:string("port_"..i.."_start_stop_in") == "yes" then
  --     external_transport = true
  --     break
  --   end
  -- end
  -- if not transport.is_running and not external_transport then
  --   print("should start transport...2")
  --   transport.toggle_transport()
  -- end
  -- if params:string("track_"..i.."_hold_style") == "sequencer" then
  --   if track[i].enabled then track_actions.enable(i,false) end
  -- end
  -- grid_dirty = true
end

function track_actions.stop_playback(i)
  local j = track[i].active_hill
  track[i][j].pause = true
  track[i][j].playing = false
  track[i][j].step = track[i][j].start_point
  track[i][j].conditional.cycle = 0
  -- grid_dirty = true
end

function track_actions.sync_playheads()
  for i = 1,10 do
    track[i][track[i].active_hill].step = track[i][track[i].active_hill].start_point
  end
end

function track_actions.iterate(target)
  while true do
    clock.sync(track[target][track[target].active_hill].time, track[target][track[target].active_hill].micro[track[target][track[target].active_hill].step]/384)
    track_actions.tick(target)
  end
end

function track_actions.tick(target,source) -- FIXME: shouldn't just trigger all voices all the time...
  if song_atoms.transport_active then
    local _active = track[target][track[target].active_hill]
    local focused_set = _active.focus == "main" and _active or _active.fill
    -- if tab.count(_active.notes) > 0 then
    if _active.pause == false then
      -- print(_active.step, clock.get_beats(),track[1].notes[1])
      if _active.step == _active.end_point and not _active.loop then
        track_actions.stop_playback(target)
      else
        if _active.swing > 50 and _active.step % 2 == 1 then
          local base_time = (clock.get_beat_sec() * _active.time)
          local swung_time =  base_time*util.linlin(50,100,0,1,_active.swing)
          clock.run(function()
            clock.sleep(swung_time)
            track_actions.process(target)
          end)
        else
          track_actions.process(target,source)
        end
        _active.playing = true
      end
    else
      _active.playing = false
    end
    -- else
    --   _active.playing = false
    -- end
    grid_dirty = true
  end
end

function track_actions.prob_fill(target,s_p,e_p,value)
  local _active = track[target][track[target].active_hill]
  local focused_set = _active.focus == "main" and _active or _active.fill
  for i = s_p,e_p do
    focused_set.prob[i] = value
  end
end

function track_actions.cond_fill(target,s_p,e_p,a_val,b_val) -- TODO: gets weird...
  local _active = track[target][track[target].active_hill]
  local focused_set = _active.focus == "main" and _active or _active.fill
  if b_val ~= "meta" then
    for i = s_p,e_p do
      focused_set.conditional.A[i] = a_val
      focused_set.conditional.B[i] = b_val
      focused_set.conditional.mode[i] = "A:B"
    end
  else
    for i = s_p,e_p do
      focused_set.conditional.mode[i] = a_val
    end
  end
end

function track_actions.retrig_fill(target,s_p,e_p,val,type)
  local _active = track[target][track[target].active_hill]
  local focused_set = _active.focus == "main" and _active or _active.fill
  if type == "retrig_count" then
    for i = s_p,e_p do
      focused_set.conditional[type][i] = val
    end
  else
    for i = s_p,e_p do
      track_paramset:set((_active.focus == "main" and "track_retrig_time_" or "track_fill_retrig_time_")..target.."_"..track[target].active_hill..'_'..i,val)
    end
  end
end

function track_actions.fill(target,s_p,e_p,style)
  local _active = track[target][track[target].active_hill]
  local focused_set = _active.focus == "main" and _active or _active.fill
  local snakes = 
  { 
      [1] = { 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16 }
    , [2] = { 1,2,3,4,8,7,6,5,9,10,11,12,16,15,14,13 }
    , [3] = { 1,5,9,13,2,6,10,14,3,7,11,15,4,8,12,16 }
    , [4] = { 1,5,9,13,14,10,6,2,3,7,11,15,16,12,8,4 }
    , [5] = { 1,2,3,4,8,12,16,15,14,13,9,5,6,7,11,10 }
    , [6] = { 13,14,15,16,12,8,4,3,2,1,5,9,10,11,7,6 }
    , [7] = { 1,2,5,9,6,3,4,7,10,13,14,11,8,12,15,16 }
    , [8] = { 1,6,11,16,15,10,5,2,7,12,8,3,9,14,13,4 }
  }
  if style < 9 then
    for i = s_p,e_p do
      focused_set.notes[i] = snakes[style][wrap(i,1,16)]
    end
  elseif style == 9 then
    for i = s_p,e_p do
      focused_set.notes[i] = math.random(1,16)
    end
  elseif style == 10 then
    for i = s_p,e_p do
      if params:get("track_"..target.."_rand_prob") >= math.random(100) then
        focused_set.notes[i] = math.random(1,16)
      else
        focused_set.notes[i] = nil
      end
    end
  elseif style == 11 then -- alt layer

  end
  if not _active.playing
  and not _active.pause
  and not _active.enabled
  then
    track_actions.enable(target,true)
    _active.pause = true
    _active.hold = true
    grid_dirty = true
  end
  screen_dirty = true
end

function track_actions.copy(target)
  local _active = track[target][track[target].active_hill]
  if track_clipboard == nil then
    track_clipboard = mc.deep_copy(_active)
    track_clipboard_bank_source = target
    track_clipboard_pad_source = page.tracks.seq_position[target]
    track_clipboard_layer_source = _active.focus
  end
end

function track_actions.paste(target,style)
  local _active = track[target][track[target].active_hill]
  if track_clipboard ~= nil then
    if style == 1 then -- paste all
      for i = 1,128 do
        _active.notes[i] = track_clipboard.notes[i]
        _active.prob[i] = track_clipboard.prob[i]
        _active.conditional.A[i] = track_clipboard.conditional.A[i]
        _active.conditional.B[i] = track_clipboard.conditional.B[i]
        _active.conditional.mode[i] = track_clipboard.conditional.mode[i]
        _active.conditional.retrig_count[i] = track_clipboard.conditional.retrig_count[i]
        track_paramset:set("track_retrig_time_"..target.."_"..i,tab.key(track_retrig_lookup,track_clipboard.conditional.retrig_time[i]))
        _active.fill.notes[i] = track_clipboard.fill.notes[i]
        _active.fill.prob[i] = track_clipboard.fill.prob[i]
        _active.fill.conditional.A[i] = track_clipboard.fill.conditional.A[i]
        _active.fill.conditional.B[i] = track_clipboard.fill.conditional.B[i]
        _active.fill.conditional.mode[i] = track_clipboard.fill.conditional.mode[i]
        _active.fill.conditional.retrig_count[i] = track_clipboard.fill.conditional.retrig_count[i]
        track_paramset:set("track_fill_retrig_time_"..target.."_"..track[target].active_hill..'_'..i,tab.key(track_retrig_lookup,track_clipboard.fill.conditional.retrig_time[i]))
        _active.swing = track_clipboard.swing
        _active.mode = track_clipboard.mode
        _active.start_point = track_clipboard.start_point
        _active.end_point = track_clipboard.end_point
        _active.loop = track_clipboard.loop
      end
    elseif style == 2 then -- paste individual
      local i = page.tracks.seq_position[target]
      _active.notes[i] = track_clipboard.notes[track_clipboard_pad_source]
      _active.prob[i] = track_clipboard.prob[track_clipboard_pad_source]
      _active.conditional.A[i] = track_clipboard.conditional.A[track_clipboard_pad_source]
      _active.conditional.B[i] = track_clipboard.conditional.B[track_clipboard_pad_source]
      _active.conditional.mode[i] = track_clipboard.conditional.mode[track_clipboard_pad_source]
      _active.conditional.retrig_count[i] = track_clipboard.conditional.retrig_count[track_clipboard_pad_source]
      track_paramset:set("track_retrig_time_"..target.."_"..track[target].active_hill..'_'..i,tab.key(track_retrig_lookup,track_clipboard.conditional.retrig_time[track_clipboard_pad_source]))
      _active.fill.notes[i] = track_clipboard.fill.notes[track_clipboard_pad_source]
      _active.fill.prob[i] = track_clipboard.fill.prob[track_clipboard_pad_source]
      _active.fill.conditional.A[i] = track_clipboard.fill.conditional.A[track_clipboard_pad_source]
      _active.fill.conditional.B[i] = track_clipboard.fill.conditional.B[track_clipboard_pad_source]
      _active.fill.conditional.mode[i] = track_clipboard.fill.conditional.mode[track_clipboard_pad_source]
      _active.fill.conditional.retrig_count[i] = track_clipboard.fill.conditional.retrig_count[track_clipboard_pad_source]
      track_paramset:set("track_fill_retrig_time_"..target.."_"..track[target].active_hill..'_'..i,tab.key(track_retrig_lookup,track_clipboard.fill.conditional.retrig_time[track_clipboard_pad_source]))
    elseif style == 3 then -- paste specific layer
      local destination = _active.focus == "main" and _active or _active.fill
      local source = track_clipboard_layer_source == "main" and track_clipboard or track_clipboard.fill
      for i = 1,128 do
        destination.notes[i] = source.notes[i]
        destination.prob[i] = source.prob[i]
        destination.conditional.A[i] = source.conditional.A[i]
        destination.conditional.B[i] = source.conditional.B[i]
        destination.conditional.mode[i] = source.conditional.mode[i]
        destination.conditional.retrig_count[i] = source.conditional.retrig_count[i]
        track_paramset:set(
          (_active.focus == "main" and "track_retrig_time_" or "track_fill_retrig_time_")
          ..target.."_"..track[target].active_hill..'_'..i,tab.key(track_retrig_lookup,track_clipboard.conditional.retrig_time[i]))
        _active.swing = track_clipboard.swing
        _active.mode = track_clipboard.mode
        _active.start_point = track_clipboard.start_point
        _active.end_point = track_clipboard.end_point
        _active.loop = track_clipboard.loop
      end
    end
    track_clipboard = nil
    track_clipboard_pad_source = nil
    track_clipboard_bank_source = nil
  end
end

function track_actions.process(target,source)
  local _active = track[target][track[target].active_hill]
  if _active.step == nil then
    print("how is track step nil???")
    _active.step = _active.start_point
  end
  if _active.mode == "fwd" then
    track_actions.forward(target)
  elseif _active.mode == "bkwd" then
    track_actions.backward(target)
  elseif _active.mode == "pend" then
    track_actions.pendulum(target)
  elseif _active.mode == "rnd" then
    track_actions.random(target)
  end
  if menu ~= 1 then screen_dirty = true end
  track_actions.run(target,_active.step,source)
end

function track_actions.forward(target)
  local _active = track[target][track[target].active_hill]
  _active.step = wrap(_active.step + 1,_active.start_point,_active.end_point)
  if _active.step == _active.start_point then
    _active.conditional.cycle = _active.conditional.cycle + 1
  end
end

function track_actions.backward(target)
  local _active = track[target][track[target].active_hill]
  _active.step = wrap(_active.step - 1,_active.start_point,_active.end_point)
  if _active.step == _active.end_point then
    _active.conditional.cycle = _active.conditional.cycle + 1
  end
end

function track_actions.random(target)
  local _active = track[target][track[target].active_hill]
  _active.step = math.random(_active.start_point,_active.end_point)
  if _active.step == _active.start_point or _active.step == _active.end_point then
    _active.conditional.cycle = _active.conditional.cycle + 1
  end
end

function track_actions.generate_er(i,j)
  local _active = track[i][j]
  local focused_set = _active.focus == "main" and _active or _active.fill
  local generated = euclid.gen(focused_set.er.pulses, focused_set.er.steps, focused_set.er.shift)
  for length = focused_set.start_point, focused_set.end_point do
    focused_set.trigs[length] = generated[length-(focused_set.start_point-1)]
  end
end

track_direction = {}

for i = 1,8 do
  track_direction[i] = "positive"
end

function track_actions.pendulum(target)
  local _active = track[target][track[target].active_hill]
  if track_direction[target] == "positive" then
    _active.step = _active.step + 1
    if _active.step > _active.end_point then
        _active.step = _active.end_point
    end
  elseif track_direction[target] == "negative" then
    _active.step = _active.step - 1
    if _active.step == _active.start_point - 1 then
        _active.step = _active.start_point
    end
  end
  if _active.step == _active.end_point and _active.step ~= _active.start_point then
    track_direction[target] = "negative"
  elseif _active.step == _active.start_point then
    track_direction[target] = "positive"
  end
end

function track_actions.check_prob(target,step)
  local _active = track[target][track[target].active_hill]
  if _active.focus == "main" then
    if _active.prob[step] == 0 then
      return false
    elseif _active.prob[step] >= math.random(1,100) then
      return true
    else
      return false
    end
  else
    if _active.fill.prob[step] == 0 then
      return false
    elseif _active.fill.prob[step] >= math.random(1,100) then
      return true
    else
      return false
    end
  end
  
end

function track_actions.run(target,step,source)
  local _active = track[target][track[target].active_hill]
  if (_active.focus == "main" and 
        (_active.trigs[step] == true or _active.lock_trigs[step] == true))
      or (_active.focus == "fill" and
        (_active.fill.trigs[step] == true or _active.fill.lock_trigs[step] == true))
  then   
    local should_happen = track_actions.check_prob(target,step)
    if should_happen then
      local A_step, B_step
      if _active.focus == "main" then
        A_step = _active.conditional.A[step]
        B_step = _active.conditional.B[step]
      else
        A_step = _active.fill.conditional.A[step]
        B_step = _active.fill.conditional.B[step]
      end
      -- print("should happen")

      if _active.conditional.mode[step] == "A:B" then
        if _active.conditional.cycle < A_step then
          _active.last_condition = false
        elseif _active.conditional.cycle == A_step then
          track_actions.execute_step(target,step,source)
        elseif _active.conditional.cycle > A_step then
          if _active.conditional.cycle <= (A_step + B_step) then
            if _active.conditional.cycle % (A_step + B_step) == 0 then
              track_actions.execute_step(target,step,source)
            else
              _active.last_condition = false
              -- grid_actions.kill_note(target,_active.notes[wrap(step-1,_active.start_point,_active.end_point)])
            end
          else
            if (_active.conditional.cycle - A_step) % B_step == 0 then
              track_actions.execute_step(target,step,source)
            else
              _active.last_condition = false
              -- grid_actions.kill_note(target,_active.notes[wrap(step-1,_active.start_point,_active.end_point)])
            end
          end
        end
      elseif _active.conditional.mode[step] == "PRE" then
        if _active.last_condition then
          track_actions.execute_step(target,step,source)
        else
          _active.last_condition = false
        end
      elseif _active.conditional.mode[step] == "NOT PRE" then
        if _active.last_condition then
          _active.last_condition = false
        else
          track_actions.execute_step(target,step,source)
        end
      elseif _active.conditional.mode[step] == "NEI" then
        local neighbors = {10,1,2,3,4,5,6,7,8,9}
        if track[neighbors[target]][track[target].active_hill].last_condition then
          track_actions.execute_step(target,step,source)
        else
          _active.last_condition = false
        end
      elseif _active.conditional.mode[step] == "NOT NEI" then
        local neighbors = {10,1,2,3,4,5,6,7,8,9}
        if track[neighbors[target]][track[target].active_hill].last_condition then
          _active.last_condition = false
        else
          track_actions.execute_step(target,step,source)
        end
      end


    else
      _active.last_condition = false
    end
  end
end

function track_actions.check_gate_prob(target)
  local _active = track[target][track[target].active_hill]
  if  _active.gate.prob == 0 then
    return false
  elseif _active.gate.prob >= math.random(1,100) then
    return true
  else
    return false
  end
end

function track_actions.execute_step(target,step,source)
  local _active = track[target][track[target].active_hill]
  local focused_set = {}
  if _active.focus == "main" then
    focused_set = _active.notes
  else
    focused_set = _active.fill.notes
  end
  local last_step = focused_set[wrap(step-1,_active.start_point,_active.end_point)]
  -- print(target,last_step,wrap(step-1,_active.start_point,_active.end_point),step,focused_set[step])
  track_actions.resolve_step(target, step, last_step)
end

function track_actions.resolve_step(target, step, last_pad)
  local _active = track[target][track[target].active_hill]
  local focused_set = {}
  if _active.focus == "main" then
    focused_set = _active.notes
  else
    focused_set = _active.fill.notes
  end
  if last_pad ~= nil then
    local next_pad = focused_set[wrap(step+1,_active.start_point,_active.end_point)]
    -- cheat(target,bank[target].id)
    local i,j = target, track[target].active_hill
    pass_note(
      i,
      j,
      hills[i][j], -- seg
      focused_set[step], -- note_val
      step, -- index
      0 -- retrig index
    )
    if _active.trigs[step] then
      track_actions.retrig_step(target,step)
    end
    if next_pad == nil then
    end
  else
    -- cheat(target,bank[target].id)
    local i,j = target, track[target].active_hill
    pass_note(
      i,
      j,
      hills[i][j], -- seg
      focused_set[step], -- note_val
      step, -- index
      0 -- retrig_index
    )
    if _active.trigs[step] then
      track_actions.retrig_step(target,step)
    end
  end
  _active.last_condition = true
end

function track_actions.retrig_step(target,step)
  local _active = track[target][track[target].active_hill]
  if _active.conditional.retrig_clock ~= nil then
    clock.cancel(_active.conditional.retrig_clock)
  end
  local focused_set, focused_notes = {}, {}
  if _active.focus == "main" then
    focused_set = _active.conditional
    focused_notes = _active.notes
  else
    focused_set = _active.fill.conditional
    focused_notes = _active.fill.notes
  end
  local base_time = (clock.get_beat_sec() * _active.time)
  local swung_time =  base_time*util.linlin(50,100,0,1,_active.swing)
  if focused_set.retrig_count[step] > 0 then
    local i,j = target, track[target].active_hill
    _active.conditional.retrig_clock = clock.run(
      function()
        for retrigs = 1,focused_set.retrig_count[step] do
          print('passing')
          clock.sleep(((clock.get_beat_sec() * _active.time)*focused_set.retrig_time[step])+swung_time)
          -- cheat(target,bank[target].id)
          pass_note(
            i,
            j,
            hills[i][j], -- seg
            focused_notes[step], -- note_val
            step, -- index
            retrigs
          )
        end
      end
    )
  end
end

function track_actions.clear(target)
  local _active = track[target][track[target].active_hill]
  -- for k,v in pairs(_active.notes) do
  --   if tab.contains(held_keys[target],v) then
  --     -- print("////>"..v)
  --     grid_actions.kill_note(target,v)
  --   end
  -- end
  -- if params:string("track_"..target.."_hold_style") ~= "sequencer" then
    _active.playing = false
    _active.pause = false
    _active.hold = false
    local focused_set = _active.focus == "main" and track[target] or _active.fill
    focused_set.notes = {}
    _active.start_point = 1
    _active.end_point = 1
    _active.step = _active.start_point
    _active.loop = true
    clock.cancel(track_clock[target])
    track_clock[target] = nil
    track_clock[target] = clock.run(track_actions.iterate,target)
  -- elseif params:string("track_"..target.."_hold_style") == "sequencer" then
  --   local focused_set = _active.focus == "main" and track[target] or _active.fill
  --   focused_set.notes = {}
  -- end
end

function track_actions.savestate()
  local collection = params:get("collection")
  local dirname = _path.data.."cheat_codes_yellow/track/"
  if os.rename(dirname, dirname) == nil then
    os.execute("mkdir " .. dirname)
  end
  
  local dirname = _path.data.."cheat_codes_yellow/track/collection-"..collection.."/"
  if os.rename(dirname, dirname) == nil then
    os.execute("mkdir " .. dirname)
  end

  for i = 1,3 do
    tab.save(track[i],_path.data .. "cheat_codes_yellow/track/collection-"..collection.."/"..i..".data")
  end
  track_paramset:write(_path.data.."cheat_codes_yellow/track/collection-"..collection.."/paramset.data")
end

function track_actions.loadstate()
  local collection = params:get("collection")
  for i = 1,3 do
    if tab.load(_path.data .. "cheat_codes_yellow/track/collection-"..collection.."/"..i..".data") ~= nil then
      track[i] = tab.load(_path.data .. "cheat_codes_yellow/track/collection-"..collection.."/"..i..".data")
    end
  end
  track_paramset:read(_path.data.."cheat_codes_yellow/track/collection-"..collection.."/paramset.data")
end

function track_actions.restore_collection()
  for i = 1,3 do
    track[i].down = track[i].down == nil and 0 or track[i].down
  end
end

return track_actions