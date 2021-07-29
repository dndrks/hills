local grid_lib = {}
local grid = util.file_exists(_path.code.."midigrid") and include "midigrid/lib/midigrid" or grid

g = grid.connect()

function grid_lib.init()
  clock.run(function()
    while true do
      clock.sleep(1/15)
      if grid_dirty then
        grid_redraw()
        grid_dirty = false
        for i = 1,4 do
          for j = 1,8 do
            if hills[i][j].perf_led then
              hills[i][j].perf_led = false
            end
          end
        end
      end
    end
  end)
  grid_dirty = true
end

function g.key(x,y,z)
  if x > 1 and x <= 5 then
    if z == 1 then
      _a.one_shot(x-1,y)
      hills[x-1].screen_focus = y
      screen_dirty = true
      hills[x-1][y].perf_led = true
      grid_dirty = true
    end
  end
end

function grid_redraw()
  g:all(0)
  for i = 2,5 do
    for j = 1,8 do
      if hills[i-1].segment == j then
        g:led(i,j,hills[i-1][j].perf_led and 15 or (hills[i-1][j].iterated and 6 or 8))
      else
        g:led(i,j,4)
      end
    end
  end
  g:refresh()
end

return grid_lib