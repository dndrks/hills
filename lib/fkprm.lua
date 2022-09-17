local m = {
  pos = 0,
  oldpos = 0,
  group = false,
  groupid = 0,
  alt = false,
  voice_focus = 1,
  hill_focus = 1,
  step_focus = 1,
  alt_menu_focus = 1,
}

local page

-- called from menu on script reset
m.reset = function()
  page = nil
  m.pos = 0
  m.group = false
end

local function build_page()
  page = {}
  local ignore_range = {params.lookup['kildare_st_header'], params.lookup['kildare_st_preload']}
  local i = params.lookup['kildare_1_group']
  repeat
    if params:visible(i)
    and (i < ignore_range[1] or i > ignore_range[2]) then
      page[#page+1] = i
    end
    if params:t(i) == params.tGROUP then
      i = i + params:get(i) + 1
    else
      i = i + 1
    end
  until i == params.lookup['hills_main_header']
end

local function build_sub(sub)
  page = {}
  for i = 1,params:get(sub) do
    if params:visible(i + sub) then
      page[#page+1] = i+sub
    end
  end
end

m.key = function(n,z)
  if n==1 and z==1 then
    key1_hold = true
  elseif n==1 and z==0 then
    key1_hold = false
  end

  local i = page[m.pos+1]
  local t = params:t(i)
  if n==2 and z==1 then
    if m.group==true then
      m.group = false
      build_page()
      m.pos = m.oldpos
    else
      ui.control_set = pre_step_page
      ignore_key2_up = true
      key2_hold = false
    end
  elseif n==3 and z==1 and key1_hold then
  elseif n==3 and z==1 then
    if t == params.tGROUP then
      build_sub(i)
      m.group = true
      m.groupid = i
      m.groupname = params:string(i)
      m.oldpos = m.pos
      m.pos = 0
    elseif t == params.tSEPARATOR then
      local n = m.pos+1
      repeat
        n = n+1
        if n > #page then n = 1 end
      until params:t(page[n]) == params.tSEPARATOR
      m.pos = n-1
    elseif t == params.tFILE then
    elseif t == params.tTEXT then
    elseif t == params.tTRIGGER then
    elseif t == params.tBINARY then 
    else
      m.fine = true
    end
  elseif n==3 and z==0 then
    m.fine = false
  end
  m.redraw()
end

m.enc = function(n,d)
  if not key1_hold then
    if n==2 then
      local prev = m.pos
      m.pos = util.clamp(m.pos + d, 0, #page - 1)
      if m.pos ~= prev then m.redraw() end
    elseif n==3 and params.count > 0 then
      if params:lookup_param(page[m.pos+1]).t == 3 then
        local dx = m.fine and (d/20) or d
        m:delta(page[m.pos+1], dx, m.voice_focus, m.hill_focus, m.step_focus)
        m.redraw()
      end
    elseif n == 1 then
      local i = m.voice_focus
      local j = m.hill_focus
      m.step_focus = util.clamp(m.step_focus+d,hills[i][j].low_bound.note,hills[i][j].high_bound.note)
    end
  else
    if n == 2 then
      m.alt_menu_focus = util.clamp(m.alt_menu_focus+d,1,3)
    elseif n == 3 then
      if m.alt_menu_focus == 1 then
        m.voice_focus = util.clamp(m.voice_focus+d,1,10)
        local i = m.voice_focus
        local j = m.hill_focus
        if m.step_focus < hills[i][j].low_bound.note then
          m.step_focus = hills[i][j].low_bound.note
        elseif m.step_focus > hills[i][j].high_bound.note then
          m.step_focus = hills[i][j].high_bound.note
        end
      elseif m.alt_menu_focus == 2 then
        m.hill_focus = util.clamp(m.hill_focus+d,1,8)
        local i = m.voice_focus
        local j = m.hill_focus
        if m.step_focus < hills[i][j].low_bound.note then
          m.step_focus = hills[i][j].low_bound.note
        elseif m.step_focus > hills[i][j].high_bound.note then
          m.step_focus = hills[i][j].high_bound.note
        end
      elseif m.alt_menu_focus == 3 then
        local i = m.voice_focus
        local j = m.hill_focus
        m.step_focus = util.clamp(m.step_focus+d,hills[i][j].low_bound.note,hills[i][j].high_bound.note)
      end
    end
  end
end

function m:delta(index, d, voice, hill, step)
  -- ah, index is coming in as number...need to couple with 'params:set_raw(index,value)'

  -- basically, want to snag the parameter info and build out a copy with the delta...
  if m.adjusted_params[voice] == nil then
    m.adjusted_params[voice] = {
      [hill] = {
        [step] = {
          ['params'] = {},
          ['ids_idx'] = {},
        }
      }
    }
  elseif m.adjusted_params[voice][hill][step] == nil then
    m.adjusted_params[voice][hill][step] = {
      ['params'] = {},
      ['ids_idx'] = {},
    }
  end
  if m.adjusted_params[voice][hill][step].params[index] == nil then
    -- write index and value
    local raw_val = params:lookup_param(index).raw
    local delta_val = params:lookup_param(index).controlspec.quantum
    m.adjusted_params[voice][hill][step].params[index] = util.clamp(raw_val + d * delta_val,0,1)
  else
    -- adjust value at index
    local current_val = m.adjusted_params[voice][hill][step].params[index]
    local delta_val = params:lookup_param(index).controlspec.quantum
    m.adjusted_params[voice][hill][step].params[index] = util.clamp(current_val + d * delta_val,0,1)
  end
  if util.round(m.adjusted_params[voice][hill][step].params[index],0.001) == util.round(params:get_raw(index),0.001) then
    m.adjusted_params[voice][hill][step].params[index] = nil
  end
end

function m:map(p)
  local value = self.adjusted_params[self.voice_focus][self.hill_focus][self.step_focus].params[p]
  local clamped = util.clamp(value, 0, 1)
  local cs = params:lookup_param(p).controlspec
  local rounded = util.round(cs.warp.map(cs, clamped), cs.step)
  return rounded
end

function m:string(p)
  if params:lookup_param(p).formatter then
    return params:lookup_param(p).formatter(self:map(p))
  else
    local value = self.adjusted_params[self.voice_focus][self.hill_focus][self.step_focus].params[p]
    local a = util.round(value, 0.01)
    return a.." "..params:lookup_param(p).controlspec.units
  end
end

local function check_subtables(p)
  if m.adjusted_params[m.voice_focus] ~= nil
  and m.adjusted_params[m.voice_focus][m.hill_focus] ~= nil
  and m.adjusted_params[m.voice_focus][m.hill_focus][m.step_focus] ~= nil
  and m.adjusted_params[m.voice_focus][m.hill_focus][m.step_focus].params ~= nil
  and m.adjusted_params[m.voice_focus][m.hill_focus][m.step_focus].params[p] ~= nil then
    return true
  else
    return false
  end
end

m.redraw = function()
  -- print(m.pos, 2 - m.pos, #page - m.pos + 3)
  screen.clear()
  screen.font_size(8)
  local n = m.voice_focus..' / hill: '..m.hill_focus
  screen.level(4)
  screen.move(0,10)
  screen.text(n)
  n = "STEP "..m.step_focus.." PARAMS"
  if m.group then n = n .. " / " .. m.groupname end
  screen.move(0,20)
  screen.text(n)
  for i=3,6 do
    if (i > 2 - m.pos) and (i < #page - m.pos + 3) then
      local highlight = {[0] = true, [3] = true, [7] = true}
      if i==3 then
        if highlight[params:lookup_param(page[m.pos+1]).t] then
          screen.level(key1_hold and 4 or 15)
        else
          screen.level(1)
        end
      else
        if highlight[params:lookup_param(page[i+m.pos-2]).t] then
          screen.level(4)
        else
          screen.level(1)
        end
      end
      local p = page[i+m.pos-2]
      local t = params:t(p)
      if t == params.tSEPARATOR then
        screen.move(0,10*i+2.5)
        screen.line_rel(127,0)
        screen.stroke()
        screen.move(63,10*i)
        screen.text_center(params:get_name(p))
      elseif t == params.tGROUP then
        screen.move(0,10*i)
        screen.text(params:get_name(p) .. " >")
      else
        if check_subtables(p) then
          screen.rect(0,(10*i)-7,127,9)
          screen.fill()
          screen.stroke()
          screen.level(0)
        end
        screen.move(2,10*i)
        screen.text(params:get_name(p))
        screen.move(125,10*i)
        if check_subtables(p) then
          screen.text_right(m:string(p))
        else
          screen.text_right(params:string(p))
        end
      end
    end
  end
  if key1_hold then
    screen.rect(7,10,112,42)
    screen.level(15)
    screen.fill()
    screen.rect(8,11,110,40)
    screen.level(0)
    screen.fill()
    screen.font_size(15)
    screen.level(15)
    screen.move(14,34)
    screen.text("///_")
    screen.font_size(8)
    screen.move(70,23)
    screen.level(m.alt_menu_focus == 1 and 15 or 4)
    screen.text('VOICE: '..m.voice_focus)
    screen.move(70,33)
    screen.level(m.alt_menu_focus == 2 and 15 or 4)
    screen.text('HILL: '..m.hill_focus)
    screen.move(70,43)
    screen.level(m.alt_menu_focus == 3 and 15 or 4)
    screen.text('STEP: '..m.step_focus)
  end
  screen.update()
end

m.init = function()
  if page == nil then build_page() end
  key1_hold = false
  m.fine = false
  m.adjusted_params = {}
end

return m