local snapshot = {}

function snapshot.init()
  selected_snapshot = {}
  snapshots = {}
  for i = 1,number_of_hills do
    snapshots[i] = {}
  end
  for j = 1,#kildare_drums do
    for coll = 1,8 do
      snapshots[j][coll] = {}
    end
  end
  for j = 1,3 do
    for coll = 1,8 do
      snapshots[7+j][coll] = {}
    end
  end
  snapshots.mod = {["index"] = 0, ["held"] = {false,false,false,false,false,false}}
  softcut_params = {
    "speed_clip_",
    "semitone_offset_",
    "vol_clip_",
    "pan_clip_",
    "post_filter_fc_",
    "post_filter_lp_",
    "post_filter_hp_",
    "post_filter_bp_",
    "post_filter_dry_",
    "post_filter_rq_"
  }
  softcut_lfo_ids = {["vol_clip_"] = {1,2,3}, ["pan_clip_"] = {4,5,6}, ["post_filter_fc_"] = {7,8,9}}
end

function snapshot.pack(voice,coll)
  if voice <= 7 then
    local d_voice = kildare_drums[voice]
    for i = 1, #kildare_drum_params[d_voice] do
      local d = kildare_drum_params[d_voice][i]
      if d.type ~= 'separator' then
        snapshots[voice][coll][d.id] = params:get(d_voice.."_"..d.id)
      end
    end
  else
    local sc_target = voice - 7
    for i = 1,#softcut_params do
      snapshots[voice][coll][softcut_params[i]..sc_target] = params:get(softcut_params[i]..sc_target)
    end
  end
  -- do i want other hill params? or just synthesis snapshots?
  -- snapshots[voice][coll].kildare_notes = params:get("hill "..voice.." kildare_notes")
  -- TODO: ADD LFOS
  selected_snapshot[voice] = coll
end

function snapshot.seed_restore_state_to_all(voice,coll,_p)

end

function snapshot.unpack(voice, coll)
  if hills[voice].snapshot.partial_restore then
    clock.cancel(hills[voice].snapshot.fnl)
    print("partial restore unpack",voice,coll)
    hills[voice].snapshot.partial_restore = false
  end

  if voice <= 7 then
    local d_voice = kildare_drums[voice]
    for i = 1, #kildare_drum_params[d_voice] do
      local d = kildare_drum_params[d_voice][i]
      if d.type ~= 'separator' then
        params:set(d_voice.."_"..d.id, snapshots[voice][coll][d.id])
      end
    end
  else
    local sc_target = voice - 7
    for i = 1,#softcut_params do
      params:set(softcut_params[i]..sc_target, snapshots[voice][coll][softcut_params[i]..sc_target])
    end
  end

  print("restored snapshot", voice, coll)

  -- TODO: ADD OPTIONAL SHIT?
  
  screen_dirty = true
  grid_dirty = true
  selected_snapshot[voice] = coll
end

function snapshot.save_to_slot(_t,slot)
  clock.sleep(0.25)
  hills[_t].snapshot.saver_active = true
  if hills[_t].snapshot.saver_active then
    if not mods.alt then
      snapshot.pack(_t,slot)
    else
      snapshot.clear(_t,slot)
    end
    grid_dirty = true
  end
  hills[_t].snapshot.saver_active = false
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
  print("snapshot funnel done",voice,coll)
  snapshot.unpack(voice, coll)
  if hills[voice].snapshot.partial_restore then
    hills[voice].snapshot.partial_restore = false
  end
end


function snapshot.route_funnel(voice,coll,sec,style)
  if style ~= nil then
    if style == "beats" then
      sec = clock.get_beat_sec()*sec
    elseif style == "time" then
      sec = sec
    end
  end
  if sec == 0 then
    if hills[voice].snapshot.partial_restore then
      clock.cancel(hills[voice].snapshot.fnl)
      print("partial restore try_it",voice,coll)
      snapshot.funnel_done_action(voice,coll)
    else
      snapshot.funnel_done_action(voice,coll)
    end
  else
    print("doing try it for "..voice)
    if hills[voice].snapshot.partial_restore then
      clock.cancel(hills[voice].snapshot.fnl)
      print("interrupted, canceling previous journey")
    end
    hills[voice].snapshot.partial_restore = true

    local original_srcs = _t.deep_copy(snapshots[voice][coll])

    if voice <=7 then
      local d_voice = kildare_drums[voice]
      for i = 1, #kildare_drum_params[d_voice] do
        local d = kildare_drum_params[d_voice][i]
        if d.type ~= 'separator' then
          original_srcs[d.id] = params:get(d_voice.."_"..d.id)
        end
      end
    else
      local sc_target = voice - 7
      for i = 1,#softcut_params do
        original_srcs[softcut_params[i]..sc_target] = params:get(softcut_params[i]..sc_target)
      end
    end
    
    hills[voice].snapshot.fnl = snapshot.fnl(
      function(r_val)
        hills[voice].snapshot.current_value = r_val

        if voice <=7 then
          local d_voice = kildare_drums[voice]
          for i = 1, #kildare_drum_params[d_voice] do
            local d = kildare_drum_params[d_voice][i]
            if d.type ~= 'separator' then
              params:set(d_voice.."_"..d.id, util.linlin(0,1,original_srcs[d.id],snapshots[voice][coll][d.id],r_val))
            end
          end
        else
          local sc_target = voice - 7
          for i = 1,#softcut_params do
            if softcut_params[i] == "vol_clip_" or softcut_params[i] == "pan_clip_" or softcut_params[i] == "post_filter_fc_" then
              if params:string("lfo_"..softcut_params[i]..softcut_lfo_ids[softcut_params[i]][sc_target]) == "off" then
                params:set(softcut_params[i]..sc_target, util.linlin(0,1,original_srcs[softcut_params[i]..sc_target],snapshots[voice][coll][softcut_params[i]..sc_target],r_val))
              end
            else
              params:set(softcut_params[i]..sc_target, util.linlin(0,1,original_srcs[softcut_params[i]..sc_target],snapshots[voice][coll][softcut_params[i]..sc_target],r_val))
            end
          end
        end

        screen_dirty = true
        grid_dirty = true
        if hills[voice].snapshot.current_value ~= nil and util.round(hills[voice].snapshot.current_value,0.001) == 1 then
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