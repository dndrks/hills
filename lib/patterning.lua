local patterning = {}

lattice = include("lib/hillattice")


function patterning.init()

  main_lattice = lattice:new{
    ppqn = 8 -- allows us to go up to 1/32 division
  }
  pattern = {}
  restart_counter = {}
  for i = 1,4 do
    pattern[i] = main_lattice:new_pattern{
      action = function() patterning.iterate(i) end,
      division = 1/16
    }
    pattern[i].active = false
    pattern[i].restart_flag = false
    pattern[i].steps = {}
    pattern[i].steps.max = 1024 -- the largest a pattern can get
    pattern[i].steps.start_point = 1
    pattern[i].steps.end_point = 64 -- let's start with 64 steps
    pattern[i].steps.current = 1
    pattern[i].steps.active = {}
    pattern[i].steps.event = {}
    for j = 1,1024 do
      pattern[i].steps.active[j] = false
      pattern[i].steps.event[j] = 0
    end

  end
end

function clock.transport.start()
  if params:string("clock_source") == "link" then
    clock.run(function()
      clock.sync(4)
      patterning.transport_start()
    end)
  end
end

function clock.transport.stop()
  patterning.transport_stop()
end

function patterning.transport_start()
  for i = 1,4 do
    pattern[i].active = true
  end
  main_lattice:hard_sync()
end

function patterning.transport_stop()
  for i = 1,4 do
    pattern[i].active = false
    pattern[i].steps.current = pattern[i].steps.start_point
  end
end

function patterning.iterate(i)
  if pattern[i].active then
    local current = pattern[i].steps.current
    if pattern[i].steps.active[current] and pattern[i].steps.event[current] ~= 0  then
      print(clock.get_beats(),current)
      _a.one_shot(i,pattern[i].steps.event[current])
    end
    pattern[i].steps.current = pattern[i].steps.current + 1
    if pattern[i].steps.current > pattern[i].steps.end_point then
      pattern[i].steps.current = pattern[i].steps.start_point
    end
    screen_dirty = true
  end
end

function patterning.restart_pattern(i)
  clock.run(function()
    clock.sync(0.25)
    pattern[i].steps.current = pattern[i].steps.start_point
    patterning.iterate(i)
    pattern[i].active = true
  end)
end

function patterning.record_event(i,event) -- expects 
  -- local current_sub = pattern[i].sub_steps.current
  local current_step = pattern[i].steps.current
  print(current_step,current_sub)
  pattern[i].steps.active[current_step] = true
  pattern[i].steps.event[current_step] = event
  -- pattern[i].steps.active[current_step].silent = true
end

function patterning.delta_note(i,j,state,delta)
  pattern[i].steps.event[j] = util.clamp(pattern[i].steps.event[j]+delta,0,8)
  pattern[i].steps.active[j] = state
end

function patterning.enter_note(i,j,state,val)
  pattern[i].steps.active[j] = state
  pattern[i].steps.event[j] = val
end

function patterning.get_note(i,j)
  return pattern[i].steps.event[j]
end

function patterning.get_state(i,j)
  return pattern[i].steps.state[j]
end

return patterning