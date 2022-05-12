local snapshot = {}

function snapshot.init()
  selected_snapshot = {}
  snapshots = {{},{},{},{},{},{},{}}
  for j = 1,#kildare_drums do
    local d_voice = kildare_drums[j]
    for coll = 1,8 do
      snapshots[j][coll] = {}
    end
  end
  snapshots.mod = {["index"] = 0, ["held"] = {false,false,false,false,false,false}}
end

function snapshot.pack(voice,coll)
  local d_voice = kildare_drums[voice]
  for i = 1, #kildare_drum_params[d_voice] do
    local d = kildare_drum_params[d_voice][i]
    if d.type ~= 'separator' then
      snapshots[voice][coll][d.id] = params:get(d_voice.."_"..d.id)
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

  local d_voice = kildare_drums[voice]
  for i = 1, #kildare_drum_params[d_voice] do
    local d = kildare_drum_params[d_voice][i]
    if d.type ~= 'separator' then
      params:set(d_voice.."_"..d.id, snapshots[voice][coll][d.id])
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
  if hills[voice].snapshot.partial_restore then
    clock.cancel(hills[voice].snapshot.fnl)
    print("partial restore try_it",voice,coll)
    snapshot.funnel_done_action(voice,coll)
  end
  print("doing try it for "..voice)
  hills[voice].snapshot.partial_restore = true
  if style ~= nil then
    if style == "beats" then
      sec = clock.get_beat_sec()*sec
    elseif style == "time" then
      sec = sec
    end
  end

  local original_srcs = _t.deep_copy(snapshots[voice][coll])
  local d_voice = kildare_drums[voice]
  for i = 1, #kildare_drum_params[d_voice] do
    local d = kildare_drum_params[d_voice][i]
    if d.type ~= 'separator' then
      original_srcs[d.id] = params:get(d_voice.."_"..d.id)
    end
  end
  
  hills[voice].snapshot.fnl = snapshot.fnl(
    function(r_val)
      hills[voice].snapshot.current_value = r_val

      local d_voice = kildare_drums[voice]
      for i = 1, #kildare_drum_params[d_voice] do
        local d = kildare_drum_params[d_voice][i]
        if d.type ~= 'separator' then
          params:set(d_voice.."_"..d.id, util.linlin(0,1,original_srcs[d.id],snapshots[voice][coll][d.id],r_val))
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

return snapshot