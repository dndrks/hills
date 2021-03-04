local draw = {}

draw.init = function()
  shape_data = {}
  for i = 1,8 do
    shape_data[i] = {}
    for j = 1,8 do
      shape_data[i][j] = {}
    end
  end
end

draw.build = function(i,j)
  local h = hills[i]
  local seg = h[j]
  for k = 1,60 do
    shape_data[i][j][k] = util.round(util.wrap_max(curves[seg.shape](k,1,59,60),1,60))
  end
end

return draw