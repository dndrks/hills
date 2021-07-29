local rec_patterning = {}

function dev()
  step_seq[1].steps.A[1] = 9
  step_seq[1].steps.B[1] = 7
  step_seq[1].steps.end_point = 16
  step_seq[1].steps.event[1] = 1
  step_seq[1].steps.active[1] = true
  patterning.transport_start()
end


function patterning.init()

  main_lattice = lattice:new{
    -- ppqn = 64 -- allows us to go up to 1/256 division
    ppqn = 32 -- allows us to go up to 1/128 division
  }
  step_seq = {}
  restart_counter = {}
  pattern_focus = {}
  for i = 1,4 do
    step_seq[i] = main_lattice:new_pattern{
      action = function() patterning.iterate(i) end,
      -- division = 1/256 -- this allows the sub_steps to run 16 = 16ths
      division = 1/128 -- this allows the sub_steps to run 8 = 16ths
    }
    step_seq[i].active = false
    step_seq[i].chunks = {{1,16},{17,32},{33,48},{49,64}}
    step_seq[i].active_chunk = 1
    step_seq[i].restart_flag = false
    step_seq[i].steps = {}
    step_seq[i].steps.max = 1024 -- the largest a step_seq can get
    step_seq[i].steps.start_point = step_seq[i].chunks[step_seq[i].active_chunk][1]
    step_seq[i].steps.end_point = step_seq[i].chunks[step_seq[i].active_chunk][2] -- let's start with 16 steps
    step_seq[i].steps.current = 1
    step_seq[i].sub_steps = {}
    step_seq[i].sub_steps.max = {}
    step_seq[i].sub_steps.current = 1
    step_seq[i].steps.active = {}
    step_seq[i].steps.event = {}
    step_seq[i].steps.probability = {}
    step_seq[i].steps.cycle = 1 -- to keep track of cycles for conditionals
    step_seq[i].steps.A = {} -- base, so when is the first time it's true?
    step_seq[i].steps.B = {} -- scale, so how many until it's true again?
    -- 4:7 = true 4th, 11th, 18th
    for j = 1,1024 do
      step_seq[i].steps.active[j] = false
      step_seq[i].steps.event[j] = 0
      step_seq[i].steps.probability[j] = 100
      step_seq[i].steps.A[j] = 1
      step_seq[i].steps.B[j] = 1
      -- step_seq[i].sub_steps.max[j] = 16 -- 16 pulses per step
      step_seq[i].sub_steps.max[j] = 8 -- 8 pulses per step
    end

    step_seq[i].queued_rate = nil
    pattern_focus[i] = "s1"
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
    step_seq[i].active = true
  end
  main_lattice:hard_sync()
end

function patterning.transport_stop()
  for i = 1,4 do
    step_seq[i].active = false
    step_seq[i].steps.current = step_seq[i].steps.start_point
    step_seq[i].sub_steps.current = 1
  end
end

-- ok, so i definitely want to do 

function patterning.iterate(i)
  if step_seq[i].active then
    local current_sub = step_seq[i].sub_steps.current
    local current_step = step_seq[i].steps.current
    if step_seq[i].steps.active[current_step] and step_seq[i].steps.event[current_step] ~= 0 and current_sub == 1 then
      if patterning.check_probability(i,current_step) then
        if step_seq[i].steps.cycle < step_seq[i].steps.A[current_step] then
          -- keep going...
        elseif step_seq[i].steps.cycle == step_seq[i].steps.A[current_step] then
          -- play the step
          print(clock.get_beats(),current_step)
          _a.one_shot(i,step_seq[i].steps.event[current_step])
          print("first "..step_seq[i].steps.cycle)
        elseif step_seq[i].steps.cycle > step_seq[i].steps.A[current_step] then
          -- if A = 2 and B = 6 then...
          -- on cycle == 2
          -- on cycle == 8
          -- on cycle == 14
          if step_seq[i].steps.cycle <= (step_seq[i].steps.A[current_step] + step_seq[i].steps.B[current_step]) then
            if step_seq[i].steps.cycle % (step_seq[i].steps.A[current_step] + step_seq[i].steps.B[current_step]) == 0 then
              print(clock.get_beats(),current_step)
              _a.one_shot(i,step_seq[i].steps.event[current_step])
              print("second "..step_seq[i].steps.cycle)
            end
          else
            if (step_seq[i].steps.cycle - step_seq[i].steps.A[current_step]) % step_seq[i].steps.B[current_step] == 0 then
              print(clock.get_beats(),current_step)
              _a.one_shot(i,step_seq[i].steps.event[current_step])
              print("..."..step_seq[i].steps.cycle)
            end
          end
        end
      end
    end
    if current_sub == 1 then
      patterning.check_rate_queue(i)
    end
    step_seq[i].sub_steps.current = step_seq[i].sub_steps.current + 1
    screen_dirty = true
    if step_seq[i].sub_steps.current > step_seq[i].sub_steps.max[current_step] then
      step_seq[i].sub_steps.current = 1
      step_seq[i].steps.current = step_seq[i].steps.current + 1
    end
    if step_seq[i].steps.current > step_seq[i].steps.end_point then
      step_seq[i].steps.current = step_seq[i].steps.start_point
      step_seq[i].steps.cycle = step_seq[i].steps.cycle + 1
    end
  end
end

function patterning.check_rate_queue(i)
  if step_seq[i].queued_rate ~= nil then
    step_seq[i].division = step_seq[i].queued_rate * (1/16)
    step_seq[i].sub_steps.current = 1
    step_seq[i].phase = 1
    step_seq[i].queued_rate = nil
  end
end

function patterning.change_all_rates(i,rate)
  local rates =
  {
    [1/16] = 8
  }
  for j = 1,1024 do
    step_seq[i].sub_steps.max[j] = nil
  end
end

function patterning.restart_pattern(i)
  clock.run(function()
    clock.sync(0.25)
    step_seq[i].sub_steps.current = 1
    step_seq[i].steps.current = step_seq[i].steps.start_point
    patterning.iterate(i)
    step_seq[i].active = true
  end)
end

function patterning.record_event(i,event) -- expects 
  -- local current_sub = step_seq[i].sub_steps.current
  local current_step = step_seq[i].steps.current
  print(current_step,current_sub)
  step_seq[i].steps.active[current_step] = true
  step_seq[i].steps.event[current_step] = event
  -- step_seq[i].steps.active[current_step].silent = true
end

function patterning.delta_probability(i,j,delta,all)
  step_seq[i].steps.probability[j] = util.clamp(step_seq[i].steps.probability[j]+delta,0,100)
  if all then
    for k = 1,1024 do
      if k ~= j then
        step_seq[i].steps.probability[k] = step_seq[i].steps.probability[j]
      end
    end
  end
end

function patterning.check_probability(i,j)
  if step_seq[i].steps.probability[j] == 100 or math.random(1,100) <= step_seq[i].steps.probability[j] then
    return true
  else
    return false
  end
end

function patterning.delta_conditional(i,j,target,delta,all)
  step_seq[i].steps[target][j] = util.clamp(step_seq[i].steps[target][j]+delta,1,8)
  if all then
    for k = 1,1024 do
      if k ~= j then
        step_seq[i].steps[target][k] = step_seq[i].steps[target][j]
      end
    end
  end
end

function patterning.get_mod(i,j)
  local mod_table = {}
  if step_seq[i].steps.probability[j] ~= 100 then
    table.insert(mod_table,"*P")
  end
  if step_seq[i].steps.A[j] ~= 1 or step_seq[i].steps.B[j] ~= 1 then
    table.insert(mod_table,"*A:B")
  end
  return mod_table
end

function patterning.delta_note(i,j,state,delta)
  step_seq[i].steps.event[j] = util.clamp(step_seq[i].steps.event[j]+delta,0,8)
  step_seq[i].steps.active[j] = state
end

function patterning.enter_note(i,j,state,val)
  step_seq[i].steps.active[j] = state
  step_seq[i].steps.event[j] = val
end

function patterning.get_note(i,j)
  return step_seq[i].steps.event[j]
end

function patterning.get_state(i,j)
  return step_seq[i].steps.state[j]
end

return patterning