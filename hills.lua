-- hills

curves = include 'lib/easing'
prms = include 'lib/parameters'
lattice = include 'lib/zacklattice'
p_rec = include 'lib/hillattice'
mu = require 'musicutil' -- with this, min/max are windows of notes
engine.name = "PolyPerc"

r = function()
  norns.script.load("code/hills/hills.lua")
end

function init()
  hills = {}
  hills.lattice = lattice:new{
    auto = true,
    meter = 4,
    ppqn = 8
  }
  -- midi_notes = {70,74,63,65,67,62,72,70,60,55,77,70,74,75,63,67}
  scale_names = {}
  pre_note = {}
  for i = 1,#mu.SCALES do
    table.insert(scale_names,mu.SCALES[i].name)
  end
  prms.init()
  midi_note_dest = {8,9,11,6,4,5,7}
  midi_device = {}
  for i = 1,#midi.vports do -- query all ports
    midi_device[i] = midi.connect(i) -- connect each device
  end
  for i = 1,2 do
    hills[i] = {{},{},{},{},{},{},{},{}}
    hills[i].active = false
    hills[i].min = 1
    hills[i].max = #hills[i]
    hills[i].segment = hills[i].min
    hills[i].notes = mu.generate_scale(60,params:get("hill "..i.." scale"),4)
    hills[i].undo = {}
    hills[i].undo_step = 1
    hills[i].auto_advance = false
    hills[i].loop = false
    hills[i].midi_note = i == 1 and 8 or 4
    for j = 1,100 do
      hills[i].undo[j] = {}
    end
    for j = 1,#hills[i] do
      hills[i][j].step = 0
      hills[i][j].duration = util.round(clock.get_beat_sec() * math.random(4),0.01) -- in seconds
      hills[i][j].eject = hills[i][j].duration
      hills[i][j].eject_percent = 1
      -- hills[i][j].base_step = math.random(0,util.round(hills[i][j].duration*1000-1)) / 1000
      hills[i][j].base_step = 0
      hills[i][j].current_val = 0
      hills[i][j].shape = params:string("hill ["..i.."]["..j.."] shape")
      hills[i][j].min = 1
      hills[i][j].max = math.random(#hills[i].notes)
      hills[i][j].random_octaves = {0}
      hills[i][j].counter = metro.init()
      hills[i][j].counter.time = 0.01
      hills[i][j].counter.count = hills[i][j].duration * 100
      hills[i][j].counter.event = function() iterate(i) end
      hills[i][j].active = false
    end
    p_rec.init(i)
  end
  -- midi_notes = {70,74,75,63,67}
  random_octaves = {}
  -- random_octaves[1] = {12,-12,24,0,36}
  random_octaves[1] = {0}
  random_octaves[2] = {-24,-12}
  -- type = "notes"
  -- will want multiple types...note, vel, cc, val

  screen_dirty = true
  clock.run(function()
    while true do
      clock.sleep(1/15)
      if screen_dirty then
        redraw()
      end
    end
  end)
end

function midi_to_hz(note)
  return (440 / 32) * (2 ^ ((note - 9) / 12))
end

iterate = function(i)
  local h = hills[i]
  local seg = h[h.segment]
  local pre_change = seg.current_val
  local midi_notes = h.notes
  -- seg.current_val = util.linlin(0,127,1,#midi_notes,curves[seg.shape](seg.step,0,127,seg.duration))
  seg.current_val = util.wrap(curves[seg.shape](seg.step,1,#midi_notes-1,seg.duration),seg.min,seg.max)
  seg.step = util.round(seg.step + 0.01,0.01)
  if util.round(pre_change) ~= util.round(seg.current_val) then
    print(h.segment, midi_notes[ util.wrap(util.round(math.abs(seg.current_val)),1,#midi_notes) ], seg.step, seg.current_val, math.abs(seg.current_val), util.linlin(0,seg.duration,1,127,seg.step))
    pass_engine_notes(i)
    pass_midi_notes(i)
    -- if i == 1 then
    --   pass_engine_notes(i)
    -- elseif i == 2 then
    --   pass_midi_notes(i)
    -- end
  end
  if util.round(seg.step,0.01) >= util.round(seg.eject,0.01) then
    seg.counter:stop()
    print("stopping", seg.counter.is_running)
    if h.segment < h.max and h.auto_advance then
      h.segment = h.segment + 1
      toggle_iterator(false,i)
    elseif h.segment >= h.max then
      if not h.loop then
        h.active = false
      else
        h.segment = h.min
        toggle_iterator(false,i)
      end
    end
    -- toggle_iterator(false,i)
  end
end

pass_engine_notes = function(i)
  local h = hills[i]
  local seg = h[h.segment]
  local midi_notes = h.notes
  local random_note = seg.random_octaves[math.random(#seg.random_octaves)]
  local played_note = midi_notes[ util.wrap(util.round(math.abs(seg.current_val)),1,#midi_notes) ] + random_note
  engine.cutoff(seg.step*1000)
  engine.hz(midi_to_hz(played_note))
  engine.release(seg.step/2)
end

pass_midi_notes = function(i)
  local h = hills[i]
  local note = h.midi_note
  -- if pre_note[i] ~= nil then
  --   midi_device[4]:note_off(pre_note,0,1)
  -- end
  midi_device[4]:note_off(note,0,1)
  local seg = h[h.segment]
  -- local midi_notes = h.notes
  -- local note = midi_note_dest[util.wrap(util.round(math.abs(seg.current_val)),1,#midi_note_dest)]
  -- local vel = util.round(util.linlin(0,seg.duration,1,64,seg.step))
  local vel = params:get("hill "..i.." velocity")
  local ch = 1
  midi_device[4]:note_on(note,vel,ch)
  pre_note[i] = note
end

toggle_iterator = function(running,i)
  local h = hills[i]
  local seg = h[h.segment]
  if running then
    seg.counter:stop()
  else
    -- seg.step = math.random()
    seg.step = seg.base_step
    -- seg.duration = math.random(1,7)
    seg.current_val = 0
    seg.counter.count = util.round(seg.duration * 100)
    seg.counter:start()
    h.active = true
  end
end

one_shot = function(i,j)
  local h = hills[i]
  h.segment = j
  local seg = h[j]
  if seg.counter.is_running then
    seg.counter:stop()
  end
  seg.step = seg.base_step
  -- seg.duration = math.random(1,7)
  seg.current_val = 0
  seg.counter.count = util.round(seg.duration * 100)
  seg.counter:start()
  h.active = true
  if h.pattern.rec then
    p_rec.add_event(i,"one_shot: "..j)
  end
end

key = function(n,z)
  if n == 3 and z == 1 then
    -- hills[1][hills[1].segment].counter:stop()
    -- hills[1].segment = hills[1].min
    -- toggle_iterator(hills[1][1].counter.is_running,1)
  elseif n == 2 and z == 1 then
    -- hills[2][hills[2].segment].counter:stop()
    -- hills[2].segment = hills[2].min
    -- toggle_iterator(hills[2][1].counter.is_running,2)
    one_shot(1,hills[1].segment)
  end
end

enc = function(n,d)
  if n == 1 then
    hills[1].segment = util.clamp(hills[1].segment+d,1,8)
  elseif n == 2 then
    local h = hills[1].segment
    hills[1][h].base_step = util.clamp(hills[1][h].base_step+d/(100/hills[1][h].duration),0,hills[1][h].eject-0.01)
  elseif n == 3 then
    local h = hills[1].segment
    hills[1][h].eject = util.clamp(hills[1][h].eject+d/(100/hills[1][h].duration),hills[1][h].base_step,hills[1][h].duration)
  end
  screen_dirty = true
end

undo = function(i)
  hills[i].undo_step = hills[i].undo_step - 1
  for k,v in pairs(hills[i].undo[hills[i].undo_step]) do
    hills[i].notes[k] = v
  end
end

add_undo_step = function(i)
  for k,v in pairs(hills[i].notes) do
    hills[i].undo[hills[i].undo_step][k] = v
  end
  hills[i].undo_step = hills[i].undo_step + 1
end

-- 1. TRANSPOSITION : ahhh this needs to account for other changes, can't just re-establish scale
-- would i need to get down to a root note delta? so how many from the root note is this, then scale via the scale?
transpose = function(i,delta)
  add_undo_step(i)
  params:delta("hill "..i.." base note",delta)
end

-- 2. REVERSAL
reverse = function(i,start_point,end_point)
  add_undo_step(i)
	local rev = {}
	for j = end_point, start_point, -1 do
		rev[end_point - j + 1] = hills[i].notes[j]
	end
  for j = start_point, end_point do
    local range = (end_point-start_point)+1
    hills[i].notes[j] = rev[util.linlin(start_point,end_point,1,range,j)]
  end
end

-- 3. ROTATION
rotate = function(i,first,second)
  add_undo_step(i)
  local originals = {hills[i].notes[first], hills[i].notes[second]}
  hills[i].notes[first] = originals[2]
  hills[i].notes[second] = originals[1]
end

-- 4. PHASE OFFSET
adjust_window = function(i,j,new_min,new_max)
  local h = hills[i]
  h[j].min = new_min
  h[j].max = new_max
end

-- 5. RESCALING
rescale = function(i,j,mult)
  local pre_change_duration = hills[i][j].duration
  hills[i][j].duration = util.round(clock.get_beat_sec() * mult,0.01)
  -- hills[i][j].base_step = 0
  hills[i][j].base_step = util.linlin(0,pre_change_duration,0,hills[i][j].duration,hills[i][j].base_step)
  -- hills[i][j].eject = hills[i][j].duration
  hills[i][j].eject = util.linlin(0,pre_change_duration,0,hills[i][j].duration,hills[i][j].eject)
end

-- 6. INTERPOLATION
reshape = function(i,new_shape)
  hills[i][j].shape = new_shape
end

-- 7. EXTRAPOLATION
bound = function(i,new_min,new_max)
  hills[i].min = new_min
  hills[i].max = new_max
end

-- 8. FRAGMENTATION
fragment = function(i,j,percent)
  hills[i][j].base_step = util.clamp(percent*hills[i][j].duration,0,hills[i][j].eject-0.01)
end

set_eject = function(i,j,percent)
  hills[i][j].eject = percent * hills[i][j].duration
end

random_window = function(i,j)
  fragment(i,j,math.random(0,59)/100)
  set_eject(i,j,math.random(60,100)/100)
end

-- 9. SUBSTITUTION -- this should commit!
-- substitute = function(i,j,random_table)
--   hills[i][j].random_octaves = random_table
-- end
shuffle = function(i)
  add_undo_step(i)
  local shuffled = {}
  for i, v in ipairs(hills[i].notes) do
	  local pos = math.random(1, #shuffled+1)
	  table.insert(shuffled, pos, v)
  end
  for k,v in pairs(shuffled) do
    hills[i].notes[k] = v
  end
end

redraw = function()
  if screen_dirty then
    screen.clear()
    for i = 1,2 do
      screen.move(0,10*i)
      local scaled_min = util.round((hills[i][hills[i].segment].base_step/hills[i][hills[i].segment].duration)*100)
      local scaled_max = util.round((hills[i][hills[i].segment].eject/hills[i][hills[i].segment].duration)*100)
      screen.text("hill "..hills[i].segment.." | min: "..scaled_min.."% | max: "..scaled_max.."%")
    end
    screen.update()
    screen_dirty = false
  end
end