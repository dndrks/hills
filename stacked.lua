-- straightforward seq

lattice = include("lib/latt")


r = function()
  norns.script.load("code/a/stacked.lua")
end

g = grid.connect() -- 'g' represents a connected grid

function init()

  main_lattice = lattice:new{
    ppqn = 64 -- allows us to go up to 1/32 division
  }
  pattern = {}
  restart_counter = {}
  for i = 1,4 do
    pattern[i] = main_lattice:new_pattern{
      action = function() iterate(i) end,
      division = 1/256
    }
    pattern[i].active = false
    pattern[i].restart_flag = false
    pattern[i].rec = false
    pattern[i].steps = {}
    pattern[i].steps.max = 1024 -- the largest a pattern can get
    pattern[i].steps.start_point = 1
    pattern[i].steps.end_point = 64 -- let's start with 64 steps
    pattern[i].steps.current = 1
    pattern[i].sub_steps = {}
    pattern[i].sub_steps.max = 16 -- 16 pulses per 1/16 step
    pattern[i].sub_steps.current = 1
    pattern[i].steps.active = {}
    for j = 1,64 do
      pattern[i].steps.active[j] = {}
      for k = 1,pattern[i].sub_steps.max do
        pattern[i].steps.active[j][k] = {}
        pattern[i].steps.active[j][k].active = false
        pattern[i].steps.active[j][k].silent = false
      end
    end
  end
  grid_dirty = true
  clock.run(grid_redraw_clock)
end

function clock.transport.start()
  if params:string("clock_source") == "link" then
    clock.run(function()
      clock.sync(4)
      transport_start()
    end)
  end
end

function clock.transport.stop()
  transport_stop()
end

function transport_start()
  for i = 1,4 do
    pattern[i].active = true
  end
  main_lattice:hard_sync()
end

function transport_stop()
  for i = 1,4 do
    pattern[i].active = false
    pattern[i].steps.current = pattern[i].steps.start_point
    pattern[i].sub_steps.current = 1
  end
end

function iterate(i)
  if pattern[i].active then
    local current_sub = pattern[i].sub_steps.current
    local current_step = pattern[i].steps.current
    if pattern[i].steps.active[current_step][current_sub].active then
      if not pattern[i].steps.active[current_step][current_sub].silent then
        print(clock.get_beats(),current_step,current_sub)
      end
    end
    if pattern[i].steps.active[current_step][current_sub].silent then
      pattern[i].steps.active[current_step][current_sub].silent = false
    end
    pattern[i].sub_steps.current = pattern[i].sub_steps.current + 1
    grid_dirty = true
    if pattern[i].sub_steps.current > pattern[i].sub_steps.max then
      pattern[i].sub_steps.current = 1
      pattern[i].steps.current = pattern[i].steps.current + 1
    end
    if pattern[i].steps.current > pattern[i].steps.end_point then
      pattern[i].steps.current = pattern[i].steps.start_point
    end
  end
end

function restart_pattern(i)
  clock.run(function()
    clock.sync(0.25)
    pattern[i].sub_steps.current = 1
    pattern[i].steps.current = pattern[i].steps.start_point
    iterate(i)
    pattern[i].active = true
  end)
end

function record_event(i,event)
  local current_sub = pattern[i].sub_steps.current
  local current_step = pattern[i].steps.current
  print(current_step,current_sub)
  pattern[i].steps.active[current_step][current_sub].active = true
  pattern[i].steps.active[current_step][current_sub].silent = true
end

function grid_redraw_clock() -- our grid redraw clock
  while true do -- while it's running...
    clock.sleep(1/30) -- refresh at 30fps.
    if grid_dirty then -- if a redraw is needed...
      grid_redraw() -- redraw...
      grid_dirty = false -- then redraw is no longer needed.
    end
  end
end

function grid_redraw() -- how we redraw
  g:all(0) -- turn off all the LEDs
  local current_sub = pattern[1].sub_steps.current
  local current_step = pattern[1].steps.current
  local row;
  if pattern[1].steps.current < 17 then
    row = 1
  elseif pattern[1].steps.current < 33 then
    row = 2
  elseif pattern[1].steps.current < 49 then
    row = 3
  else
    row = 4
  end
  for i = 1,16 do
    for j = 1,4 do
      g:led(i,j,pattern[1].steps.active[current_step][current_sub].active == true and 15 or 3) -- light this coordinate at indicated brightness
    end
  end
  g:led(util.wrap(pattern[1].steps.current,1,16),row,15) -- light this coordinate at indicated brightness
  g:refresh() -- refresh the hardware to display the new LED selection
end

function g.key(x,y,z) -- define what happens if a grid key is pressed or released
  if z==1 then -- if a grid key is pressed down...
    show.x = x -- update stored x position to selected x position
    show.y = y -- update stored y position to selected y position
    grid_dirty = true -- flag for a redraw
  end
end