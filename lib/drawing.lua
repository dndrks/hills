local draw = {}

draw.init = function()
  shape_data = {}
  for i = 1,8 do
    shape_data[i] = {}
    for j = 1,8 do
      shape_data[i][j] = {}
      shape_data[i][j].index = 0
      shape_data[i][j].notes = {}
      shape_data[i][j].timing = {}
      shape_data[i][j].notes_destroy = false
    end
  end
end

draw.build = function(i,j)
  -- local h = hills[i]
  -- local seg = h[j]
  -- seg.change_lock = true
  -- local pre_change = seg.current_val
  -- local midi_notes = h.notes
  -- local total_notes = util.round(#midi_notes*seg.population)
  -- for k = 1,100*seg.eject do
  --   shape_data[i][j][k] = util.wrap(curves[seg.shape](k,1,total_notes-1,100*seg.eject),seg.min,seg.max)
  -- end
end

return draw