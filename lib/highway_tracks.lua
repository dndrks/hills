local track_actions = {}

track = {}

track_clock = {}

track_paste_style = 1

track_queues = {}

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

local function build_params(target, hill_number, i)
  track_paramset:add_option("track_retrig_time_"..target.."_"..hill_number..'_'..i,"",
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
  track_paramset:set_action("track_retrig_time_"..target.."_"..hill_number..'_'..i, function(x)
    track[target][hill_number].conditional.retrig_time[i] = track_retrig_lookup[x]
  end)

  track_paramset:add_option("track_fill_retrig_time_"..target.."_"..hill_number..'_'..i,"",
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
  track_paramset:set_action("track_fill_retrig_time_"..target.."_"..hill_number..'_'..i, function(x)
    track[target][hill_number].fill.conditional.retrig_time[i] = track_retrig_lookup[x]
  end)
end

function track_actions.init(target, hill_number, clear_reset)
  print('begin initialize track: '..target..', '..util.time())
  local build_clock = false
  local pre_clear_step;
  if clear_reset and track[target].active_hill == hill_number then
    pre_clear_step = track[target][hill_number].step
  end
  if track[target] == nil then
    track[target] = {}
    track[target].scale = {source = {}, index = 1}
    track[target].active_hill = 1
    track[target].seed_prob = 100
    track[target].song_mute = {}
    track[target].external_prm_change = {}
    track[target].rec = false
    track[target].rec_note_entry = false
    track[target].manual_note_entry = false
    track[target].mute_during_note_entry = false
    -- build_clock = true
  end

  track[target][hill_number] = {}
  track[target][hill_number].playing = false
  track[target][hill_number].pause = false
  track[target][hill_number].hold = false
  track[target][hill_number].enabled = false
  track[target][hill_number].time = 1/4
  if not clear_reset or (clear_reset and track[target].active_hill ~= hill_number) then
    track[target][hill_number].step = 1
  elseif clear_reset and track[target].active_hill == hill_number then
    track[target][hill_number].step = pre_clear_step
  end
  track[target][hill_number].ui_position = 1
  track[target][hill_number].ui_page = 1
  
  track[target][hill_number].base_note = {}
  track[target][hill_number].chord_notes = {}
  track[target][hill_number].seed_default_note = {}
  track[target][hill_number].chord_degrees = {}
  track[target][hill_number].velocities = {}
  track[target][hill_number].trigs = {}
  track[target][hill_number].muted_trigs = {}
  track[target][hill_number].accented_trigs = {}
  track[target][hill_number].legato_trigs = {}
  track[target][hill_number].lock_trigs = {}
  track[target][hill_number].prob = {}
  track[target][hill_number].micro = {}
  track[target][hill_number].song_mute = false
  track[target][hill_number].er = {pulses = 0, steps = 16, shift = 0}
  track[target][hill_number].last_condition = false
  track[target][hill_number].conditional = {}
  track[target][hill_number].conditional.cycle = 1
  track[target][hill_number].conditional.A = {}
  track[target][hill_number].conditional.B = {}
  track[target][hill_number].conditional.mode = {}
  track[target][hill_number].conditional.retrig_clock = nil
  track[target][hill_number].conditional.retrig_count = {}
  track[target][hill_number].conditional.retrig_time = {}
  track[target][hill_number].conditional.retrig_slope = {}
  track[target][hill_number].focus = "main"
  track[target][hill_number].fill =
  {
    ["base_note"] = {},
    ["chord_notes"] = {},
    ["seed_default_note"] = {},
    ["chord_degrees"] = {},
    ["velocities"] = {},
    ["trigs"] = {},
    ["muted_trigs"] = {},
    ["accented_trigs"] = {},
    ["legato_trigs"] = {},
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
    track[target][hill_number].base_note[i] = -1
    track[target][hill_number].chord_notes[i] = {0,0,0}
    track[target][hill_number].seed_default_note[i] = true
    track[target][hill_number].chord_degrees[i] = 1
    track[target][hill_number].velocities[i] = 127
    track[target][hill_number].trigs[i] = false
    track[target][hill_number].muted_trigs[i] = false
    track[target][hill_number].accented_trigs[i] = false
    track[target][hill_number].legato_trigs[i] = false
    track[target][hill_number].lock_trigs[i] = false
    track[target][hill_number].prob[i] = 100
    track[target][hill_number].conditional.A[i] = 1
    track[target][hill_number].conditional.B[i] = 1
    track[target][hill_number].conditional.mode[i] = "A:B"
    track[target][hill_number].conditional.retrig_count[i] = 0
    track[target][hill_number].micro[i] = 0
    if not clear_reset then
      build_params(target,hill_number,i)
    end
    track[target][hill_number].conditional.retrig_time[i] = track_retrig_lookup[track_paramset:get("track_retrig_time_"..target.."_"..hill_number..'_'..i)]
    track[target][hill_number].conditional.retrig_slope[i] = 0
    
    track[target][hill_number].fill.base_note[i] = -1
    track[target][hill_number].fill.chord_notes[i] = {0,0,0}
    track[target][hill_number].fill.seed_default_note[i] = true
    track[target][hill_number].fill.chord_degrees[i] = 1
    track[target][hill_number].fill.velocities[i] = 127
    track[target][hill_number].fill.trigs[i] = false
    track[target][hill_number].fill.muted_trigs[i] = false
    track[target][hill_number].fill.accented_trigs[i] = false
    track[target][hill_number].fill.legato_trigs[i] = false
    track[target][hill_number].fill.lock_trigs[i] = false
    track[target][hill_number].fill.prob[i] = 100
    track[target][hill_number].fill.conditional.A[i] = 1
    track[target][hill_number].fill.conditional.B[i] = 1
    track[target][hill_number].fill.conditional.mode[i] = "A:B"
    track[target][hill_number].fill.conditional.retrig_count[i] = 0
    track[target][hill_number].fill.conditional.retrig_time[i] = track_retrig_lookup[track_paramset:get("track_fill_retrig_time_"..target.."_"..hill_number..'_'..i)]
    track[target][hill_number].fill.conditional.retrig_slope[i] = 0
  end

  track[target][hill_number].gate = {}
  track[target][hill_number].gate.active = false
  track[target][hill_number].gate.prob = 0
  track[target][hill_number].swing = 50
  track[target][hill_number].mode = "fwd"
  track[target][hill_number].start_point = 1
  track[target][hill_number].end_point = 16
  track[target][hill_number].down = 0
  track[target][hill_number].loop = true
  if build_clock then
    track_clock[target] = clock.run(track_actions.iterate,target)
  end

  print('initializing track: '..target..', '..util.time())
end

-- function track_actions.add(target, value)
--   local _active = track[target][track[target].active_hill]
--   if _active.hold then
--     table.insert(_active.notes, value)
--     _active.end_point = #_active.notes
--   end
-- end

function track_actions.change_pattern(i,j,source)
  track_actions.stop_playback(i)
  if source ~= 'from pattern' then
    track[i].active_hill = j
  end
  track_actions.start_playback(i,j)
end

function track_actions.enable(target,state)
  track[target][track[target].active_hill].enabled = state
end

-- function track_actions.toggle(state,target)
--   local i = target
--   if state == "start" then
--     track_actions.start_playback(i)
--   elseif state == "stop" then
--     track_actions.stop_playback(i)
--   end
-- end

function track_actions.start_playback(i,j)
  track[i][j].micro[0] = track[i][j].micro[1]
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
  -- track[i][j].step = track[i][j].start_point
  track[i][j].conditional.cycle = 1
  local track_start =
  {
    ["fwd"] = track[i][j].start_point - 1
  , ["bkwd"] = track[i][j].end_point + 1
  , ["pend"] = track[i][j].start_point
  , ["rnd"] = track[i][j].start_point - 1
  }
  track[i][j].step = track_start[track[i][j].mode]
  -- grid_dirty = true
end

function track_actions.sync_playheads()
  for i = 1,number_of_hills do
    track[i][track[i].active_hill].step = track[i][track[i].active_hill].start_point
  end
end

function track_actions.iterate(target)
  while true do
    clock.sync(track[target][track[target].active_hill].time, track[target][track[target].active_hill].micro[track[target][track[target].active_hill].step]/384)
    track_actions.tick(target)
  end
end

function track_actions.tick(target) -- FIXME: shouldn't just trigger all voices all the time...
  if song_atoms.transport_active or params:string('hill_'..target..'_iterator') ~= 'norns' then
    local _active = track[target][track[target].active_hill]
    local focused_set = _active.focus == "main" and _active or _active.fill
    -- if tab.count(_active.notes) > 0 then
    if _active.pause == false or params:string('hill_'..target..'_iterator') ~= 'norns' then
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
          track_actions.process(target)
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

function track_actions.change_trig_state(target_track,target_step,state, i, j)
  target_track.trigs[target_step] = state
  if state == true then
    if tab.count(_fkprm.adjusted_params_lock_trigs[i][j][target_step].params) > 0 then
      _fkprm.adjusted_params[i][j][target_step].params = _t.deep_copy(_fkprm.adjusted_params_lock_trigs[i][j][target_step].params)
    end
  end
end

function track_actions.copy(target,pattern)
  local _active = track[target][pattern]
  if track_clipboard == nil then
    track_clipboard = _t.deep_copy(_active)

    track_clipboard.playing = false
    track_clipboard.down = 0
    track_clipboard.pause = false
    track_clipboard.step = 1
    track_clipboard.enabled = false

    track_clipboard_bank_source = target
    track_clipboard_pattern_source = pattern
    -- track_clipboard_pad_source = page.tracks.seq_position[target]
    track_clipboard_layer_source = _active.focus
  end
  if fkprm_clipboard == nil then
    fkprm_clipboard = _t.deep_copy(_fkprm.adjusted_params[target][pattern])
  end
end

function track_actions.paste_new(target,pattern)
  track[target][pattern] = _t.deep_copy(track_clipboard)
  track_clipboard = nil
  _fkprm.adjusted_params[target][pattern] = _t.deep_copy(fkprm_clipboard)
  fkprm_clipboard = nil
end

function track_actions.paste(target,style)
  local _active = track[target][track[target].active_hill]
  if track_clipboard ~= nil then
    if style == 1 then -- paste all
      for i = 1,128 do
        _active.base_note[i] = track_clipboard.base_note[i]
        _active.prob[i] = track_clipboard.prob[i]
        _active.conditional.A[i] = track_clipboard.conditional.A[i]
        _active.conditional.B[i] = track_clipboard.conditional.B[i]
        _active.conditional.mode[i] = track_clipboard.conditional.mode[i]
        _active.conditional.retrig_count[i] = track_clipboard.conditional.retrig_count[i]
        track_paramset:set("track_retrig_time_"..target.."_"..i,tab.key(track_retrig_lookup,track_clipboard.conditional.retrig_time[i]))
        _active.fill.base_note[i] = track_clipboard.fill.base_note[i]
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
      _active.base_note[i] = track_clipboard.base_note[track_clipboard_pad_source]
      _active.prob[i] = track_clipboard.prob[track_clipboard_pad_source]
      _active.conditional.A[i] = track_clipboard.conditional.A[track_clipboard_pad_source]
      _active.conditional.B[i] = track_clipboard.conditional.B[track_clipboard_pad_source]
      _active.conditional.mode[i] = track_clipboard.conditional.mode[track_clipboard_pad_source]
      _active.conditional.retrig_count[i] = track_clipboard.conditional.retrig_count[track_clipboard_pad_source]
      track_paramset:set("track_retrig_time_"..target.."_"..track[target].active_hill..'_'..i,tab.key(track_retrig_lookup,track_clipboard.conditional.retrig_time[track_clipboard_pad_source]))
      _active.fill.base_note[i] = track_clipboard.fill.base_note[track_clipboard_pad_source]
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
        destination.base_note[i] = source.base_note[i]
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

function track_actions.process(target)
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
  screen_dirty = true
  track_actions.run(target,_active.step)
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
    -- focused_set.trigs[length] = generated[length-(focused_set.start_point-1)]
    _htracks.change_trig_state(focused_set,length, generated[length-(focused_set.start_point-1)], i, j)
  end
end

track_direction = {}

for i = 1,number_of_patterns do
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

function track_actions.run(target,step)
  local _active = track[target][track[target].active_hill]
  if (_active.focus == "main" and 
        (_active.trigs[step] == true or _active.lock_trigs[step] == true or _active.legato_trigs[step] == true))
      or (_active.focus == "fill" and
        (_active.fill.trigs[step] == true or _active.fill.lock_trigs[step] == true or _active.fill.legato_trigs[step] == true))
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

      if _active.conditional.mode[step] == "A:B" then
        if _active.conditional.cycle < A_step then
          _active.last_condition = false
        elseif _active.conditional.cycle == A_step then
          track_actions.execute_step(target,step)
        elseif _active.conditional.cycle > A_step then
          if _active.conditional.cycle <= (A_step + B_step) then
            if _active.conditional.cycle % (A_step + B_step) == 0 then
              track_actions.execute_step(target,step)
            else
              _active.last_condition = false
            end
          else
            if (_active.conditional.cycle - A_step) % B_step == 0 then
              track_actions.execute_step(target,step)
            else
              _active.last_condition = false
            end
          end
        end
      elseif _active.conditional.mode[step] == "PRE" then
        if _active.last_condition then
          track_actions.execute_step(target,step)
        else
          _active.last_condition = false
        end
      elseif _active.conditional.mode[step] == "NOT PRE" then
        if _active.last_condition then
          _active.last_condition = false
        else
          track_actions.execute_step(target,step)
        end
      elseif _active.conditional.mode[step] == "NEI" then
        local neighbors = {10,1,2,3,4,5,6,7,8,9}
        if track[neighbors[target]][track[target].active_hill].last_condition then
          track_actions.execute_step(target,step)
        else
          _active.last_condition = false
        end
      elseif _active.conditional.mode[step] == "NOT NEI" then
        local neighbors = {10,1,2,3,4,5,6,7,8,9}
        if track[neighbors[target]][track[target].active_hill].last_condition then
          _active.last_condition = false
        else
          track_actions.execute_step(target,step)
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

-- function track_actions.execute_step(target,step)
--   track_actions.resolve_step(target, step)
-- end

function track_actions.execute_step(target, step)
  local _active = track[target][track[target].active_hill]
  local focused_trigs = {}
  local focused_notes = {}
  local focused_legato = {}
  local focused_chords = {}
  if _active.focus == "main" then
    focused_trigs = _active.trigs[step]
    focused_notes = _active.base_note[step]
    focused_legato = _active.legato_trigs[step]
    focused_chords = _active.chord_notes[step]
  else
    focused_trigs = _active.fill.trigs[step]
    focused_notes = _active.fill.base_note[step]
    focused_legato = _active.fill.legato_trigs[step]
    focused_chords = _active.fill.chord_notes[step]
  end
  local i,j = target, track[target].active_hill
  if focused_legato and not focused_trigs then
    send_note_data(i,j,step,focused_notes)
  else
    local note_check;
    if params:string('voice_model_'..i) ~= 'sample' and params:string('voice_model_'..i) ~= 'input' then
      note_check = params:get(i..'_'..params:string('voice_model_'..i)..'_carHz')
    else
      note_check = params:get('hill '..i..' base note')
    end
    pass_note(
      i,
      j,
      hills[i][j], -- seg
      focused_notes == -1 and note_check or focused_notes, -- note_val
      step, -- index
      0 -- retrig_index
    )
    for notes = 1,3 do
      if focused_chords[notes] ~= 0 then
        -- force_note(i,j,focused_notes == -1 and note_check+focused_chords[notes] or focused_notes+focused_chords[notes]) -- note_val
      end
    end
  end
  -- TODO: should these be focuseD???
  if _active.trigs[step] then
    track_actions.retrig_step(target,step)
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
    focused_notes = _active.base_note
  else
    focused_set = _active.fill.conditional
    focused_notes = _active.fill.base_note
  end
  local base_time = (clock.get_beat_sec() * _active.time)
  local swung_time =  base_time*util.linlin(50,100,0,1,_active.swing)
  if focused_set.retrig_count[step] > 0 then
    local i,j = target, track[target].active_hill
    _active.conditional.retrig_clock = clock.run(
      function()
        for retrigs = 1,focused_set.retrig_count[step] do
          clock.sleep(((clock.get_beat_sec() * _active.time)*focused_set.retrig_time[step])+swung_time)
          local note_check;
          if params:string('voice_model_'..i) ~= 'sample' and params:string('voice_model_'..i) ~= 'input' then
            note_check = params:get(i..'_'..params:string('voice_model_'..i)..'_carHz')
          else
            note_check = params:get('hill '..i..' base note')
          end
          pass_note(
            i,
            j,
            hills[i][j], -- seg
            focused_notes[step] == -1 and note_check or focused_notes[step], -- note_val
            step, -- index
            retrigs
          )
        end
      end
    )
  end
end

function track_actions.clear(target,hill_number)
  track_actions.init(target,hill_number,true)
end

function track_actions.reset_note_to_default(i,j)
  local _active = track[i][j]
  local focused_set = _active.focus == 'main' and _active or _active.fill
  local note_check;
  if params:string('voice_model_'..i) ~= 'sample' and params:string('voice_model_'..i) ~= 'input' then
    note_check = params:get(i..'_'..params:string('voice_model_'..i)..'_carHz')
  else
    note_check = params:get('hill '..i..' base note')
  end
  if focused_set.base_note[_active.ui_position] == note_check then
    focused_set.base_note[_active.ui_position] = -1
  end
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