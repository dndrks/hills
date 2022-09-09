local m = {
  pos = 0,
  oldpos = 0,
  group = false,
  groupid = 0,
  alt = false,
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
  local i = params.lookup['kildare_1_group']
  repeat
    if params:visible(i) then table.insert(page, i) end
    if params:t(i) == params.tGROUP then
      i = i + params:get(i) + 1
    else i = i + 1 end
  until i > params.count
end

local function build_sub(sub)
  page = {}
  for i = 1,params:get(sub) do
    if params:visible(i + sub) then
      table.insert(page, i + sub)
    end
  end
end

m.key = function(n,z)
  if n==1 and z==1 then
    m.alt = true
  elseif n==1 and z==0 then
    m.alt = false
  end

  local i = page[m.pos+1]
  local t = params:t(i)
  if n==2 and z==1 then
  elseif n==3 and z==1 and m.alt then
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
  if n==2 and m.alt==false then
    local prev = m.pos
    m.pos = util.clamp(m.pos + d, 0, #page - 1)
    if m.pos ~= prev then m.redraw() end
  -- jump section
  elseif n==2 and m.alt==true then
    d = d>0 and 1 or -1
    local i = m.pos+1
    repeat
      i = i+d
      if i > #page then i = 1 end
      if i < 1 then i = #page end
    until params:t(page[i]) == params.tSEPARATOR or i==1
    m.pos = i-1
  -- adjust value
  elseif n==3 and params.count > 0 then
    local dx = m.fine and (d/20) or d
    params:delta(page[m.pos+1],dx)
    m.redraw()
  end
end

m.redraw = function()
  screen.clear()
  screen.font_size(8)
  if m.pos == 0 then
    local n = "STEP PARAMETERS"
    if m.group then n = n .. " / " .. m.groupname end
    screen.level(4)
    screen.move(0,10)
    screen.text(n)
  end
  for i=1,6 do
    if (i > 2 - m.pos) and (i < #page - m.pos + 3) then
      if i==3 then screen.level(15) else screen.level(4) end
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
        screen.move(0,10*i)
        screen.text(params:get_name(p))
        screen.move(127,10*i)
        screen.text_right(params:string(p))
      end
    end
  end
  screen.update()
end

m.init = function()
  if page == nil then build_page() end
  m.alt = false
  m.fine = false
end

return m