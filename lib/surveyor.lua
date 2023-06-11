local surveyor = {}

surveyor.grid_takeover = false
surveyor.rate = 1/4
surveyor.step = 0
surveyor.start_point = 1
surveyor.end_point = 16
surveyor.cutting = false
surveyor.next_position = 0

surveyor.landscapes = {}

local queue_conditional_inc = false

function surveyor.process()
  if surveyor.cutting then
    surveyor.step = surveyor.next_position
    surveyor.cutting = false
  elseif surveyor.step == surveyor.end_point then
    surveyor.step = surveyor.start_point
    queue_conditional_inc = true
  else
    surveyor.step = surveyor.step + 1
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

function surveyor.process_key(x,y,z)
  if y == 4 and z == 1 then
    surveyor.cutting = true
    surveyor.next_position = x
  elseif y > 4 and y <= 8 and z == 1 then
    local i = surveyor.landscapes[y-4]
    if i ~= nil then
      local _active =  track[i][track[i].active_hill]
      local _a = _active[_active.page]
      local focused_set = _active.focus == 'main' and _a or _a.fill
      focused_set.trigs[x] = not focused_set.trigs[x]
    end
  end
end

function surveyor.draw_grid()
  local pos = surveyor.step
  
  local lvl_main = 2
  for x = 1,16 do
    g:led(x,5,0)
    g:led(x,6,0)
    g:led(x,7,0)
    g:led(x,8,0)
    if x >= surveyor.start_point and x <= surveyor.end_point then
      lvl_main = x == pos and 15 or 5
      for i = 1,#surveyor.landscapes do
        local lvl_sub = 0
        local j = surveyor.landscapes[i]
        local _active =  track[j][track[j].active_hill]
        local _a = _active[_active.page]
        local focused_set = _active.focus == 'main' and _a or _a.fill
        if focused_set.trigs[x] then
          lvl_sub = x == pos and 15 or 10
        elseif x == pos then
          lvl_sub = 2
        end
        g:led(x,4+i,lvl_sub)
      end
    end
    g:led(x,4,lvl_main)
  end
end

return surveyor