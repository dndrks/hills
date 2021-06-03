local actions = {}

actions.one_shot = function(i,j)
  local h = hills[i]

  if h.active then
    h.active = false
  end

  h.segment = j
  local seg = h[j]

  seg.step = seg.note_timestamp[seg.low_bound.note] -- reset
  seg.high_bound.time = seg.note_timestamp[seg.high_bound.note]
  seg.index = seg.low_bound.note
  -- h.counter.time = 0.01/seg.counter_div -- TODO make this just a multiplier for the lengths...
  -- h.counter:start()

  h.active = true
end

return actions