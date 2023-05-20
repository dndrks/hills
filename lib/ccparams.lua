local m = {
  pos = 0,
  oldpos = 0,
  group = false,
  groupid = 0,
  alt = false,
  voice_focus = 1,
  pad_focus = 1,
  alt_menu_focus = 1,
}

local page

local function build_sub(sub)
  page = {}
  for i = 1,params:get(sub) do
    if params:visible(i + sub) then
      page[#page+1] = i+sub
    end
  end
end

-- called from menu on script reset
m.reset = function()
  page = nil
  m.pos = 0
  m.group = false
end

m.flip_to_fkprm = function(prev_page, locked_entry)
  if ui.menu_focus == 1 or ui.menu_focus == 3 then
    m.voice_focus = ui.hill_focus
  end
  pre_step_page = prev_page
  ui.control_set = 'cc parameters'
  build_sub(params.lookup['kildare_'..m.voice_focus..'_group'])
  m.group = true
  m.groupid = params.lookup['kildare_'..m.voice_focus..'_group']
  m.groupname = params:string(params.lookup['kildare_'..m.voice_focus..'_group'])
  m.oldpos = m.pos
  m.pos = 0
end

m.flip_from_fkprm = function()
  if pre_step_page ~= 'cc parameters' then
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
    m:force(page[m.pos+1], m.voice_focus, m.pad_focus)
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
          m:delta_many(params:lookup_param(page[m.pos+1]).id, dx, m.voice_focus, m.pad_focus)
        else
          m:delta(params:lookup_param(page[m.pos+1]).id, dx, m.voice_focus, m.pad_focus)
        end
        m.redraw()
      end
    elseif n == 1 then
      local i = m.voice_focus
      local j = m.hill_focus
      m.pad_focus = util.clamp(m.pad_focus+d,1,params:get(i..'_poly_voice_count'))
    end
  else
    if n == 2 then
      m.alt_menu_focus = util.clamp(m.alt_menu_focus+d,1,3)
    elseif n == 3 then
      if m.alt_menu_focus == 1 then
        m.voice_focus = util.clamp(m.voice_focus+d,1,number_of_hills)
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

local function build_check(target_trig,voice,alloc)
  if target_trig[voice] == nil then
    target_trig[voice] = {
      [alloc] = {
        ['params'] = {}
      }
    }
  elseif target_trig[voice][alloc] == nil then
    target_trig[voice][alloc] = {
      ['params'] = {},
    }
  end
end

function m:force(index, voice, alloc)
  local target_trig = m.adjusted_params
  build_check(target_trig, voice, alloc)
  print('forcing',voice,alloc,step,index)
  if target_trig[voice][alloc].params[index] ~= params:lookup_param(index).raw then
    target_trig[voice][alloc].params[index] = params:lookup_param(index).raw
  else
    target_trig[voice][alloc].params[index] = nil
  end
end

function m:unpack_pad(voice,pad)
  print("230520: WHEN DOES THIS HAPPEN? UNCOMMENT IF IT DOES")
  -- for i = 6,#kildare_drum_params.sample do
  --   if kildare_drum_params.sample[i].type ~= 'separator' then
  --     local id = voice..'_sample_'..kildare_drum_params.sample[i].id
  --     params:lookup_param(id):bang()
  --     -- TODO: this doesn't respect polyphony...
  --   end
  -- end
  -- print(voice, pad)
  -- for prm,val in pairs(m.adjusted_params[voice][pad].params) do
  --   params:lookup_param(prm).action(params:lookup_param(prm):map_value(val))
  -- end
end

function m:delta(index, d, voice, alloc)
  build_check(m.adjusted_params, voice, alloc)
  local val;
  if m.adjusted_params[voice][alloc].params[index] == nil then
    -- write index and value
    val = params:lookup_param(index).raw
  else
    -- adjust value at index
    val = m.adjusted_params[voice][alloc].params[index]
  end
  local delta_val = params:lookup_param(index).controlspec.quantum
  m.adjusted_params[voice][alloc].params[index] = util.clamp(val + d * delta_val,0,1)
  local paramValue = m.adjusted_params[voice][alloc].params[index]
  local paramKey = string.gsub(
    index,
    voice..'_'..params:string('voice_model_'..voice)..'_',
    ""
  )
  paramValue = params:lookup_param(index):map_value(paramValue)
  if paramKey == 'loop' then
    if paramValue == 1 then
      m.queued_loop[voice][alloc] = true
    elseif paramValue == 0 then
      m.queued_unloop[voice][alloc] = true
    end
  elseif paramKey == 'playbackRateBase' then
    -- m.queued_rate_change[voice][alloc] = paramValue
    -- do nothing, because it just needs to end up handled by the clip actions...
  else
    -- print(voice, alloc, paramKey, paramValue)
    -- NO, don't send to engine:
    -- send_to_engine('set_poly_voice_param',{voice, alloc, paramKey, paramValue})
  end
  
  if util.round(m.adjusted_params[voice][alloc].params[index],0.001) == util.round(params:get_raw(index),0.001) then
    m.adjusted_params[voice][alloc].params[index] = nil
  end
end

function m:delta_many(index, d, voice, alloc)
  for i = 1,#data_entry_steps.focus[voice] do
    m:delta(index, d, voice, alloc)
  end
end

function m:map(p)
  local target_trig = self.adjusted_params
  local value = target_trig[self.voice_focus][self.pad_focus].params[params:lookup_param(p).id]
  local clamped = util.clamp(value, 0, 1)
  local cs = params:lookup_param(p).controlspec
  local rounded = util.round(cs.warp.map(cs, clamped), cs.step)
  return rounded
end

function m:string(p)
  if params:lookup_param(p).formatter then
    return params:lookup_param(p).formatter(self:map(p))
  else
    local target_trig = self.adjusted_params
    local value = target_trig[self.voice_focus][self.pad_focus].params[p]
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
  local target_trig = m.adjusted_params
  return prm_lookup(target_trig, m.voice_focus,m.pad_focus,'params',params:lookup_param(p).id)
end

m.redraw = function()
  -- print(m.pos, 2 - m.pos, #page - m.pos + 3)
  screen.clear()
  screen.font_size(8)
  local n = m.groupname
  screen.level(4)
  screen.move(0,10)
  screen.text(n)
  local appended = ''
  if params:get(m.voice_focus..'_poly_voice_count') > 1 then
    appended = ' | ('..kildare.pad_focus[m.voice_focus]..')'
  end
  n = 'PAD: '..m.pad_focus..appended
  screen.move(128,10)
  screen.text_right(n)
  for i=2,6 do
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
  for i = 1,number_of_hills do
    m.adjusted_params[i] = {}
    for j = 1,16 do
      m.adjusted_params[i][j] = {params = {}}
    end
  end
  m.reset_polyparams()
  print('cc!!')
end

m.reset_polyparams = function()
  m.pad_focus = 1
  m.queued_loop = {}
  m.queued_unloop = {}
  m.queued_rate_change = {}
  for i = 1,number_of_hills do
    m.queued_loop[i] = {}
    m.queued_unloop[i] = {}
    m.queued_rate_change[i] = {}
  end
  m.reset()
end

return m