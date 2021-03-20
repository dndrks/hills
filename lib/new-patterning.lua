local patterning = {}

lattice = include("lib/hillattice")

function dev()
  pattern[1].steps.A[1] = 9
  pattern[1].steps.B[1] = 7
  pattern[1].steps.end_point = 16
  pattern[1].steps.event[1] = 1
  pattern[1].steps.active[1] = true
  patterning.transport_start()
end


function patterning.init()

  main_lattice = lattice:new{
    -- ppqn = 64 -- allows us to go up to 1/256 division
    ppqn = 32 -- allows us to go up to 1/128 division
  }
  pattern = {}
  restart_counter = {}
  for i = 1,4 do
    pattern[i] = main_lattice:new_pattern{
      action = function() patterning.iterate(i) end,
      -- division = 1/256 -- this allows the sub_steps to run 16 = 16ths
      division = 1/128 -- this allows the sub_steps to run 8 = 16ths
    }
    pattern[i].active = false
    pattern[i].restart_flag = false
    pattern[i].steps = {}
    pattern[i].steps.max = 1024 -- the largest a pattern can get
    pattern[i].steps.start_point = 1
    pattern[i].steps.end_point = 64 -- let's start with 64 steps
    pattern[i].steps.current = 1
    pattern[i].sub_steps = {}
    pattern[i].sub_steps.max = {}
    pattern[i].sub_steps.current = 1
    pattern[i].steps.active = {}
    pattern[i].steps.event = {}
    pattern[i].steps.probability = {}
    pattern[i].steps.cycle = 1 -- to keep track of cycles for conditionals
    pattern[i].steps.A = {} -- base, so when is the first time it's true?
    pattern[i].steps.B = {} -- scale, so how many until it's true again?
    -- 4:7 = true 4th, 11th, 18th
    for j = 1,1024 do
      pattern[i].steps.active[j] = false
      pattern[i].steps.event[j] = 0
      pattern[i].steps.probability[j] = 100
      pattern[i].steps.A[j] = 1
      pattern[i].steps.B[j] = 1
      -- pattern[i].sub_steps.max[j] = 16 -- 16 pulses per step
      pattern[i].sub_steps.max[j] = 8 -- 8 pulses per step
    end

    pattern[i].queued_rate = nil

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
    pattern[i].sub_steps.current = 1
  end
end

-- ok, so i definitely want to do 

function patterning.iterate(i)
  if pattern[i].active then
    local current_sub = pattern[i].sub_steps.current
    local current_step = pattern[i].steps.current
    if pattern[i].steps.active[current_step] and pattern[i].steps.event[current_step] ~= 0 and current_sub == 1 then
      if patterning.check_probability(i,current_step) then
        if pattern[i].steps.cycle < pattern[i].steps.A[current_step] then
          -- keep going...
        elseif pattern[i].steps.cycle == pattern[i].steps.A[current_step] then
          -- play the step
          print(clock.get_beats(),current_step)
          _a.one_shot(i,pattern[i].steps.event[current_step])
          print("first "..pattern[i].steps.cycle)
        elseif pattern[i].steps.cycle > pattern[i].steps.A[current_step] then
          -- if A = 2 and B = 6 then...
          -- on cycle == 2
          -- on cycle == 8
          -- on cycle == 14
          if pattern[i].steps.cycle <= (pattern[i].steps.A[current_step] + pattern[i].steps.B[current_step]) then
            if pattern[i].steps.cycle % (pattern[i].steps.A[current_step] + pattern[i].steps.B[current_step]) == 0 then
              print(clock.get_beats(),current_step)
              _a.one_shot(i,pattern[i].steps.event[current_step])
              print("second "..pattern[i].steps.cycle)
            end
          else
            if (pattern[i].steps.cycle - pattern[i].steps.A[current_step]) % pattern[i].steps.B[current_step] == 0 then
              print(clock.get_beats(),current_step)
              _a.one_shot(i,pattern[i].steps.event[current_step])
              print("..."..pattern[i].steps.cycle)
            end
          end
        end
      end
    end
    if current_sub == 1 then
      patterning.check_rate_queue(i)
    end
    pattern[i].sub_steps.current = pattern[i].sub_steps.current + 1
    screen_dirty = true
    if pattern[i].sub_steps.current > pattern[i].sub_steps.max[current_step] then
      pattern[i].sub_steps.current = 1
      pattern[i].steps.current = pattern[i].steps.current + 1
    end
    if pattern[i].steps.current > pattern[i].steps.end_point then
      pattern[i].steps.current = pattern[i].steps.start_point
      pattern[i].steps.cycle = pattern[i].steps.cycle + 1
    end
  end
end

function patterning.check_rate_queue(i)
  if pattern[i].queued_rate ~= nil then
    pattern[i].division = pattern[i].queued_rate * (1/16)
    pattern[i].sub_steps.current = 1
    pattern[i].phase = 1
    pattern[i].queued_rate = nil
  end
end

function patterning.change_all_rates(i,rate)
  local rates =
  {
    [1/16] = 8
  }
  for j = 1,1024 do
    pattern[i].sub_steps.max[j] = nil
  end
end

function patterning.restart_pattern(i)
  clock.run(function()
    clock.sync(0.25)
    pattern[i].sub_steps.current = 1
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

function patterning.delta_probability(i,j,delta,all)
  pattern[i].steps.probability[j] = util.clamp(pattern[i].steps.probability[j]+delta,0,100)
  if all then
    for k = 1,1024 do
      if k ~= j then
        pattern[i].steps.probability[k] = pattern[i].steps.probability[j]
      end
    end
  end
end

function patterning.check_probability(i,j)
  if pattern[i].steps.probability[j] == 100 or math.random(1,100) <= pattern[i].steps.probability[j] then
    return true
  else
    return false
  end
end

function patterning.delta_conditional(i,j,target,delta,all)
  pattern[i].steps[target][j] = util.clamp(pattern[i].steps[target][j]+delta,1,8)
  if all then
    for k = 1,1024 do
      if k ~= j then
        pattern[i].steps[target][k] = pattern[i].steps[target][j]
      end
    end
  end
end

function patterning.get_mod(i,j)
  local mod_table = {}
  if pattern[i].steps.probability[j] ~= 100 then
    table.insert(mod_table,"*P")
  end
  if pattern[i].steps.A[j] ~= 1 or pattern[i].steps.B[j] ~= 1 then
    table.insert(mod_table,"*A:B")
  end
  return mod_table
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