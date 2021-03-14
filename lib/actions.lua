local actions = {}

actions.one_shot = function(i,j)
  local h = hills[i]

  if h.counter.is_running then
    h.counter:stop()
  end

  h.segment = j
  local seg = h[j]

  seg.step = seg.note_timestamp[seg.low_bound.note] -- reset
  seg.high_bound.time = seg.note_timestamp[seg.high_bound.note]
  seg.index = seg.low_bound.note
  h.counter.time = seg.counter_time
  h.counter:start()

  h.active = true
end

return actions