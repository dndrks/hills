local grid_lib = {}

g = grid.connect()

function grid_lib.init()
  clock.run(function()
    while true do
      clock.sleep(1/15)
      if grid_dirty then
        grid_redraw()
      end
    end
  end)
end

function g.key(x,y,z)
  if x > 1 and x <= 5 then
    if z == 1 then
      _a.one_shot(x-1,y)
      hills[x-1].screen_focus = y
      screen_dirty = true
    end
  end
end

function grid_redraw()
  g:all(0)
  
  g:refresh()
end

return grid_lib