-- hills
-- hills[x][y].min = lo-note cutoff (after base)
-- hills[x][y].max = hi-note cutoff (after base)
-- rescale(x,y,multiple of beats) (controls duration)
-- fragment(x,y,percent of total) (controls base_step)
-- set_eject(x,y,percent of total) (controls eject)
-- reshape(x,y,shape) (controls shape)
-- 

curves = include 'lib/easing'
prms = include 'lib/parameters'
lattice = include 'lib/zacklattice'
p_rec = include 'lib/hillattice'
_arc = include 'lib/arc_lib'
_draw = include 'lib/drawing'
mu = require 'musicutil' -- with this, min/max are windows of notes
engine.name = "PolyPerc"

r = function()
  norns.script.load("code/hills/hills.lua")
end

a = arc.connect()
last_bpm = params:get("clock_tempo")

function init()
  for i = 1,4 do
    crow.output[i].action = "pulse(0.05,8)"
  end
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
  for i = 1,8 do
    hills[i] = {{},{},{},{},{},{},{},{}}
    hills[i].active = false
    hills[i].min = 1
    hills[i].max = #hills[i]
    hills[i].segment = hills[i].min
    hills[i].notes = mu.generate_scale_of_length(params:get("hill "..i.." base note"),params:get("hill "..i.." scale"),127)
    hills[i].undo = {}
    hills[i].undo_step = 1
    hills[i].auto_advance = false
    hills[i].loop = false
    hills[i].midi_note = i == 1 and 8 or 4
    hills[i].screen_focus = hills[i].min

    hills[i].counter = metro.init()
    hills[i].counter.time = 0.01
    hills[i].counter.event = function() iterate(i) end

    for j = 1,100 do
      hills[i].undo[j] = {}
    end
    for j = 1,#hills[i] do
      hills[i][j].step = 0
      hills[i][j].duration = util.round(clock.get_beat_sec() * math.random(8,15),0.01) -- in seconds
      hills[i][j].eject = hills[i][j].duration
      hills[i][j].eject_percent = 1
      -- hills[i][j].base_step = math.random(0,util.round(hills[i][j].duration*1000-1)) / 1000
      hills[i][j].base_step = 0
      hills[i][j].current_val = 0
      hills[i][j].shape = params:string("hill ["..i.."]["..j.."] shape")
      hills[i][j].min = 1
      hills[i][j].max = math.random(#hills[i].notes)
      hills[i][j].population = 0.5
      hills[i][j].change_lock = false
      hills[i][j].random_octaves = {0}
      hills[i][j].velocity_send = true
      hills[i][j].velocity_min = 0
      hills[i][j].velocity_max = 127
      hills[i][j].velocity = 127
      hills[i][j].cc_val_send = true
      hills[i][j].cc_val_min = 0
      hills[i][j].cc_val_max = 127
      hills[i][j].cc_val = 127
      -- hills[i][j].counter = metro.init()
      -- hills[i][j].counter.time = 0.01
      -- hills[i][j].counter.count = hills[i][j].duration * 100
      -- hills[i][j].counter.event = function() iterate(i) end
      -- hills[i][j].active = false
    end
    hills[i].counter.count = hills[1][1].duration * 100
    p_rec.init(i)
  end
  -- midi_notes = {70,74,75,63,67}
  random_octaves = {}
  -- random_octaves[1] = {12,-12,24,0,36}
  random_octaves[1] = {0}
  random_octaves[2] = {-24,-12}
  -- type = "notes"
  -- will want multiple types...note, vel, cc, val
  _draw.init()
  _draw.build(1,1)
  screen_dirty = true
  clock.run(function()
    while true do
      clock.sleep(1/15)
      if screen_dirty then
        redraw()
      end
    end
  end)
  hills.lattice:hard_sync()
end

function midi_to_hz(note)
  return (440 / 32) * (2 ^ ((note - 9) / 12))
end

iterate = function(i)
  local h = hills[i]
  local seg = h[h.segment]
  seg.change_lock = true
  local pre_change = seg.current_val
  local midi_notes = h.notes
  local total_notes = util.round(#midi_notes*seg.population)
  -- seg.current_val = util.linlin(0,127,1,#midi_notes,curves[seg.shape](seg.step,0,127,seg.duration))
  seg.current_val = util.wrap(curves[seg.shape](seg.step,1,total_notes-1,seg.duration),seg.min,seg.max)
  seg.step = util.round(seg.step + 0.01,0.01)
  if util.round(pre_change) ~= util.round(seg.current_val) then
    -- print(h.segment, midi_notes[ util.wrap(util.round(math.abs(seg.current_val)),1,#midi_notes) ], seg.step, seg.current_val, math.abs(seg.current_val), util.linlin(0,seg.duration,1,127,seg.step))
    print(h.segment, seg.step, seg.current_val)
    -- process_velocity(i) -- down here, it processes when a note happens ***
    process_data(i,"cc_val")
    process_data(i,"velocity")
    pass_note(i,"engine")
    pass_note(i,"midi")
    -- pass_note(i,"crow_pulse")
  end
  if util.round(seg.step,0.01) >= util.round(seg.eject,0.01) then
    h.counter:stop()
    seg.change_lock = false
    print("stopping", h.counter.is_running)

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

pass_note = function(i,destination)
  local h = hills[i]
  local seg = h[h.segment]
  local midi_notes = h.notes
  local random_note = seg.random_octaves[math.random(#seg.random_octaves)]
  local total_notes = util.round(#midi_notes*(params:get("hill ["..i.."]["..h.segment.."] population")/100))
  local played_note = midi_notes[ util.wrap( util.clamp(util.round(math.abs(seg.current_val)),seg.min,seg.max) ,1,total_notes) ] + random_note
  if destination == "engine" then
    if i < 3 then
      engine.cutoff(seg.velocity*100)
      engine.hz(midi_to_hz(played_note))
      engine.release(seg.step/2)
    end
  elseif destination == "midi" then
    if i > 2 then
      local ch = params:get("hill "..i.." MIDI note channel")
      local dev = params:get("hill "..i.." MIDI device")
      if pre_note[i] ~= nil then
        midi_device[dev]:note_off(pre_note[i],seg.velocity,ch)
      end
      midi_device[dev]:note_on(played_note,seg.velocity,ch)
      for j = 1,5 do
        if params:get("hill "..i.." cc_"..j) ~= "none" then
          midi_device[dev]:cc(params:get("hill "..i.." cc_"..j),seg.cc_val,params:get("hill "..i.." cc_"..j.."_ch"))
        end
      end
      -- midi_device[4]:cc(18,seg.cc_val,9)
      pre_note[i] = played_note
    end
  elseif destination == "crow_pulse" then
    crow.output[i].volts = (played_note-60)/12
    crow.output[i+2]()
  end
end

pass_midi_notes = function(i)
  local h = hills[i]
  local note = params:get("hill "..i.." fixed MIDI note") ~= "none" and params:get("hill "..i.." fixed MIDI note")-2 or h.midi_note
  local seg = h[h.segment]
  local ch = 1
  midi_device[4]:note_on(note,seg.velocity,ch)
  for j = 1,5 do
    if params:get("hill "..i.." cc_"..j) ~= "none" then
      midi_device[4]:cc(params:get("hill "..i.." cc_"..j),seg.cc_val,params:get("hill "..i.." cc_"..j.."_ch"))
    end
  end
  -- midi_device[4]:cc(18,seg.cc_val,9)
  pre_note[i] = note
end

process_data = function(i,data_param)
  local h = hills[i]
  local seg = h[h.segment]
  if seg[data_param.."_send"] then
    local pre_change = util.round(seg[data_param])
    local min = seg[data_param.."_min"]
    local max = seg[data_param.."_max"]
    local new_vel = util.round(util.linlin(0,seg.duration,0,127,seg.step))
    if util.clamp(pre_change,min,max) ~= util.clamp(new_vel,min,max) then
      seg[data_param] = util.clamp(new_vel,min,max)
      -- print(data_param..": "..seg[data_param])
    end
  -- else
    -- seg[data_param] = params:get("hill "..i.." "..data_param)
  end
end

-- process_velocity = function(i)
--   local h = hills[i]
--   local seg = h[h.segment]
--   local pre_change = util.round(seg.velocity)
--   if seg.velocity_send then
--     local new_vel = util.round(util.wrap(util.linlin(0,seg.duration,0,127,seg.step),seg.velocity_min,seg.velocity_max))
--     if util.clamp(pre_change,seg.velocity_min,seg.velocity_max) ~= util.clamp(new_vel,seg.velocity_min,seg.velocity_max) then
--       seg.velocity = util.clamp(new_vel,seg.velocity_min,seg.velocity_max)
--       print("vel: "..seg.velocity)
--     end
--   else
--     vel = params:get("hill "..i.." velocity")
--   end
-- end

-- process_cc_value = function(i)

-- end

toggle_iterator = function(running,i)
  local h = hills[i]
  local seg = h[h.segment]
  if running then
    -- seg.counter:stop()
    h.counter:stop()
  else
    seg.step = seg.base_step
    seg.current_val = 0

    -- seg.counter.count = util.round(seg.duration * 100)
    -- seg.counter:start()
    h.counter.count = util.round(seg.duration * 100)
    h.counter:start()

    h.active = true
  end
end

one_shot = function(i,j)
  local h = hills[i]

  -- if h[h.segment].counter.is_running then
  --   h[h.segment].counter:stop()
  -- end
  if h.counter.is_running then
    h.counter:stop()
  end

  h.segment = j
  local seg = h[j]

  -- if seg.counter.is_running then
  --   seg.counter:stop()
  -- end
  
  seg.step = seg.base_step
  seg.current_val = 0

  -- seg.counter.count = util.round(seg.duration * 100)
  -- seg.counter:start()
  h.counter.count = util.round(seg.duration * 100)
  h.counter:start()

  h.active = true
  pattern_rec = {}
  pattern_rec.hill_id = i
  pattern_rec.hill_sub = j
  h.pattern:watch(pattern_rec)
end

set_loop = function(i,start_point,end_point,state)
  if state then
    hills[i].auto_advance = true
    hills[i].min = start_point
    hills[i].max = end_point
    hills[i].loop = true
  else
    hills[i].auto_advance = false
    hills[i].min = 1
    hills[i].max = 8
    hills[i].loop = true
  end
end

key = function(n,z)
  if n == 3 and z == 1 then
    -- hills[1][hills[1].segment].counter:stop()
    -- hills[1].segment = hills[1].min
    -- toggle_iterator(hills[1][1].counter.is_running,1)
    one_shot(2,hills[2].screen_focus)
  elseif n == 2 and z == 1 then
    -- hills[2][hills[2].segment].counter:stop()
    -- hills[2].segment = hills[2].min
    -- toggle_iterator(hills[2][1].counter.is_running,2)
    one_shot(1,hills[1].screen_focus)
  end
end

enc = function(n,d)
  if n == 1 then
    -- hills[1].segment = util.clamp(hills[1].segment+d,1,8)
    -- hills[1].screen_focus = util.clamp(hills[1].screen_focus+d,1,8)
    local shape_index = tab.key(easingNames,hills[1][1].shape)
    hills[1][1].shape = easingNames[util.clamp(shape_index + d,1,#easingNames)]
    _draw.build(1,1)
    screen_dirty = true
  elseif n == 2 then
    local h = hills[1].screen_focus
    hills[1][h].base_step = util.clamp(hills[1][h].base_step+d/(100/hills[1][h].duration),0,hills[1][h].eject-0.01)
    base_step_pattern_rec = {}
    base_step_pattern_rec.hill_id = 1
    base_step_pattern_rec.hill_sub = h
    base_step_pattern_rec.base_step = hills[1][h].base_step
    base_step_pattern_rec.base_step_delta = d
    base_step_pattern_rec.duration = hills[1][h].duration
    base_step_pattern_rec.eject = hills[1][h].eject
    hills[1].base_step_pattern:watch(base_step_pattern_rec)
  elseif n == 3 then
    local h = hills[1].screen_focus
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

  --- doesn't really work....
  for x = 1,128 do
    if #hills[i].base_step_pattern.entries[x] > 0 then
      for k,v in pairs(hills[i].base_step_pattern.entries[x]) do
        -- print(k,v)
        hills[i].base_step_pattern.entries[x][k].base_step = util.linlin(0,pre_change_duration,0,hills[i][j].duration,v.base_step)
      end
    end
  end
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
shuffle = function(i,j)
  add_undo_step(i)
  local shuffled = {}
  for m = hills[i][j].min,hills[i][j].max do
    local pos = math.random(1, #shuffled+1)
	  table.insert(shuffled, pos, hills[i].notes[m])
  end
  for k,v in pairs(shuffled) do
    hills[i].notes[k] = v
  end
end

redraw = function()
  if screen_dirty then
    screen.clear()
    -- for i = 1,2 do
    --   screen.move(0,10*i)
    --   local scaled_min = util.round((hills[i][hills[i].screen_focus].base_step/hills[i][hills[i].screen_focus].duration)*100)
    --   local scaled_max = util.round((hills[i][hills[i].screen_focus].eject/hills[i][hills[i].screen_focus].duration)*100)
    --   screen.text("hill "..hills[i].screen_focus.." | min: "..scaled_min.."% | max: "..scaled_max.."%")
    -- end
    screen.level(15)
    for i = 1,60 do
      screen.pixel(i,util.linlin(1,60,60,10,shape_data[1][1][i]))
    end
    screen.fill()
    screen.update()
    screen_dirty = false
  end
end

clock.transport.start = function()
  -- p_rec.blast_off()
end

parse_pattern = function(r)
  local h = hills[r.hill_id][r.hill_sub]
  h.duration = r.duration
  h.base_step = r.base_step
  h.eject = r.eject
  screen_dirty = true
  one_shot(r.hill_id,r.hill_sub)
end

parse_base_step_pattern = function(r)
  local h = hills[r.hill_id][r.hill_sub]
  h.base_step = util.clamp(r.base_step+r.base_step_delta/(100/r.duration),0,r.eject-0.01)
  screen_dirty = true
end

-- record_this = {}
-- record_this.hill_id = i
-- record_this.hill_sub = j
-- record_this.duration = seg.duration
-- record_this.base_step = seg.base_step
-- record_this.eject = seg.eject