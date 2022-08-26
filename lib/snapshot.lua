local snapshot = {}

function snapshot.init()
  selected_snapshot = {}
  snapshot_overwrite = {}
  snapshot_overwrite_mod = false
  snapshots = {}
  for i = 1,number_of_hills do
    snapshots[i] = {}
    snapshot_overwrite[i] = {}
  end

  for j = 1,#kildare.drums do
    for coll = 1,8 do
      snapshots[j][coll] = {}
      snapshot_overwrite[j][coll] = false
    end
  end

  snapshots.delay = {}
  snapshots.reverb = {}
  snapshots.main = {}
  
  for k,v in pairs(kildare.fx) do
    snapshot_overwrite[v] = {}
    for coll = 1,8 do
      snapshots[v][coll] = {}
      snapshot_overwrite[v][coll] = false
    end
    snapshots[v].partial_restore = false
    snapshots[v].restore_times = {["beats"] = {1,2,4,8,16,32,64,128}, ["time"] = {1,2,4,8,16,32,64,128}, ["mode"] = "beats"}
    snapshots[v].mod_index = 0
    snapshots[v].focus = 0
  end

  snapshots.mod = {["index"] = 0, ["held"] = {false,false,false,false,false,false}}
end

function snapshot.pack(voice,coll)
  if type(voice) == "number" and voice <= 10 then
    local d_voice = kildare.drums[voice]
    for i = 1, #kildare_drum_params[d_voice] do
      local d = kildare_drum_params[d_voice][i]
      if d.type ~= 'separator' and not d.lfo_exclude then
        snapshots[voice][coll][d.id] = params:get(d_voice.."_"..d.id)
      end
    end
  else
    -- delay, reverb, main
    for i = 1, #kildare_fx_params[voice] do
      local d = kildare_fx_params[voice][i]
      if d.type ~= 'separator' and not d.lfo_exclude then
        snapshots[voice][coll][d.id] = params:get(voice.."_"..d.id)
      end
    end
  end

  selected_snapshot[voice] = coll
end

function snapshot.seed_restore_state_to_all(voice,coll,_p)

end

function snapshot.unpack(voice, coll)
  if type(voice) == "number" and voice <= 10 then
    if hills[voice].snapshot.partial_restore then
      clock.cancel(hills[voice].snapshot.fnl)
      hills[voice].snapshot.partial_restore = false
    end
    local d_voice = kildare.drums[voice]
    for i = 1, #kildare_drum_params[d_voice] do
      local d = kildare_drum_params[d_voice][i]
      if d.type ~= 'separator' and not d.lfo_exclude then
        params:set(d_voice.."_"..d.id, snapshots[voice][coll][d.id])
      end
    end
  else
    if snapshots[voice].partial_restore then
      clock.cancel(snapshots[voice].fnl)
      snapshots[voice].partial_restore = false
    end
    -- delay, reverb, main
    for i = 1, #kildare_fx_params[voice] do
      local d = kildare_fx_params[voice][i]
      if d.type ~= 'separator' and not d.lfo_exclude then
        params:set(voice.."_"..d.id, snapshots[voice][coll][d.id])
      end
    end
  end

  selected_snapshot[voice] = coll

  -- print("restored snapshot", voice, coll)

  -- TODO: ADD OPTIONAL SHIT?
  
  screen_dirty = true
  grid_dirty = true
end

function snapshot.save_to_slot(_t,slot)
  clock.sleep(0.25)
  local focus;
  if type(_t) == "number" and _t <= 10 then
    focus = hills[_t].snapshot.saver_active
  else
    focus = snapshots[_t].saver_active
  end
  focus = true
  if focus then
    if not mods.alt then
      snapshot.pack(_t,slot)
    else
      snapshot.clear(_t,slot)
    end
    grid_dirty = true
  end
  focus = false
end

function snapshot.clear(_t,slot)
  local pre_clear_restore = snapshots[_t][slot].restore
  snapshots[_t][slot] = {}
  snapshots[_t][slot].restore = pre_clear_restore
  if selected_snapshot[_t] == slot then
    selected_snapshot[_t] = 0
  end
end

function snapshot.fnl(fn, origin, dest_ms, fps)
  return clock.run(function()
    fps = fps or 15 -- default
    local spf = 1 / fps -- seconds per frame
    fn(origin)
    for _,v in ipairs(dest_ms) do
      local count = math.floor(v[2] * fps) -- number of iterations
      local stepsize = (v[1]-origin) / count -- how much to increment by each iteration
      while count > 0 do
        clock.sleep(spf)
        origin = origin + stepsize -- move toward destination
        count = count - 1 -- count iteration
        fn(origin)
      end
    end
  end)
end

snapshot.funnel_done_action = function(voice,coll)
  -- print("snapshot funnel done",voice,coll)
  snapshot.unpack(voice, coll)
  if type(voice) == 'number' and voice <= 10 then
    if hills[voice].snapshot.partial_restore then
      hills[voice].snapshot.partial_restore = false
    end
  else
    if snapshots[voice].partial_restore then
      snapshots[voice].partial_restore = false
    end
  end
end


function snapshot.route_funnel(voice,coll,sec,style)
  local focus;
  if type(voice) == 'number' and voice <= 10 then
    focus = hills[voice].snapshot
  else
    focus = snapshots[voice]
  end
  if style ~= nil then
    if style == "beats" then
      sec = clock.get_beat_sec()*sec
    elseif style == "time" then
      -- sec = sec
      sec = clock.get_beat_sec()*sec
    end
  end
  if sec == 0 then
    if focus.partial_restore then
      clock.cancel(focus.fnl)
      -- print("partial restore try_it",voice,coll)
      snapshot.funnel_done_action(voice,coll)
    else
      snapshot.funnel_done_action(voice,coll)
    end
  else
    -- print("doing try it for "..voice)
    if focus.partial_restore then
      clock.cancel(focus.fnl)
      -- print("interrupted, canceling previous journey")
    end
    focus.partial_restore = true

    local original_srcs = _t.deep_copy(snapshots[voice][coll])

    if type(voice) == 'number' and voice <= 10 then
      local d_voice = kildare.drums[voice]
      for i = 1, #kildare_drum_params[d_voice] do
        local d = kildare_drum_params[d_voice][i]
        if d.type ~= 'separator' and not d.lfo_exclude then
          original_srcs[d.id] = params:get(d_voice.."_"..d.id)
        end
      end
    else
      -- delay, reverb, main
      for i = 1, #kildare_fx_params[voice] do
        local d = kildare_fx_params[voice][i]
        if d.type ~= 'separator' and not d.lfo_exclude then
          original_srcs[d.id] = params:get(voice.."_"..d.id)
        end
      end
    end
    
    focus.fnl = snapshot.fnl(
      function(r_val)
        focus.current_value = r_val

        if type(voice) == 'number' and voice <=10 then
          local d_voice = kildare.drums[voice]
          for i = 1, #kildare_drum_params[d_voice] do
            local d = kildare_drum_params[d_voice][i]
            if d.type ~= 'separator' and not d.lfo_exclude then
              params:set(d_voice.."_"..d.id, util.linlin(0,1,original_srcs[d.id],snapshots[voice][coll][d.id],r_val))
            end
          end
        else
          for i = 1, #kildare_fx_params[voice] do
            local d = kildare_fx_params[voice][i]
            if d.type ~= 'separator' and not d.lfo_exclude then
              params:set(voice.."_"..d.id, util.linlin(0,1,original_srcs[d.id],snapshots[voice][coll][d.id],r_val))
            end
          end
        end

        screen_dirty = true
        grid_dirty = true
        if focus.current_value ~= nil and util.round(focus.current_value,0.001) == 1 then
          snapshot.funnel_done_action(voice,coll)
        end
      end,
      0,
      {{1,sec}},
      60
    )
  end
end

return snapshot