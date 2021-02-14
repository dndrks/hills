-- hills

curves = include 'lib/easing'
prms = include 'lib/parameters'
mu = require 'musicutil' -- with this, min/max are windows of notes
engine.name = "PolyPerc"

r = function()
  norns.script.load("code/hills/hills.lua")
end

function init()
  -- midi_notes = {70,74,63,65,67,62,72,70,60,55,77,70,74,75,63,67}
  scale_names = {}
  for i = 1,#mu.SCALES do
    table.insert(scale_names,mu.SCALES[i].name)
  end
  midi_note_dest = {8,9,11,6,4,5,7}
  midi_device = {}
  for i = 1,#midi.vports do -- query all ports
    midi_device[i] = midi.connect(i) -- connect each device
  end
  hills = {}
  prms.init()
  for i = 1,2 do
    hills[i] = {{},{},{},{},{},{},{},{}}
    hills[i].active = false
    hills[i].min = 1
    hills[i].max = #hills[i]
    hills[i].segment = hills[i].min
    hills[i].notes = mu.generate_scale(60,params:get("hill "..i.." scale"),2)
    for j = 1,#hills[i] do
      hills[i][j].step = 0
      hills[i][j].duration = util.round(clock.get_beat_sec() * math.random(4),0.01) -- in seconds
      -- hills[i][j].base_step = math.random(0,util.round(hills[i][j].duration*1000-1)) / 1000
      hills[i][j].base_step = 0
      hills[i][j].current_val = 0
      hills[i][j].shape = curves.easingNames[math.random(#curves.easingNames)]
      hills[i][j].min = 1
      hills[i][j].max = math.random(#hills[i].notes)
      hills[i][j].random_octaves = {0}
      hills[i][j].counter = metro.init()
      hills[i][j].counter.time = 0.01
      hills[i][j].counter.count = hills[i][j].duration * 100
      hills[i][j].counter.event = function() iterate(i) end
    end
  end
  -- midi_notes = {70,74,75,63,67}
  random_octaves = {}
  -- random_octaves[1] = {12,-12,24,0,36}
  random_octaves[1] = {0}
  random_octaves[2] = {-24,-12}
  -- type = "notes"
  -- will want multiple types...note, vel, cc, val
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
    -- if i == 1 then
    --   engine.cutoff(seg.step*1000)
    --   engine.hz(midi_to_hz( midi_notes[ util.wrap(util.round(math.abs(seg.current_val)),1,#midi_notes) ] + seg.random_octaves[math.random(#seg.random_octaves)] ))
    --   engine.release(seg.step/2)
    -- elseif i == 2 then
    --   midi_device[4]:note_on(midi_note_dest[ util.wrap(util.round(math.abs(seg.current_val)),1,#midi_note_dest) ],util.round(util.linlin(0,seg.duration,1,64,seg.step)),1)
    -- end
  end
  if util.round(seg.step,0.01) == util.round(seg.duration,0.01) then
    seg.counter:stop()
    print("stopping", seg.counter.is_running)
    if h.segment < h.max then
      h.segment = h.segment + 1
      toggle_iterator(false,i)
    elseif h.segment == h.max then
      h.active = false
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
  local seg = h[h.segment]
  local midi_notes = h.notes
  local note = midi_note_dest[util.wrap(util.round(math.abs(seg.current_val)),1,#midi_note_dest)]
  local vel = util.round(util.linlin(0,seg.duration,1,64,seg.step))
  local ch = 1
  midi_device[4]:note_on(note,vel,ch)
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

key = function(n,z)
  if n == 3 and z == 1 then
    hills[1][hills[1].segment].counter:stop()
    hills[1].segment = hills[1].min
    toggle_iterator(hills[1][1].counter.is_running,1)
  elseif n == 2 and z == 1 then
    hills[2][hills[2].segment].counter:stop()
    hills[2].segment = hills[2].min
    toggle_iterator(hills[2][1].counter.is_running,2)
  end
end

-- 1. TRANSPOSITION
transpose = function(i,delta)
  params:delta("hill "..i.." base note",delta)
end

-- 2. REVERSAL
reverse = function(i,start_point,end_point)
	local rev = {}
	for j = end_point, start_point, -1 do
		rev[end_point - j + 1] = hills[i].notes[j]
	end
  for j = start_point, end_point do
    local range = (end_point-start_point)+1
    hills[i].notes[j] = rev[util.linlin(start_point,end_point,1,range,j)]
  end
end

-- 3. ROTATION: moving from one end to another, so like mirror...
