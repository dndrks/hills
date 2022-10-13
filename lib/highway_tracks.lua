local track_actions = {}

track = {}

track_clock = {}

track_paste_style = 1

track_paramset = paramset.new()
local track_retrig_lookup = 
{
  1/32,
  1/24,
  1/16,
  1/12,
  1/8,
  1/6,
  3/16,
  1/4,
  5/16,
  1/3,
  3/8,
  2/3,
  1/2,
  3/4,
  1,
  4/3,
  1.5,
  2,
  8/3,
  3,
  4,
  6,
  8,
  16,
  32
}

function track_actions.init(target)
  track[target] = {}
  track[target].playing = false
  track[target].pause = false
  track[target].hold = false
  track[target].enabled = false
  track[target].time = 1/4
  track[target].step = 1
  track[target].notes = {}
  track[target].prob = {}
  track[target].last_condition = true
  track[target].conditional = {}
  track[target].conditional.cycle = 0
  track[target].conditional.A = {}
  track[target].conditional.B = {}
  track[target].conditional.mode = {}
  track[target].conditional.retrig_clock = nil
  track[target].conditional.retrig_count = {}
  track[target].conditional.retrig_time = {}
  track[target].focus = "main"
  track[target].fill =
  {
    ["notes"] = {},
    ["prob"] = {},
    ["conditional"] = {["A"] = {}, ["B"] = {}, ["mode"] = {}, ["retrig_count"] = {}, ["retrig_time"] = {}}
  }
  for i = 1,128 do
    track[target].prob[i] = 100
    track[target].conditional.A[i] = 1
    track[target].conditional.B[i] = 1
    track[target].conditional.mode[i] = "A:B"
    track[target].conditional.retrig_count[i] = 0
    track_paramset:add_option("track_retrig_time_"..target.."_"..i,"",
    {
      "1/32",
      "1/24",
      "1/16",
      "1/12",
      "1/8",
      "1/6",
      "3/16",
      "1/4",
      "5/16",
      "1/3",
      "3/8",
      "2/3",
      "1/2",
      "3/4",
      "1",
      "1.33",
      "1.5",
      "2",
      "2.33",
      "3",
      "4",
      "6",
      "8",
      "16",
      "32"
    },
    8)
    track_paramset:set_action("track_retrig_time_"..target.."_"..i, function(x)
      track[target].conditional.retrig_time[i] = track_retrig_lookup[x]
    end)

    track_paramset:add_option("track_fill_retrig_time_"..target.."_"..i,"",
    {
      "1/32",
      "1/24",
      "1/16",
      "1/12",
      "1/8",
      "1/6",
      "3/16",
      "1/4",
      "5/16",
      "1/3",
      "3/8",
      "2/3",
      "1/2",
      "3/4",
      "1",
      "1.33",
      "1.5",
      "2",
      "2.33",
      "3",
      "4",
      "6",
      "8",
      "16",
      "32"
    },
    8)
    track_paramset:set_action("track_fill_retrig_time_"..target.."_"..i, function(x)
      track[target].fill.conditional.retrig_time[i] = track_retrig_lookup[x]
    end)
    track[target].conditional.retrig_time[i] = track_retrig_lookup[track_paramset:get("track_retrig_time_"..target.."_"..i)]
    
    track[target].fill.prob[i] = 100
    track[target].fill.conditional.A[i] = 1
    track[target].fill.conditional.B[i] = 1
    track[target].fill.conditional.mode[i] = "A:B"
    track[target].fill.conditional.retrig_count[i] = 0
    track[target].fill.conditional.retrig_time[i] = track_retrig_lookup[track_paramset:get("track_fill_retrig_time_"..target.."_"..i)]
  end

  track[target].gate = {}
  track[target].gate.active = false
  track[target].gate.prob = 0
  track[target].swing = 50
  track[target].mode = "fwd"
  track[target].start_point = 1
  track[target].end_point = 16
  track[target].down = 0
  track[target].loop = true
  track_clock[target] = clock.run(track_actions.iterate,target)
end

-- function track_actions.find_index(tab,el)
--   local rev = {}
--   for k,v in pairs(tab) do
--       rev[v]=k
--   end
--   return rev[el]
-- end

function track_actions.add(target, value)
  if track[target].hold then
    table.insert(track[target].notes, value)
    track[target].end_point = #track[target].notes
  end
end

function track_actions.enable(target,state)
  track[target].enabled = state
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
  local track_start =
  {
    ["fwd"] = track[i].start_point - 1
  , ["bkwd"] = track[i].end_point + 1
  , ["pend"] = track[i].start_point
  , ["rnd"] = track[i].start_point - 1
  }
  track[i].step = track_start[track[i].mode]
  track[i].pause = false
  track[i].playing = true
  if track[i].mode == "pend" then
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
  track[i].pause = true
  track[i].playing = false
  track[i].step = track[i].start_point
  track[i].conditional.cycle = 0
  -- grid_dirty = true
end

function track_actions.iterate(target)
  while true do
    clock.sync(track[target].time)
    track_actions.tick(target)
  end
end

function track_actions.tick(target,source)
  if _song.transport_active then
    local focused_set = track[target].focus == "main" and track[target] or track[target].fill
    if tab.count(track[target].notes) > 0 then
      if track[target].pause == false then
        -- print(track[target].step, clock.get_beats(),track[1].notes[1])
        if track[target].step == track[target].end_point and not track[target].loop then
          track_actions.stop_playback(target)
        else
          if track[target].swing > 50 and track[target].step % 2 == 1 then
            local base_time = (clock.get_beat_sec() * track[target].time)
            local swung_time =  base_time*util.linlin(50,100,0,1,track[target].swing)
            clock.run(function()
              clock.sleep(swung_time)
              track_actions.process(target)
            end)
          else
            track_actions.process(target,source)
          end
          track[target].playing = true
          grid_dirty = true
        end
      else
        track[target].playing = false
      end
    else
      track[target].playing = false
    end
  end
  grid_dirty = true
end

function track_actions.prob_fill(target,s_p,e_p,value)
  local focused_set = track[target].focus == "main" and track[target] or track[target].fill
  for i = s_p,e_p do
    focused_set.prob[i] = value
  end
end

function track_actions.cond_fill(target,s_p,e_p,a_val,b_val) -- gets weird...
  local focused_set = track[target].focus == "main" and track[target] or track[target].fill
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
  local focused_set = track[target].focus == "main" and track[target] or track[target].fill
  if type == "retrig_count" then
    for i = s_p,e_p do
      focused_set.conditional[type][i] = val
    end
  else
    for i = s_p,e_p do
      track_paramset:set((track[target].focus == "main" and "track_retrig_time_" or "track_fill_retrig_time_")..target.."_"..i,val)
    end
  end
end

function track_actions.fill(target,s_p,e_p,style)
  local focused_set = track[target].focus == "main" and track[target] or track[target].fill
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
  if not track[target].playing
  and not track[target].pause
  and not track[target].enabled
  then
    track_actions.enable(target,true)
    track[target].pause = true
    track[target].hold = true
    grid_dirty = true
  end
  screen_dirty = true
end

function track_actions.copy(target)
  if track_clipboard == nil then
    track_clipboard = mc.deep_copy(track[target])
    track_clipboard_bank_source = target
    track_clipboard_pad_source = page.tracks.seq_position[target]
    track_clipboard_layer_source = track[target].focus
  end
end

function track_actions.paste(target,style)
  if track_clipboard ~= nil then
    if style == 1 then -- paste all
      for i = 1,128 do
        track[target].notes[i] = track_clipboard.notes[i]
        track[target].prob[i] = track_clipboard.prob[i]
        track[target].conditional.A[i] = track_clipboard.conditional.A[i]
        track[target].conditional.B[i] = track_clipboard.conditional.B[i]
        track[target].conditional.mode[i] = track_clipboard.conditional.mode[i]
        track[target].conditional.retrig_count[i] = track_clipboard.conditional.retrig_count[i]
        track_paramset:set("track_retrig_time_"..target.."_"..i,tab.key(track_retrig_lookup,track_clipboard.conditional.retrig_time[i]))
        track[target].fill.notes[i] = track_clipboard.fill.notes[i]
        track[target].fill.prob[i] = track_clipboard.fill.prob[i]
        track[target].fill.conditional.A[i] = track_clipboard.fill.conditional.A[i]
        track[target].fill.conditional.B[i] = track_clipboard.fill.conditional.B[i]
        track[target].fill.conditional.mode[i] = track_clipboard.fill.conditional.mode[i]
        track[target].fill.conditional.retrig_count[i] = track_clipboard.fill.conditional.retrig_count[i]
        track_paramset:set("track_fill_retrig_time_"..target.."_"..i,tab.key(track_retrig_lookup,track_clipboard.fill.conditional.retrig_time[i]))
        track[target].swing = track_clipboard.swing
        track[target].mode = track_clipboard.mode
        track[target].start_point = track_clipboard.start_point
        track[target].end_point = track_clipboard.end_point
        track[target].loop = track_clipboard.loop
      end
    elseif style == 2 then -- paste individual
      local i = page.tracks.seq_position[target]
      track[target].notes[i] = track_clipboard.notes[track_clipboard_pad_source]
      track[target].prob[i] = track_clipboard.prob[track_clipboard_pad_source]
      track[target].conditional.A[i] = track_clipboard.conditional.A[track_clipboard_pad_source]
      track[target].conditional.B[i] = track_clipboard.conditional.B[track_clipboard_pad_source]
      track[target].conditional.mode[i] = track_clipboard.conditional.mode[track_clipboard_pad_source]
      track[target].conditional.retrig_count[i] = track_clipboard.conditional.retrig_count[track_clipboard_pad_source]
      track_paramset:set("track_retrig_time_"..target.."_"..i,tab.key(track_retrig_lookup,track_clipboard.conditional.retrig_time[track_clipboard_pad_source]))
      track[target].fill.notes[i] = track_clipboard.fill.notes[track_clipboard_pad_source]
      track[target].fill.prob[i] = track_clipboard.fill.prob[track_clipboard_pad_source]
      track[target].fill.conditional.A[i] = track_clipboard.fill.conditional.A[track_clipboard_pad_source]
      track[target].fill.conditional.B[i] = track_clipboard.fill.conditional.B[track_clipboard_pad_source]
      track[target].fill.conditional.mode[i] = track_clipboard.fill.conditional.mode[track_clipboard_pad_source]
      track[target].fill.conditional.retrig_count[i] = track_clipboard.fill.conditional.retrig_count[track_clipboard_pad_source]
      track_paramset:set("track_fill_retrig_time_"..target.."_"..i,tab.key(track_retrig_lookup,track_clipboard.fill.conditional.retrig_time[track_clipboard_pad_source]))
    elseif style == 3 then -- paste specific layer
      local destination = track[target].focus == "main" and track[target] or track[target].fill
      local source = track_clipboard_layer_source == "main" and track_clipboard or track_clipboard.fill
      for i = 1,128 do
        destination.notes[i] = source.notes[i]
        destination.prob[i] = source.prob[i]
        destination.conditional.A[i] = source.conditional.A[i]
        destination.conditional.B[i] = source.conditional.B[i]
        destination.conditional.mode[i] = source.conditional.mode[i]
        destination.conditional.retrig_count[i] = source.conditional.retrig_count[i]
        track_paramset:set(
          (track[target].focus == "main" and "track_retrig_time_" or "track_fill_retrig_time_")
          ..target.."_"..i,tab.key(track_retrig_lookup,track_clipboard.conditional.retrig_time[i]))
        track[target].swing = track_clipboard.swing
        track[target].mode = track_clipboard.mode
        track[target].start_point = track_clipboard.start_point
        track[target].end_point = track_clipboard.end_point
        track[target].loop = track_clipboard.loop
      end
    end
    track_clipboard = nil
    track_clipboard_pad_source = nil
    track_clipboard_bank_source = nil
  end
end

function track_actions.process(target,source)
  if track[target].step == nil then
    print("how is track step nil???")
    track[target].step = track[target].start_point
  end
  if track[target].mode == "fwd" then
    track_actions.forward(target)
  elseif track[target].mode == "bkwd" then
    track_actions.backward(target)
  elseif track[target].mode == "pend" then
    track_actions.pendulum(target)
  elseif track[target].mode == "rnd" then
    track_actions.random(target)
  end
  if menu ~= 1 then screen_dirty = true end
  track_actions.cheat(target,track[target].step,source)
end

function track_actions.forward(target)
  track[target].step = wrap(track[target].step + 1,track[target].start_point,track[target].end_point)
  if track[target].step == track[target].start_point then
    track[target].conditional.cycle = track[target].conditional.cycle + 1
  end
end

function track_actions.backward(target)
  track[target].step = wrap(track[target].step - 1,track[target].start_point,track[target].end_point)
  if track[target].step == track[target].end_point then
    track[target].conditional.cycle = track[target].conditional.cycle + 1
  end
end

function track_actions.random(target)	
  track[target].step = math.random(track[target].start_point,track[target].end_point)
  if track[target].step == track[target].start_point or track[target].step == track[target].end_point then
    track[target].conditional.cycle = track[target].conditional.cycle + 1
  end
end

track_direction = {}

for i = 1,3 do
  track_direction[i] = "positive"
end

function track_actions.pendulum(target)
    if track_direction[target] == "positive" then
        track[target].step = track[target].step + 1
        if track[target].step > track[target].end_point then
            track[target].step = track[target].end_point
        end
    elseif track_direction[target] == "negative" then
        track[target].step = track[target].step - 1
        if track[target].step == track[target].start_point - 1 then
            track[target].step = track[target].start_point
        end
    end
    if track[target].step == track[target].end_point and track[target].step ~= track[target].start_point then
      track_direction[target] = "negative"
    elseif track[target].step == track[target].start_point then
      track_direction[target] = "positive"
    end
end

function track_actions.check_prob(target,step)
  if track[target].focus == "main" then
    if track[target].prob[step] == 0 then
      return false
    elseif track[target].prob[step] >= math.random(1,100) then
      return true
    else
      return false
    end
  else
    if track[target].fill.prob[step] == 0 then
      return false
    elseif track[target].fill.prob[step] >= math.random(1,100) then
      return true
    else
      return false
    end
  end
  
end

function track_actions.cheat(target,step,source)
  if (track[target].focus == "main" and track[target].notes[step] ~= nil) or (track[target].focus == "fill" and track[target].fill.notes[step] ~= nil) then   
    local should_happen = track_actions.check_prob(target,step)
    if should_happen then
      local A_step, B_step
      if track[target].focus == "main" then
        A_step = track[target].conditional.A[step]
        B_step = track[target].conditional.B[step]
      else
        A_step = track[target].fill.conditional.A[step]
        B_step = track[target].fill.conditional.B[step]
      end
      -- print("should happen")

      if track[target].conditional.mode[step] == "A:B" then
        if track[target].conditional.cycle < A_step then
          track[target].last_condition = false
        elseif track[target].conditional.cycle == A_step then
          track_actions.execute_step(target,step,source)
        elseif track[target].conditional.cycle > A_step then
          if track[target].conditional.cycle <= (A_step + B_step) then
            if track[target].conditional.cycle % (A_step + B_step) == 0 then
              track_actions.execute_step(target,step,source)
            else
              track[target].last_condition = false
              -- grid_actions.kill_note(target,track[target].notes[wrap(step-1,track[target].start_point,track[target].end_point)])
            end
          else
            if (track[target].conditional.cycle - A_step) % B_step == 0 then
              track_actions.execute_step(target,step,source)
            else
              track[target].last_condition = false
              -- grid_actions.kill_note(target,track[target].notes[wrap(step-1,track[target].start_point,track[target].end_point)])
            end
          end
        end
      elseif track[target].conditional.mode[step] == "PRE" then
        if track[target].last_condition then
          track_actions.execute_step(target,step,source)
        else
          track[target].last_condition = false
        end
      elseif track[target].conditional.mode[step] == "NOT PRE" then
        if track[target].last_condition then
          track[target].last_condition = false
        else
          track_actions.execute_step(target,step,source)
        end
      elseif track[target].conditional.mode[step] == "NEI" then
        local neighbors = {3,1,2}
        if track[neighbors[target]].last_condition then
          track_actions.execute_step(target,step,source)
        else
          track[target].last_condition = false
        end
      elseif track[target].conditional.mode[step] == "NOT NEI" then
        local neighbors = {3,1,2}
        if track[neighbors[target]].last_condition then
          track[target].last_condition = false
        else
          track_actions.execute_step(target,step,source)
        end
      end


    else
      track[target].last_condition = false
    end
  end
end

function track_actions.check_gate_prob(target)
  if  track[target].gate.prob == 0 then
    return false
  elseif track[target].gate.prob >= math.random(1,100) then
    return true
  else
    return false
  end
end

function track_actions.execute_step(target,step,source)
  local focused_set = {}
  if track[target].focus == "main" then
    focused_set = track[target].notes
  else
    focused_set = track[target].fill.notes
  end
  local last_pad = focused_set[wrap(step-1,track[target].start_point,track[target].end_point)]
  bank[target].id = focused_set[step]
  selected[target].x = (5*(target-1)+1)+(math.ceil(bank[target].id/4)-1)
  if (bank[target].id % 4) ~= 0 then
    selected[target].y = 9-(bank[target].id % 4)
  else
    selected[target].y = 5
  end
  -- print("should be this note.."..track[1].notes[1],clock.get_beats()) 
  track_actions.resolve_step(target,step,last_pad)
end

function track_actions.resolve_step(target,step,last_pad)
  local focused_set = {}
  if track[target].focus == "main" then
    focused_set = track[target].notes
  else
    focused_set = track[target].fill.notes
  end
  if last_pad ~= nil then
    local next_pad = focused_set[wrap(step+1,track[target].start_point,track[target].end_point)]
    cheat(target,bank[target].id)
    track_actions.retrig_step(target,step)
    if next_pad == nil then
    end
  else
    cheat(target,bank[target].id)
    track_actions.retrig_step(target,step)
    local this_last_pad = focused_set[step]
  end
  track[target].last_condition = true
end

function track_actions.retrig_step(target,step)
  if track[target].conditional.retrig_clock ~= nil then
    clock.cancel(track[target].conditional.retrig_clock)
  end
  local focused_set = {}
  if track[target].focus == "main" then
    focused_set = track[target].conditional
  else
    focused_set = track[target].fill.conditional
  end
  local base_time = (clock.get_beat_sec() * track[target].time)
  local swung_time =  base_time*util.linlin(50,100,0,1,track[target].swing)
  if focused_set.retrig_count[step] > 0 then
    track[target].conditional.retrig_clock = clock.run(
      function()
        for i = 1,focused_set.retrig_count[step] do
          clock.sleep(((clock.get_beat_sec() * track[target].time)*focused_set.retrig_time[step])+swung_time)
          cheat(target,bank[target].id)
        end
      end
    )
  end
end

-- function track_actions.timed_note_off(target,pad)
--   clock.run(function()
--     clock.sleep(clock.get_beat_sec() * (track[target].time-(track[target].time/10)))
--     grid_actions.kill_note(target,pad)
--     -- print("killing", target, pad)
--   end)
-- end

function track_actions.clear(target)
  -- for k,v in pairs(track[target].notes) do
  --   if tab.contains(held_keys[target],v) then
  --     -- print("////>"..v)
  --     grid_actions.kill_note(target,v)
  --   end
  -- end
  -- if params:string("track_"..target.."_hold_style") ~= "sequencer" then
    track[target].playing = false
    track[target].pause = false
    track[target].hold = false
    local focused_set = track[target].focus == "main" and track[target] or track[target].fill
    focused_set.notes = {}
    track[target].start_point = 1
    track[target].end_point = 1
    track[target].step = track[target].start_point
    track[target].loop = true
    clock.cancel(track_clock[target])
    track_clock[target] = nil
    track_clock[target] = clock.run(track_actions.iterate,target)
  -- elseif params:string("track_"..target.."_hold_style") == "sequencer" then
  --   local focused_set = track[target].focus == "main" and track[target] or track[target].fill
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