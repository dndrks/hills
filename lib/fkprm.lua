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

m.flip_to_fkprm = function(prev_page, locked_entry)
  if ui.menu_focus == 1 or ui.menu_focus == 3 then
    m.voice_focus = ui.hill_focus
    m.hill_focus = hills[ui.hill_focus].screen_focus
    if hills[ui.hill_focus].highway then
      if not locked_entry then
        m.step_focus = track[m.voice_focus][m.hill_focus].ui_position
      end
    else
      m.step_focus = ui.screen_controls[m.voice_focus][m.hill_focus][ui.menu_focus == 1 and 'hills' or 'notes'].focus
    end
  end
  pre_step_page = prev_page
  ui.control_set = 'step parameters'
end

m.flip_from_fkprm = function()
  if pre_step_page ~= 'step parameters' then
    ui.control_set = pre_step_page
  else
    ui.control_set = 'edit'
  end
  grid_data_entry = false
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
      m.flip_from_fkprm()
      ignore_key2_up = true
      key2_hold = false
    end
  elseif n==3 and z==1 and key1_hold then
    m:force(page[m.pos+1], m.voice_focus, m.hill_focus, m.step_focus)
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
        if grid_data_entry then
          m:delta_many(page[m.pos+1], dx, m.voice_focus, m.hill_focus)
        else
          m:delta(page[m.pos+1], dx, m.voice_focus, m.hill_focus, m.step_focus)
        end
        m.redraw()
      end
    elseif n == 1 then
      local i = m.voice_focus
      local j = m.hill_focus
      if hills[i].highway then
        m.step_focus = util.clamp(m.step_focus+d,1,128)
      else
        m.step_focus = util.clamp(m.step_focus+d,hills[i][j].low_bound.note,hills[i][j].high_bound.note)
      end
    end
  else
    if n == 2 then
      m.alt_menu_focus = util.clamp(m.alt_menu_focus+d,1,3)
    elseif n == 3 then
      if m.alt_menu_focus == 1 then
        m.voice_focus = util.clamp(m.voice_focus+d,1,10)
        local i = m.voice_focus
        local j = m.hill_focus
        local low_bound = hills[i].highway == true and 1 or hills[i][j].low_bound.note
        local high_bound = hills[i].highway == true and 128 or hills[i][j].high_bound.note
        if m.step_focus < low_bound then
          m.step_focus = low_bound
        elseif m.step_focus > high_bound then
          m.step_focus = high_bound
        end
      elseif m.alt_menu_focus == 2 then
        m.hill_focus = util.clamp(m.hill_focus+d,1,8)
        local i = m.voice_focus
        local j = m.hill_focus
        local low_bound = hills[i].highway == true and 1 or hills[i][j].low_bound.note
        local high_bound = hills[i].highway == true and 128 or hills[i][j].high_bound.note
        if m.step_focus < low_bound then
          m.step_focus = low_bound
        elseif m.step_focus > high_bounde then
          m.step_focus = high_bound
        end
      elseif m.alt_menu_focus == 3 then
        local i = m.voice_focus
        local j = m.hill_focus
        local low_bound = hills[i].highway == true and 1 or hills[i][j].low_bound.note
        local high_bound = hills[i].highway == true and 128 or hills[i][j].high_bound.note
        m.step_focus = util.clamp(m.step_focus+d, low_bound, high_bound)
      end
    end
  end
end

local function build_check(target_trig,voice,hill,step)
  if target_trig[voice] == nil then
    target_trig[voice] = {
      [hill] = {
        [step] = {
          ['params'] = {},
          ['ids_idx'] = {},
        }
      }
    }
  elseif target_trig[voice][hill] == nil then
    target_trig[voice][hill] = {
      
      [step] = {
        ['params'] = {},
        ['ids_idx'] = {},
      }
    }
  elseif target_trig[voice][hill][step] == nil then
    target_trig[voice][hill][step] = {
      ['params'] = {},
      ['ids_idx'] = {},
    }
  end
end

local function get_focus(voice,hill,step)
  if hills[voice].highway == true then
    if track[voice][hill].trigs[step] then
      return m.adjusted_params
    else
      return m.adjusted_params_lock_trigs
    end
  else
    return m.adjusted_params
  end
end

function m:force(index, voice, hill, step)
  local target_trig = get_focus(voice,hill,step)
  build_check(target_trig, voice, hill, step)
  print(voice,hill,step,index)
  if target_trig[voice][hill][step].params[index] ~= params:lookup_param(index).raw then
    target_trig[voice][hill][step].params[index] = params:lookup_param(index).raw
    -- target_trig[voice][hill][step].lock_trigs[index] = true
    track[voice][hill].lock_trigs[step] = true
  else
    target_trig[voice][hill][step].params[index] = nil
    -- target_trig[voice][hill][step].lock_trigs[index] = false
    if tab.count(target_trig[voice][hill][step].params) == 0 then
      track[voice][hill].lock_trigs[step] = false
    end
  end
end

function m:delta(index, d, voice, hill, step)
  local target_trig = get_focus(voice,hill,step)
  build_check(target_trig, voice, hill, step)
  local val;
  if target_trig[voice][hill][step].params[index] == nil then
    -- write index and value
    val = params:lookup_param(index).raw
  else
    -- adjust value at index
    val = target_trig[voice][hill][step].params[index]
  end
  local delta_val = params:lookup_param(index).controlspec.quantum
  target_trig[voice][hill][step].params[index] = util.clamp(val + d * delta_val,0,1)
  if util.round(target_trig[voice][hill][step].params[index],0.001) == util.round(params:get_raw(index),0.001) then
    target_trig[voice][hill][step].params[index] = nil
    if tab.count(target_trig[voice][hill][step].params) == 0 then
      track[voice][hill].lock_trigs[step] = false
    end
  elseif target_trig == m.adjusted_params_lock_trigs then
    track[voice][hill].lock_trigs[step] = true
  end
end

function m:delta_many(index, d, voice, hill)
  for i = 1,#data_entry_steps.focus[voice] do
    m:delta(index, d, voice, hill, data_entry_steps.focus[voice][i])
  end
end

function m:map(p)
  local target_trig;
  if hills[self.voice_focus].highway == true then
    if track[self.voice_focus][self.hill_focus].trigs[self.step_focus] then
      target_trig = self.adjusted_params
    else
      target_trig = self.adjusted_params_lock_trigs
    end
  else
    target_trig = self.adjusted_params
  end
  local value = target_trig[self.voice_focus][self.hill_focus][self.step_focus].params[p]
  local clamped = util.clamp(value, 0, 1)
  local cs = params:lookup_param(p).controlspec
  local rounded = util.round(cs.warp.map(cs, clamped), cs.step)
  return rounded
end

function m:string(p)
  if params:lookup_param(p).formatter then
    return params:lookup_param(p).formatter(self:map(p))
  else
    local target_trig;
    if hills[self.voice_focus].highway == true then
      if track[self.voice_focus][self.hill_focus].trigs[self.step_focus] then
        target_trig = self.adjusted_params
      else
        target_trig = self.adjusted_params_lock_trigs
      end
    else
      target_trig = self.adjusted_params
    end
    local value = target_trig[self.voice_focus][self.hill_focus][self.step_focus].params[p]
    local a = util.round(value, 0.01)
    return a.." "..params:lookup_param(p).controlspec.units
  end
end

local function prm_lookup(t, ...)
  for _, k in ipairs{...} do
    t = t[k]
    if not t then
      return false
    end
  end
  return true
end

local function check_subtables(p)
  local target_trig = get_focus(m.voice_focus,m.hill_focus,m.step_focus)
  return prm_lookup(target_trig, m.voice_focus,m.hill_focus,m.step_focus,'params',p)
end

m.redraw = function()
  -- print(m.pos, 2 - m.pos, #page - m.pos + 3)
  screen.clear()
  screen.font_size(8)
  local trig_type = track[m.voice_focus][m.hill_focus].trigs[m.step_focus] and '' or ' (parameter lock)'
  local n = m.voice_focus..' / hill: '..m.hill_focus..trig_type
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
    draw_popup("///_")
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
  m.adjusted_params_lock_trigs = {}
end

return m