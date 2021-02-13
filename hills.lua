-- hills

curves = include 'lib/easing'
engine.name = "PolyPerc"

r = function()
  norns.script.load("code/hills/hills.lua")
end

function init()
  midi_notes = {70,74,63,65,67,62,72,70,60,55,77,70,74,75,63,67}
  hills = {}
  for i = 1,2 do
    hills[i] = {{},{},{},{}}
    hills[i].segment = 1
    hills[i].active = false
    for j = 1,4 do
      hills[i][j].step = 0
      hills[i][j].duration = util.round(clock.get_beat_sec() * math.random(4),0.01) -- in seconds
      -- hills[i][j].base_step = math.random(0,util.round(hills[i][j].duration*1000-1)) / 1000
      hills[i][j].base_step = 0
      hills[i][j].current_val = 0
      hills[i][j].shape = curves.easingNames[math.random(#curves.easingNames)]
      hills[i][j].min = 1
      hills[i][j].max = math.random(#midi_notes)
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
  miniii = 1
  maxiii = #midi_notes
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
  -- seg.current_val = util.linlin(0,127,1,#midi_notes,curves[seg.shape](seg.step,0,127,seg.duration))
  seg.current_val = util.wrap(curves[seg.shape](seg.step,1,#midi_notes-1,seg.duration),seg.min,seg.max)
  seg.step = util.round(seg.step + 0.01,0.01)
  if util.round(pre_change) ~= util.round(seg.current_val) then
    print(midi_notes[ util.wrap(util.round(math.abs(seg.current_val)),1,#midi_notes) ], seg.step, seg.current_val, math.abs(seg.current_val))
    engine.cutoff(seg.step*1000)
    engine.hz(midi_to_hz( midi_notes[ util.wrap(util.round(math.abs(seg.current_val)),1,#midi_notes) ] + seg.random_octaves[math.random(#seg.random_octaves)] ))
    engine.release(seg.step/2)
  end
  if util.round(seg.step,0.01) == util.round(seg.duration,0.01) then
    seg.counter:stop()
    print("stopping", seg.counter.is_running)
    if h.segment < 4 then
      h.segment = h.segment + 1
      toggle_iterator(false,i)
    elseif h.segment == 4 then
      h.active = false
    end
    -- toggle_iterator(false,i)
  end
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
    hills[1].segment = 1
    toggle_iterator(hills[1][1].counter.is_running,1)
  elseif n == 2 and z == 1 then
    hills[2][hills[2].segment].counter:stop()
    hills[2].segment = 1
    toggle_iterator(hills[2][1].counter.is_running,2)
  end
end