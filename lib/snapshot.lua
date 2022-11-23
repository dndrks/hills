local snapshot = {}

function snapshot.init()
  snapshot_lfos = {}
  snapshot_overwrite = {}
  snapshot_overwrite_mod = false
  snapshots = {}
  for i = 1,number_of_hills do
    snapshots[i] = {}
    snapshot_overwrite[i] = {}
  end

  for i = 1,#kildare.drums do
    for j = 1,#kildare.drums do
      snapshots[i][kildare.drums[j]] = {}
      snapshot_overwrite[i][kildare.drums[j]] = {}
      for coll = 1,8 do
        snapshots[i][kildare.drums[j]][coll] = {}
        snapshot_overwrite[i][kildare.drums[j]][coll] = false
      end
    end
  end

  snapshots.delay = {}
  snapshots.feedback = {}
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
   
    local d_voice, d_string;
    if voice <= 7 then
      d_voice = params:string('voice_model_'..voice)
      d_string = voice..'_'..d_voice..'_'
    else
      d_voice = 'sample'..voice-7
      d_string = d_voice..'_'
    end

    for i = 1, #kildare_drum_params[d_voice] do
      local d = kildare_drum_params[d_voice][i]
      if d.type ~= 'separator' and not d.lfo_exclude then
        snapshots[voice][d_voice][coll][d.id] = params:get(d_string..d.id)
      end
    end
  else
    -- delay, feedback, main
    for i = 1, #kildare_fx_params[voice] do
      local d = kildare_fx_params[voice][i]
      if d.type ~= 'separator' and not d.lfo_exclude then
        snapshots[voice][coll][d.id] = params:get(voice.."_"..d.id)
      end
    end
  end

end

function snapshot.seed_restore_state_to_all(voice,coll,_p)

end

function snapshot.unpack(voice, coll)
  print(voice,coll)
  if type(voice) == "number" and voice <= 10 then
    
    if hills[voice].snapshot.partial_restore then
      clock.cancel(hills[voice].snapshot.fnl)
      hills[voice].snapshot.partial_restore = false
    end

    local d_voice, d_string;
    if voice <= 7 then
      d_voice = params:string('voice_model_'..voice)
      d_string = voice..'_'..d_voice..'_'
    else
      d_voice = 'sample'..voice-7
      d_string = d_voice..'_'
    end

    for i = 1, #kildare_drum_params[d_voice] do
      local d = kildare_drum_params[d_voice][i]
      if d.type ~= 'separator' and not d.lfo_exclude and snapshots[voice][d_voice][coll][d.id] ~= nil then
        params:set(d_string..d.id, snapshots[voice][d_voice][coll][d.id])
      end
    end

  else
    if snapshots[voice].partial_restore then
      clock.cancel(snapshots[voice].fnl)
      snapshots[voice].partial_restore = false
    end
    -- delay, feedback, main
    for i = 1, #kildare_fx_params[voice] do
      local d = kildare_fx_params[voice][i]
      if d.type ~= 'separator' and not d.lfo_exclude and snapshots[voice][coll][d.id] ~= nil then
        params:set(voice.."_"..d.id, snapshots[voice][coll][d.id])
      end
    end
  end

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
  local d_voice, _snap;
  if type(_t) == 'number' then
    if _t <= 7 then
      d_voice = params:string('voice_model_'.._t)
      snapshots[_t][d_voice][slot] = {}
    elseif _t <= 10 then
      d_voice = 'sample'.._t-7
      snapshots[_t][d_voice][slot] = {}
    end
  else
    snapshots[_t][slot] = {}
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

function snapshot.crossfade(voice,scene_a,scene_b,val)
  -- 'val' will come in as -1 to 1

  -- focus.partial_restore = true

  local d_voice, d_string, original_srcs, focus;
  if voice <= 7 then
    d_voice = params:string('voice_model_'..voice)
    d_string = voice..'_'..d_voice..'_'
    focus = snapshots[voice][d_voice]
    -- original_srcs = _t.deep_copy(snapshots[voice][d_voice][coll])
  elseif voice <= 10 then
    d_voice = 'sample'..voice-7
    d_string = d_voice..'_'
    focus = snapshots[voice][d_voice]
    -- original_srcs = _t.deep_copy(snapshots[voice][d_voice][coll])
  else
    focus = snapshots[voice]
    -- original_srcs = _t.deep_copy(snapshots[voice][coll])
  end

  local d = (type(voice) == 'number' and voice <=10) and kildare_drum_params[d_voice] or kildare_fx_params[voice]
  for i = 1, #d do
    local destination = d[i]
    if destination.type ~= 'separator'
    and not destination.lfo_exclude
    and focus[scene_a][destination.id] ~= nil
    and focus[scene_b][destination.id] ~= nil
    and scene_a ~= scene_b then
      params:set(d_string..destination.id, util.linlin(-1,1,focus[scene_a][destination.id],focus[scene_b][destination.id],val))
    end
  end

  if val == -1 or val == 0 or val == 1 then
    -- focus.partial_restore = false
  end

  screen_dirty = true
  grid_dirty = true
  
end


function snapshot.route_funnel(voice,coll,mod_idx)
  print('route funnel', voice, coll)
  local focus;
  if type(voice) == 'number' and voice <= 10 then
    focus = hills[voice].snapshot
  else
    focus = snapshots[voice]
  end
  if mod_idx ~= 0 then
    if params:string('global_snapshot_mod_mode_'..mod_idx) == "free" then
      mod_idx = params:get('global_snapshot_mod_time_'..mod_idx)
    elseif params:string('global_snapshot_mod_mode_'..mod_idx) == "clocked" then
      mod_idx = clock.get_beat_sec() * params:get('global_snapshot_mod_beats_'..mod_idx)
    end
  end
  if mod_idx == 0 then
    if focus.partial_restore then
      clock.cancel(focus.fnl)
      snapshot.funnel_done_action(voice,coll)
    else
      snapshot.funnel_done_action(voice,coll)
    end
  else
    if focus.partial_restore then
      clock.cancel(focus.fnl)
    end
    focus.partial_restore = true

    local d_voice, d_string, original_srcs;
    if type(voice) ~= 'string' and voice <= 7 then
      d_voice = params:string('voice_model_'..voice)
      d_string = voice..'_'..d_voice..'_'
      original_srcs = _t.deep_copy(snapshots[voice][d_voice][coll])
    elseif type(voice) ~= 'string' and voice <= 10 then
      d_voice = 'sample'..voice-7
      d_string = d_voice..'_'
      original_srcs = _t.deep_copy(snapshots[voice][d_voice][coll])
    else
      original_srcs = _t.deep_copy(snapshots[voice][coll])
    end

    if type(voice) == 'number' and voice <= 10 then
      for i = 1, #kildare_drum_params[d_voice] do
        local d = kildare_drum_params[d_voice][i]
        if d.type ~= 'separator' and not d.lfo_exclude then
          original_srcs[d.id] = params:get(d_string..d.id)
        end
      end
    else
      -- delay, feedback, main
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
          for i = 1, #kildare_drum_params[d_voice] do
            local d = kildare_drum_params[d_voice][i]
            if d.type ~= 'separator' and not d.lfo_exclude and snapshots[voice][d_voice][coll][d.id] ~= nil then
              params:set(d_string..d.id, util.linlin(0,1,original_srcs[d.id],snapshots[voice][d_voice][coll][d.id],r_val))
            end
          end
        else
          for i = 1, #kildare_fx_params[voice] do
            local d = kildare_fx_params[voice][i]
            if d.type ~= 'separator' and not d.lfo_exclude and snapshots[voice][coll][d.id] ~= nil then
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
      {{1,mod_idx}},
      60
    )
  end
end

return snapshot