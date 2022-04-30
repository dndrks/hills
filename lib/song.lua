local song = {}

song.init = function()
  song_atoms = {}
  for i = 1,4 do
    song_atoms[i] = {}
    song_atoms[i].lane = {}
    for j = 1,1 do
      song_atoms[i].lane[j] = {["arp"] = {}, ["grid"] = {}, ["euclid"] = {}, ["snapshot"] = {}}
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
end

song.iterate = function()
  while true do
    clock.sync(1,-1/64)
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
  for k,v in pairs(song_atoms[i].lane[_current]) do
    if k == "arp" and song_atoms[i].runner == 1 then
      local shot = song_atoms[i].lane[_current][k].target
      if shot > 0 and tab.count(grid_pattern[i].event) > 1 then
        print("would launch pattern")
        -- TODO: will need to know what pattern played last and cancel it, otherwise can just roll.
        -- style = track[i].snapshot.restore_times.mode
        -- _snap.restore(i,shot,modifier,style)
        
      elseif shot == 0 then
      elseif shot == -1 then
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
  -- should probably kill running patterns...
end

song.add_line = function(b,loc)
  table.insert(song_atoms[b].lane,loc+1,{["arp"] = {}, ["grid"] = {}, ["euclid"] = {}, ["snapshot"] = {}})
  for k,v in pairs(song_atoms[b].lane[loc+1]) do
    song_atoms[b].lane[loc+1][k].target = 0
  end
  song_atoms[b].lane[loc+1].beats = 16
  song_atoms[b].lane[loc+1].snapshot_restore_mod_index = 0
  song_atoms[b].end_point = #song_atoms[b].lane
end

song.duplicate_line = function(b,loc)
  table.insert(song_atoms[b].lane,loc+1,{["arp"] = {}, ["grid"] = {}, ["euclid"] = {}, ["snapshot"] = {}})
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
    if page.flow.song_line[page.flow.voice] > song_atoms[b].end_point then
      page.flow.song_line[page.flow.voice] = song_atoms[b].end_point
    end
    if song_atoms[b].current > song_atoms[b].end_point then
      song_atoms[b].runner = 0
      song_atoms[b].current = song_atoms[b].start_point
    end
  end
end

song.save = function(collection)
  for i = 1,4 do
    tab.save(song_atoms[i],_path.data .. "cheat_codes_yellow/collection-"..collection.."/song/"..i..".data")
  end
end

song.load = function(collection)
  for i = 1,4 do
    song_atoms[i] = tab.load(_path.data .. "cheat_codes_yellow/collection-"..collection.."/song/"..i..".data")
  end
end

return song