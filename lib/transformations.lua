local m = {}

-- 1. TRANSPOSITION : ahhh this needs to account for other changes, can't just re-establish scale
-- would i need to get down to a root note delta? so how many from the root note is this, then scale via the scale?
-- m.transpose = function(i,delta)
--   add_undo_step(i)
--   params:delta("hill "..i.." base note",delta)
-- end

-- m.transpose = function(i,j,pos,delta)
--   local current_scale = mu.generate_scale_of_length(params:get("hill "..i.." base note"),params:get("hill "..i.." scale"),hills[i][j].max)
--   local current_note_pos = tab.key(current_scale,shape_data[i][j].notes[pos])
--   current_note_pos = util.clamp(current_note_pos + delta,hills[i][j].min,hills[i][j].max)
--   -- hills[i][j].notes[pos] = current_scale[current_note_pos]
--   shape_data[i][j].notes[pos] = current_scale[current_note_pos]
-- end

m.adjust_velocity = function(i,j,pos,delta)
  hills[i][j].note_velocity[pos] = util.clamp(hills[i][j].note_velocity[pos]+delta,0,127)
end

m.transpose = function(i,j,pos,delta)
  hills[i][j].note_num.pool[pos] = util.clamp(hills[i][j].note_num.pool[pos]+delta,1,hills[i][j].note_num.max)
  hills[i][j].note_num.chord_degree[pos] = util.wrap(hills[i][j].note_num.pool[pos], 1, 7)
end

m.track_transpose = function(i,j,_page,pos,delta)
  local _active = track[i][j]
  local _a = _active[_active.page]
  local focused_set = {}
  if _active.focus == "main" then
    focused_set = _active.base_note
    if _a.trigs[pos] == false then
      if delta > 0 then
        _htracks.change_trig_state(_a,pos, true, i, j, _page)
      end
      goto finished
    end
  else
    focused_set = _a.fill.base_note
    if _a.fill.trigs[pos] == false then
      if delta > 0 then
        _htracks.change_trig_state(_a.fill,pos, true, i, j, _page)
      end
      goto finished
    end
  end
  if focused_set[pos] == 0 and delta < 1 then
    if focused_set == _active.base_note then
      _htracks.change_trig_state(_a,pos, false, i, j, _page)
    else
      _htracks.change_trig_state(_a.fill,pos, true, i, j, _page)
    end
    local note_check;
    if params:string('voice_model_'..i) ~= 'sample' and params:string('voice_model_'..i) ~= 'input' then
      note_check = params:get(i..'_'..params:string('voice_model_'..i)..'_carHz')
    else
      note_check = params:get('hill '..i..' base note')
    end
    focused_set[pos] = note_check
  else
    if focused_set[pos] == -1 then
      local note_check;
      if params:string('voice_model_'..i) ~= 'sample' and params:string('voice_model_'..i) ~= 'input' then
        note_check = params:get(i..'_'..params:string('voice_model_'..i)..'_carHz')
      else
        note_check = params:get('hill '..i..' base note')
      end
      focused_set[pos] = note_check + delta
    else
      focused_set[pos] = util.clamp(focused_set[pos] + delta, 0, 127)
    end
  end
  ::finished::
end

m.sample_transpose = function(i,j,pos,delta)
  hills[i][j].sample_controls.rate[pos] = util.clamp(hills[i][j].sample_controls.rate[pos]+delta,1,#sample_speedlist)
end

-- 2. REVERSAL
m['reverse notes'] = function(i,j,start_point,end_point,focus,sc)
  local target = sc ~= nil and hills[i][j].sample_controls.rate or hills[i][j].note_num.pool
  local rev = {}
  for k = end_point, start_point, -1 do
    rev[end_point - k + 1] = target[k]
  end
  for k = start_point, end_point do
    local range = (end_point-start_point)+1
    target[k] = rev[util.linlin(start_point,end_point,1,range,k)]
    if target == hills[i][j].note_num.pool then
      hills[i][j].note_num.chord_degree[k] = util.wrap(hills[i][j].note_num.pool[k], 1, 7)
    end
  end
end

m.reverse = function(i,j,start_point,end_point,focus,sc)
  local target = sc ~= nil and hills[i][j].sample_controls.rate or hills[i][j].note_num.pool
  local rev = {}
  for k = end_point, start_point, -1 do
    rev[end_point - k + 1] = target[k]
  end
  for k = start_point, end_point do
    local range = (end_point-start_point)+1
    target[k] = rev[util.linlin(start_point,end_point,1,range,k)]
    if target == hills[i][j].note_num.pool then
      hills[i][j].note_num.chord_degree[k] = util.wrap(hills[i][j].note_num.pool[k], 1, 7)
    end
  end
end

m['reverse vel'] = function(i,j,start_point,end_point,focus)
  local target = hills[i][j].note_velocity
  local rev = {}
  for k = end_point, start_point, -1 do
    rev[end_point - k + 1] = target[k]
  end
  for k = start_point, end_point do
    local range = (end_point-start_point)+1
    target[k] = rev[util.linlin(start_point,end_point,1,range,k)]
  end
end

-- 3. ROTATION
m['rotate notes'] = function(i,j,start_point,end_point,focus,sc)
  local target = sc ~= nil and hills[i][j].sample_controls.rate or hills[i][j].note_num.pool
  local originals = {}
  for k = start_point,end_point do
    table.insert(originals,target[k])
  end
  for k = 1,#originals do
    target[util.wrap(start_point+k,start_point,end_point)] = originals[k]
    if target == hills[i][j].note_num.pool then
      hills[i][j].note_num.chord_degree[util.wrap(start_point+k,start_point,end_point)] = util.wrap(target[util.wrap(start_point+k,start_point,end_point)], 1, 7)
    end
  end
end

m['rotate track notes'] = function(i,j)
  local _page = track[i][j].page
  local target = track[i][j].focus == 'main' and track[i][j][_page].base_note or track[i][j][_page].fill.base_note
  local originals = {}
  local steps_with_trigs
  for k = track[i][j][_page].start_point, track[i][j][_page].end_point do
    if track[i][j][_page].trigs[k] then
      originals[k] = target[k]
    else
      originals[k] = 'none'
    end
  end
  tab.print(originals)
  for k = 1,#originals do
    if originals[k] ~= 'none' then
      print('rotate track notes: '..util.wrap(track[i][j][_page].start_point+k, track[i][j][_page].start_point, track[i][j][_page].end_point), originals[k])
      target[util.wrap(track[i][j][_page].start_point+k, track[i][j][_page].start_point, track[i][j][_page].end_point)] = originals[k]
    end
  end
end

m.rotate = function(i,j,start_point,end_point,focus,sc)
  local target = sc ~= nil and hills[i][j].sample_controls.rate or hills[i][j].note_num.pool
  local originals = {}
  for k = start_point,end_point do
    table.insert(originals,target[k])
  end
  for k = 1,#originals do
    target[util.wrap(start_point+k,start_point,end_point)] = originals[k]
    if target == hills[i][j].note_num.pool then
      hills[i][j].note_num.chord_degree[util.wrap(start_point+k,start_point,end_point)] = util.wrap(target[util.wrap(start_point+k,start_point,end_point)], 1, 7)
    end
  end
end

m['rotate vel'] = function(i,j,start_point,end_point,focus)
  local target = hills[i][j].note_velocity
  local originals = {}
  for k = start_point,end_point do
    table.insert(originals,target[k])
  end
  for k = 1,#originals do
    target[util.wrap(start_point+k,start_point,end_point)] = originals[k]
  end
end

-- 4. PHASE OFFSET
m.adjust_window = function(i,j,new_min,new_max)
  local h = hills[i]
  h[j].min = new_min
  h[j].max = new_max
end

-- 5. RESCALING
m.rescale = function(i,j,mult)

  local pre_change_duration = hills[i][j].duration
  hills[i][j].duration = util.round(clock.get_beat_sec() * mult,0.01)
  -- hills[i][j].base_step = 0
  hills[i][j].base_step = util.linlin(0,pre_change_duration,0,hills[i][j].duration,hills[i][j].base_step)
  -- hills[i][j].eject = hills[i][j].duration
  hills[i][j].eject = util.linlin(0,pre_change_duration,0,hills[i][j].duration,hills[i][j].eject)
end

-- 6. INTERPOLATION
m.reshape = function(i,j,new_shape)
  hills[i][j].shape = new_shape
end

m.clamp_down = function(i,j)
  
end

-- 7. EXTRAPOLATION
m.bound = function(i,new_min,new_max)
  hills[i].min = new_min
  hills[i].max = new_max
end

-- 8. FRAGMENTATION
m.set_low = function(i,j,base)
  stored[i][j].low_bound = util.clamp(base,1,#stored[i][j].note_step)
  stored[i][j].step = stored[i][j].note_timestamp[stored[i][j].low_bound] -- reset
  stored[i][j].index = stored[i][j].low_bound
end

m.set_high = function(i,j,ceil)
  stored[i][j].high_bound = util.clamp(ceil,stored[i][j].low_bound,#stored[i][j].note_step)
end

m.set_window = function(i,j,base,ceil)
  m.set_high(i,j,ceil)
  m.set_low(i,j,base)
end

m.random_window = function(i,j)
  m.set_low(i,j,math.random(1,math.floor(#stored[i][j].note_step/2)))
  m.set_high(i,j,math.random(stored[i][j].low_bound,#stored[i][j].note_step))
end

-- 9. SUBSTITUTION -- this should commit!
m['shuffle notes'] = function(i,j,lo,hi,focus,sc)
  local target = sc ~= nil and hills[i][j].sample_controls.rate or hills[i][j].note_num.pool
  local shuffled = {}
  for m = lo,hi do
    local pos = math.random(1, #shuffled+1)
	  table.insert(shuffled, pos, target[m])
  end
  for k,v in pairs(shuffled) do
    -- print(k,v)
    target[lo-1+k] = v
    if target == hills[i][j].note_num.pool then
      hills[i][j].note_num.chord_degree[lo-1+k] = util.wrap(target[lo-1+k], 1, 7)
    end
  end
end

m['shuffle vel'] = function(i,j,lo,hi,focus)
  local target = hills[i][j].note_velocity
  local shuffled = {}
  for m = lo,hi do
    local pos = math.random(1, #shuffled+1)
	  table.insert(shuffled, pos, target[m])
  end
  for k,v in pairs(shuffled) do
    -- print(k,v)
    target[lo-1+k] = v
  end
end

m["rand fill notes"] = function(i,j,start_point,end_point,focus,sc)
  if sc == nil then
    for m = start_point,end_point do
      hills[i][j].note_num.pool[m] = math.random(1,hills[i][j].note_num.max)
      hills[i][j].note_num.chord_degree[m] = util.wrap(hills[i][j].note_num.pool[m], 1, 7)
    end
  else
    for m = start_point,end_point do
      hills[i][j].sample_controls.rate[m] = math.random(1,#sample_speedlist)
    end
  end
end

m["rand vel"] = function(i,j,start_point,end_point,focus)
  for m = start_point,end_point do
    hills[i][j].note_velocity[m] = math.random(0,127)
  end
end

m["rand rate"] = function(i,j,start_point,end_point,focus,sc)
  if sc == nil then
    for m = start_point,end_point do
      hills[i][j].note_num.pool[m] = math.random(1,hills[i][j].note_num.max)
      hills[i][j].note_num.chord_degree[m] = util.wrap(hills[i][j].note_num.pool[m], 1, 7)
    end
  else
    for m = start_point,end_point do
      hills[i][j].sample_controls.rate[m] = math.random(1,#sample_speedlist)
    end
  end
end

m["rand loop"] = function(i,j,start_point,end_point,focus,sc)
  for m = start_point,end_point do
    local state = math.random(0,1)
    if state == 1 then
      hills[i][j].sample_controls.loop[m] = true
    else
      hills[i][j].sample_controls.loop[m] = false
    end
  end
end

m['mute step'] = function(i,j,pos)
  hills[i][j].note_num.active[pos] = not hills[i][j].note_num.active[pos]
end

m.toggle_loop = function(i,j,pos)
  hills[i][j].sample_controls.loop[pos] = not hills[i][j].sample_controls.loop[pos]
end

m.offset_timestart = function(i,j,target,delta)
  hills[i][j].note_timestamp[target] = hills[i][j].note_timestamp[target] + delta
  print(hills[i][j].note_timestamp[target])
end

m.offset_timeend = function(i,j,target,delta)
  for k = target+1,#stored[i][j].note_step do
    stored[i][j].note_timestamp[k] = stored[i][j].note_timestamp[k] + delta
  end
  calculate_timedeltas(i,j)
end

m.offset_timeend_quantized = function(i,j,target,smallest,delta)
  local notes_to_durs =
  {
    ["1/4"] = 1
  , ["1/4d"] = 2/3
  , ["1/4t"] = 3/2
  , ["1/8"] = 2
  , ["1/8d"] = 4/3
  , ["1/8t"] = 3
  , ["1/16"] = 4
  , ["1/16d"] = 8/3
  , ["1/16t"] = 6
  , ["1/32"] = 8
  , ["1/32d"] = 16/3
  , ["1/32t"] = 12
  }
  local quant_val = clock.get_beat_sec()/notes_to_durs[smallest]
  hills[i][j].note_timedelta[target+1] = hills[i][j].note_timedelta[target+1] + quant_val*delta
  m.adjust_timestamps(i,j)
end

m.deep_copy = function(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == "table" then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
        copy[m.deep_copy(orig_key)] = m.deep_copy(orig_value)
    end
    setmetatable(copy, m.deep_copy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

m.static = function(i,j,start_point,end_point,pos)
  local e_p = end_point
  if e_p == nil then
    e_p = hills[i][j].high_bound.note
  end
  if start_point ~= end_point then
    for k = start_point,e_p do
      hills[i][j].note_num.pool[k] = hills[i][j].note_num.pool[pos]
      hills[i][j].note_num.chord_degree[k] = util.wrap(hills[i][j].note_num.pool[k], 1, 7)
    end
  else
    print("this is the last note, can't change any more!")
  end
end

m['static notes'] = function(i,j,start_point,end_point,pos)
  local e_p = end_point
  if e_p == nil then
    e_p = hills[i][j].high_bound.note
  end
  if start_point ~= end_point then
    for k = start_point,e_p do
      hills[i][j].note_num.pool[k] = hills[i][j].note_num.pool[pos]
      hills[i][j].note_num.chord_degree[k] = util.wrap(hills[i][j].note_num.pool[k], 1, 7)
    end
  else
    print("this is the last note, can't change any more!")
  end
end

m["static vel"] = function(i,j,start_point,end_point,pos)
  local e_p = end_point
  if e_p == nil then
    e_p = hills[i][j].high_bound.note
  end
  if start_point ~= end_point then
    for k = start_point,e_p do
      hills[i][j].note_velocity[k] = hills[i][j].note_velocity[pos]
    end
  else
    print("this is the last note, can't change any more!")
  end
end

m["static rate"] = function(i,j,start_point,end_point,pos,sc)
  local e_p = end_point
  if e_p == nil then
    e_p = hills[i][j].high_bound.note
  end
  if start_point ~= end_point then
    for k = start_point,e_p do
      hills[i][j].sample_controls.rate[k] = hills[i][j].sample_controls.rate[pos]
    end
  else
    print("this is the last note, can't change any more!")
  end
end

m["static loop"] = function(i,j,start_point,end_point,pos,sc)
  local e_p = end_point
  if e_p == nil then
    e_p = hills[i][j].high_bound.note
  end
  if start_point ~= end_point then
    for k = start_point,e_p do
      hills[i][j].sample_controls.loop[k] = hills[i][j].sample_controls.loop[pos]
    end
  else
    print("this is the last note, can't change any more!")
  end
end

m.quantize = function(i,j,smallest,start_point,end_point)
  local s_p = start_point
  local e_p = end_point
  if s_p == nil then
    s_p = hills[i][j].low_bound.note
  end
  if e_p == nil then
    e_p = hills[i][j].high_bound.note
  end
  local notes_to_durs =
  {
    ["1/4"] = 1
  , ["1/4d"] = 2/3
  , ["1/4t"] = 3/2
  , ["1/8"] = 2
  , ["1/8d"] = 4/3
  , ["1/8t"] = 3
  , ["1/16"] = 4
  , ["1/16d"] = 8/3
  , ["1/16t"] = 6
  , ["1/32"] = 8
  , ["1/32d"] = 16/3
  , ["1/32t"] = 12
  }
  local quant_val = clock.get_beat_sec()/notes_to_durs[smallest]
  for k = s_p,e_p do
    hills[i][j].note_timedelta[k] = quant_val
  end
  for k = e_p,s_p,-1 do
    if hills[i][j].note_timedelta[k] == 0 then
      print('note_timedelta',k)
      hills[i][j].note_timedelta[k] = quant_val
    end
  end
  if hills[i][j].high_bound.note > #hills[i][j].note_timedelta then
    hills[i][j].high_bound.note = #hills[i][j].note_timedelta
  end
  m.adjust_timestamps(i,j)
end

m.clamp_to_steps = function(i,j,count)
  hills[i][j].high_bound.note = hills[i][j].low_bound.note + (count-1)
end

m.adjust_timestamps = function(i,j)
  hills[i][j].note_timestamp[1] = 0
  for k = 2,#hills[i][j].note_timedelta do
    hills[i][j].note_timestamp[k] = hills[i][j].note_timestamp[k-1] + hills[i][j].note_timedelta[k]
  end
end

m.adjust_hill_start = function(i,j,delta)
  hills[i][j].low_bound.note = util.clamp(hills[i][j].low_bound.note+delta,1,hills[i][j].high_bound.note)
  if hills[i][j].index < hills[i][j].low_bound.note then
    hills[i][j].index = hills[i][j].low_bound.note
    hills[i][j].step = hills[i][j].note_timestamp[hills[i][j].index]
  end
end

m.adjust_hill_end = function(i,j,delta)
  hills[i][j].high_bound.note = util.clamp(hills[i][j].high_bound.note+delta,hills[i][j].low_bound.note,#hills[i][j].note_timedelta)
  if hills[i][j].index > hills[i][j].high_bound.note then
    hills[i][j].index = hills[i][j].high_bound.note
    hills[i][j].step = hills[i][j].note_timestamp[hills[i][j].index]
  end
end

m.nudge = function(i,j,index,delta)
  local h = hills[i]
  local seg = h[j]
  local reasonable_min, reasonable_max;
  if index == 1 then
    reasonable_min = 0
  else
    reasonable_min = seg.note_timestamp[index-1]+0.01
  end
  if index == #seg.note_timedelta then
    reasonable_max = seg.note_timestamp[index]+1
  else
    reasonable_max = seg.note_timestamp[index+1]-0.01
  end
  seg.note_timestamp[index] = util.clamp(seg.note_timestamp[index] + delta/100, reasonable_min, reasonable_max)
  calculate_timedeltas(i,j)
end

m.kill = function(i,j,index)
  local h = hills[i]
  local seg = h[j]

end

m.snap_bound = function(i,j)
  local h = hills[i]
  local seg = h[j]
  local clamp_to;
  if seg.index < 1 then
    clamp_to = 1
  else
    clamp_to = seg.index-1
  end
  seg.high_bound.note = clamp_to
end

m.reseed = function(i,j)
  local total_shape_count = tab.count(curves.easingNames)
  hills[i][j].shape = curves.easingNames[math.random(total_shape_count)]
  hills[i][j].note_timestamp = {}
  hills[i][j].note_timedelta = {}
  hills[i][j].note_num = -- this is where we track the note entries for the constructed hill
  {
    ["min"] = 1, -- defines the lowest note degree
    ["max"] = 15, -- defines the highest note degree
    ["pool"] = {}, -- gets filled with the constructed hill's notes
    ["active"] = {}, -- tracks whether the note should play
    ["chord_degree"] = {}, -- defines the shell voicing chord degree
  }
  construct(i,j)
end

return m