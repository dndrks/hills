local song = {}

song.init = function()
  song_atoms = {}
  for i = 1,4 do
    song_atoms[i] = {}
    song_atoms[i].lane = {}
    for j = 1,1 do
      song_atoms[i].lane[j] = { {}, {}, {}, {}}
      for k,v in pairs(song_atoms[i].lane[j]) do
        song_atoms[i].lane[j][k].target = 0
      end
      song_atoms[i].lane[j].beats = 16
      song_atoms[i].lane[j].snapshot_restore_mod_index = 0
    end
    song_atoms[i].start_point = 1
    song_atoms[i].end_point = 1
    song_atoms[i].current = 1
    song_atoms[i].runner = 0
    song_atoms[i].active = true
  end
  song_atoms.clock = nil
  song_atoms.transport_clock = nil
  song_atoms.transport_active = false
end

song.iterate = function()
  while true do
    -- clock.sync(1,-1/64)
    clock.sync(1/4)
    for i = 1,4 do
      if song_atoms[i].active then
        local _current = song_atoms[i].current
        if song_atoms[i].runner == song_atoms[i].lane[_current].beats then
          song_atoms[i].current = util.wrap(song_atoms[i].current + 1,song_atoms[i].start_point,song_atoms[i].end_point)
          song_atoms[i].runner = 0
        end
        _current = song_atoms[i].current
        song_atoms[i].runner = util.wrap(song_atoms[i].runner + 1,1,song_atoms[i].lane[_current].beats)
        song.check_step(i)
      end
    end
  end
end

song.check_step = function(i)
  local _current = song_atoms[i].current
  -- for k,v in pairs(song_atoms[i].lane[_current]) do
  for j = 1,4 do
    -- if k == 1 and song_atoms[i].runner == 1 then
    if song_atoms[i].runner == 1 then
      local shot = song_atoms[i].lane[_current][j].target
      if shot > 0 and shot <= 16 then
        if tab.count(grid_pattern[shot].event) > 1 and grid_pattern[shot].rec == 0 then
          if grid_pattern[shot].play == 0 then
            grid_pattern[shot]:start()
          else
            _g.stop_pattern_playback(shot)
            grid_pattern[shot]:start()
          end
        end
      elseif shot >= 17 and shot <= 24 then
        for k = 1,10 do
          if hills[k].highway then
            _htracks.stop_playback(k)
            track[k].active_hill = shot - 16
            _htracks.start_playback(k)
            if k == 1 then
              print(clock.get_beats())
            end
          end
        end
      elseif shot == 0 then
      elseif shot == -1 then
        for k = _current,1,-1 do
          if k ~= current and song_atoms[i].lane[k][j].target > 0 then
            if grid_pattern[song_atoms[i].lane[k][j].target].play == 1 then
              _g.stop_pattern_playback(song_atoms[i].lane[k][j].target)
              break
            end
          end
        end
      end
    end
  end
  screen_dirty = true
end

song.start = function()
  if song_atoms.clock ~= nil then
    clock.cancel(song_atoms.clock)
  end
  for i = 1,4 do
    song_atoms[i].runner = 1
    song_atoms[i].current = song_atoms[i].start_point
  end
  song_atoms.clock = clock.run(song.iterate)
  song_atoms.running = true
  for i = 1,4 do
    song.check_step(i)
  end

  if params:string('global_transport_mode') == 'highways' then
    for i = 1,10 do
      if hills[i].highway then
        _htracks.start_playback(i)
      end
    end
  end
  screen_dirty = true
  grid_dirty = true
end

song.stop = function()
  if song_atoms.clock ~= nil then
    clock.cancel(song_atoms.clock)
  end
  song_atoms.running = false
  for i = 1,4 do
    song_atoms[i].runner = 1
    -- song_atoms[i].current = song_atoms[i].start_point
  end
  for i = 1,16 do
    if grid_pattern[i].play == 1 then
      _g.stop_pattern_playback(i)
    end
  end
  for i = 1,10 do
    _htracks.stop_playback(i)
  end
  screen_dirty = true
  grid_dirty = true
  -- should probably kill running patterns...
end

function clock.transport.start()
  if params:string("clock_source") ~= "midi" then
    if song_atoms.transport_clock == nil then
      song_atoms.transport_clock = clock.run(
        function()
          clock.sync(params:get('link_quantum'))
          song.start()
        end
      )
    end
  else
    song.start()
  end
  song_atoms.transport_active = true
end

function clock.transport.stop()
  if song_atoms.transport_clock ~= nil then
    clock.cancel(song_atoms.transport_clock)
    song_atoms.transport_clock = nil
  end
  song.stop()
  song_atoms.transport_active = false
end

song.add_line = function(b,loc)
  table.insert(song_atoms[b].lane, loc+1, {{}, {}, {}, {}})
  for k,v in pairs(song_atoms[b].lane[loc+1]) do
    song_atoms[b].lane[loc+1][k].target = 0
  end
  song_atoms[b].lane[loc+1].beats = 16
  song_atoms[b].lane[loc+1].snapshot_restore_mod_index = 0
  song_atoms[b].end_point = #song_atoms[b].lane
end

song.duplicate_line = function(b,loc)
  table.insert(song_atoms[b].lane,loc+1,{{}, {}, {}, {}})
  for k,v in pairs(song_atoms[b].lane[loc+1]) do
    song_atoms[b].lane[loc+1][k].target = song_atoms[b].lane[loc][k].target
  end
  song_atoms[b].lane[loc+1].beats = song_atoms[b].lane[loc].beats
  song_atoms[b].lane[loc+1].snapshot_restore_mod_index = song_atoms[b].lane[loc].snapshot_restore_mod_index
  song_atoms[b].end_point = #song_atoms[b].lane
end

song.remove_line = function(b,loc)
  if #song_atoms[b].lane ~= 1 then
    table.remove(song_atoms[b].lane,loc)
    song_atoms[b].end_point = util.clamp(song_atoms[b].end_point-1,1,128)
    if page.flow.song_line[page.flow.group] > song_atoms[b].end_point then
      page.flow.song_line[page.flow.group] = song_atoms[b].end_point
    end
    if song_atoms[b].current > song_atoms[b].end_point then
      song_atoms[b].runner = 0
      song_atoms[b].current = song_atoms[b].start_point
    end
  end
end

song.save = function(collection)
  for i = 1,#song_atoms do
    tab.save(song_atoms[i],_path.data .. "cheat_codes_yellow/collection-"..collection.."/song/"..i..".data")
  end
end

song.load = function(collection)
  for i = 1,#song_atoms do
    song_atoms[i] = tab.load(_path.data .. "cheat_codes_yellow/collection-"..collection.."/song/"..i..".data")
  end
end

return song