local m = {}

-- 1. TRANSPOSITION : ahhh this needs to account for other changes, can't just re-establish scale
-- would i need to get down to a root note delta? so how many from the root note is this, then scale via the scale?
-- m.transpose = function(i,delta)
--   add_undo_step(i)
--   params:delta("hill "..i.." base note",delta)
-- end

m.transpose = function(i,j,pos,delta)
  local current_scale = mu.generate_scale_of_length(params:get("hill "..i.." base note"),params:get("hill "..i.." scale"),hills[i][j].max)
  local current_note_pos = tab.key(current_scale,shape_data[i][j].notes[pos])
  current_note_pos = util.clamp(current_note_pos + delta,hills[i][j].min,hills[i][j].max)
  -- hills[i][j].notes[pos] = current_scale[current_note_pos]
  shape_data[i][j].notes[pos] = current_scale[current_note_pos]
end

-- 2. REVERSAL
m.reverse = function(i,j,start_point,end_point)
	local rev = {}
	for k = end_point, start_point, -1 do
		rev[end_point - k + 1] = stored[i][j].note_step[k]
	end
  for k = start_point, end_point do
    local range = (end_point-start_point)+1
    stored[i][j].note_step[k] = rev[util.linlin(start_point,end_point,1,range,k)]
  end
end

-- 3. ROTATION
m.rotate = function(i,j,first,second)
  local originals = {stored[i][j].note_step[first], stored[i][j].note_step[second]}
  stored[i][j].note_step[first] = originals[2]
  stored[i][j].note_step[second] = originals[1]
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

  --- doesn't really work....
  -- for x = 1,128 do
  --   if #hills[i].base_step_pattern.entries[x] > 0 then
  --     for k,v in pairs(hills[i].base_step_pattern.entries[x]) do
  --       -- print(k,v)
  --       hills[i].base_step_pattern.entries[x][k].base_step = util.linlin(0,pre_change_duration,0,hills[i][j].duration,v.base_step)
  --     end
  --   end
  -- end
end

-- 6. INTERPOLATION
m.reshape = function(i,j,new_shape)
  hills[i][j].shape = new_shape
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
m.shuffle = function(i,j,lo,hi)
  local shuffled = {}
  for m = lo,hi do
    local pos = math.random(1, #shuffled+1)
	  table.insert(shuffled, pos, hills[i][j].note_num.pool[m])
  end
  for k,v in pairs(shuffled) do
    -- print(k,v)
    hills[i][j].note_num.pool[lo-1+k] = v
  end
end

m.random_note_fill = function(i,j,start_point,end_point,lo,hi)
  -- fill these steps with random notes between min and max
  local randomized = {}
  for m = start_point,end_point do
    hills[i][j].note_num.pool[m] = math.random(lo,hi)
  end
  tab.print(hills[i][j].note_num.pool)
end

m.flatten = function(i,j,start_point,end_point,note)
  for m = start_point, end_point do
    hills[i][j].note_num.pool[m] = note
  end
end

m.offset_timestart = function(i,j,target,delta)
  hills[i][j].note_timestamp[target] = hills[i][j].note_timestamp[target] + delta
  print(hills[i][j].note_timestamp[target])
  -- calculate_timedeltas(i,j)
end

m.offset_timeend = function(i,j,target,delta)
  for k = target+1,#stored[i][j].note_step do
    stored[i][j].note_timestamp[k] = stored[i][j].note_timestamp[k] + delta
  end
  calculate_timedeltas(i,j)
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

return m