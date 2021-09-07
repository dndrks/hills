local actions = {}

actions.start = function(i,j,pass_clock)
  local h = hills[i]

  if h.active then
    h.active = false
  end

  h.segment = j
  local seg = h[j]

  seg.step = seg.note_timestamp[seg.low_bound.note] -- reset
  seg.high_bound.time = seg.note_timestamp[seg.high_bound.note]
  seg.index = seg.low_bound.note

  h.active = true

  if pass_clock then
    if hills[i][j].looper.mode == "clock" then
      if hills[i].looper.clock == nil then
        hills[i].looper.clock = clock.run(actions.clock_synced_loop,i,j)
      else
        _a.kill_clock(i)
        hills[i].looper.clock = clock.run(actions.clock_synced_loop,i,j)
      end
    else
      if hills[i].looper.clock ~= nil then
        _a.kill_clock(i)
      end
    end
  end
end

actions.clock_synced_loop = function(i,j)
  hills[i][j].looper.runner = 1
  while true do
    clock.sync(1/4)
    if hills[i][j].looper.runner == hills[i][j].looper.clock_time * 4 then
      hills[i][j].looper.runner = 1
      stop(i)
      actions.start(i,j)
    else
      hills[i][j].looper.runner = hills[i][j].looper.runner + 1
    end
  end
end

actions.kill_clock = function(i)
  clock.cancel(hills[i].looper.clock)
  hills[i].looper.clock = nil
end

return actions