local surveyor = {}

surveyor.rate = 1/4
surveyor.step = 0
surveyor.start_point = 1
surveyor.end_point = 16

surveyor.landscapes = {}

local queue_conditional_inc = false

function surveyor.process()
  surveyor.step = surveyor.step + 1
  if surveyor.step > surveyor.end_point then
    surveyor.step = surveyor.start_point
    queue_conditional_inc = true
  end
  for i = 1,#surveyor.landscapes do
    local j = surveyor.landscapes[i]
    local _active =  track[j][track[j].active_hill]
    local _a = _active[_active.page]
    _active.step = surveyor.step
    _htracks.run(j,_active.step)
    if queue_conditional_inc then
      _a.conditional.cycle = _a.conditional.cycle + 1
    end
  end
  queue_conditional_inc = false
end

function surveyor.jump_step(i)
  surveyor.step = i - 1
end

surveyor.clock = clock.run(
  function()
    while true do
      surveyor.process()
      clock.sync(surveyor.rate)
    end
  end
)

return surveyor