-- if construct is interrrupted, clamp to that time/step

-- note_timestamp holds each step's place in the total timescale
-- note_timedelta holds each step's duration

curves = include 'lib/easing'
prms = include 'lib/parameters'
_t = include 'lib/transformations'
_a = include 'lib/actions'
_g = include 'lib/grid_lib'
_p = include 'lib/new-patterning'
_e = include 'lib/enc_actions'
_k = include 'lib/key_actions'
_s = include 'lib/screen_actions'
mu = require 'musicutil'
engine.name = "Krick"

r = function()
  norns.script.load("code/a-hills/hills2.lua")
end

for i = 1,3 do
  norns.enc.sens(i,2)
end

function midi_to_hz(note)
  return (440 / 32) * (2 ^ ((note - 9) / 12))
end

function init()
  math.randomseed(os.time())
  _g.init()
  _p.init()
  key1_hold = false
  
  ui = {}
  ui.control_set = "play"
  ui.display_style = "single"
  ui.edit_note = {}
  ui.hill_focus = 1
  ui.menu_focus = 1
  ui.screen_controls = {}
  ui.seq_menu_focus = 1
  ui.seq_menu_layer = "nav"
  ui.seq_controls = {}
  ui.pattern_focus = {"s1","s1","s1","s1"}

  hills = {}

  pre_note = {}
  midi_device = {}
  for i = 1,#midi.vports do -- query all ports
    midi_device[i] = midi.connect(i) -- connect each device
  end

  scale_names = {}
  for i = 1,#mu.SCALES do
    table.insert(scale_names,mu.SCALES[i].name)
  end
  prms.init()

  for i = 1,8 do
    ui.edit_note[i] = {}
    hills[i] = {}
    hills[i].mode = "iterate"
    -- hills[i].counter = metro.init()
    -- hills[i].counter.time = 0.01
    -- hills[i].counter.event = function() _G[hills[i].mode](i) end
    hills[i].counter = clock.run(function() _G[hills[i].mode](i) end)
    hills[i].active = false

    -- hills[i].iterate_counter = metro.init()
    -- hills[i].iterate_counter.time = 0.01
    -- hills[i].iterate_counter.event = function() iterate(i) end

    hills[i].note_scale = mu.generate_scale_of_length(60,1,28)
    hills[i].segment = 1
    ui.seq_controls[i] =
    {
      ["seq"] = {["focus"] = 1}
    , ["trig_detail"] = {["focus"] = 1, ["max"] = 3}
    }
    ui.screen_controls[i] = {}
    ui.screen_controls[i] =
    {
      ["seq"] = {["focus"] = 1}
    }

    for j = 1,8 do
      hills[i][j] = {}
      hills[i][j].edit_position = 1
      -- hills[i][j].duration = util.round(clock.get_beat_sec() * math.random(8,15),0.01) -- in seconds
      hills[i][j].duration = util.round(clock.get_beat_sec() * 10,0.01)
      hills[i][j].eject = hills[i][j].duration
      hills[i][j].base_step = 0
      hills[i][j].population = 1
      hills[i][j].current_val = 0
      hills[i][j].step = 0
      hills[i][j].index = 1
      hills[i][j].note_ocean = mu.generate_scale_of_length(params:get("hill "..i.." base note"),params:get("hill "..i.." scale"),127) -- the full range of notes
      -- hills[i][j].note_ocean = {70,62,63,65,67,70,72,79,84,85,63,77,75}
      hills[i][j].timing = {}
      hills[i][j].shape =  params:string("hill ["..i.."]["..j.."] shape")
      hills[i][j].constructed = false
      hills[i][j].low_bound = {}
      hills[i][j].low_bound.note = 1
      hills[i][j].high_bound = {}
      hills[i][j].high_bound.note = nil
      hills[i][j].high_bound.time = hills[i][j].duration
      hills[i][j].bound_mode = "note"
      hills[i][j].loop = false

      hills[i][j].note_num = -- this is where we track the note entries for the constructed hill
      {
        ["min"] = 1, -- defines the lowest note degree
        ["max"] = 12, -- defines the highest note degree
        ["pool"] = {} -- gets filled with the constructed hill's notes
      }
        
      hills[i][j].note_timestamp = {}
      hills[i][j].note_timedelta = {}

      hills[i][j].counter_div = 1

      construct(i,j)
      _t.shuffle(i,j,hills[i][j].low_bound.note,hills[i][j].high_bound.note)

      ui.edit_note[i][j] = 1
      ui.screen_controls[i][j] =
      {
        ["bounds"] = {["focus"] = 1, ["max"] = 2}
      , ["notes"] = {["focus"] = 1, ["max"] = 12, ["transform"] = "shuffle"}
      , ["loop"] = {["focus"] = 1, ["max"] = 2}
      }
    end

    -- hills[i].counter.count = -1
    -- hills[i].iterate_counter.count = (hills[1][1].duration * 100)+1
    hills[i].screen_focus = 1
    clock.run(function()
      while true do
        clock.sleep(1/15)
        if screen_dirty then
          redraw()
        end
      end
    end)
  end
end

process_events = function(i)
  _G[hills[i].mode](i)
end

construct = function(i,j)
  local h = hills[i]
  local seg = h[j]
  local total_notes = util.round(#seg.note_ocean*seg.population)
  local index = 0
  local reasonable_max = seg.note_num.min ~= seg.note_num.max and seg.note_num.max or seg.note_num.min+1
  for k = 0,seg.duration*100 do
    local last_val = seg.current_val
    seg.current_val = math.floor(util.wrap(curves[seg.shape](k/100,1,total_notes-1,seg.duration),seg.note_num.min,reasonable_max))
    local note_num = seg.note_num.min ~= seg.note_num.max and seg.current_val or seg.note_num.min
    if util.round(last_val) ~= util.round(seg.current_val) then
      index = index + 1
      pass_data_into_storage(i,j,index,{note_num,k/100})
    end
  end
  -- hills[i][j].high_bound.note = 
  calculate_timedeltas(i,j)
  screen_dirty = true
end

pass_data_into_storage = function(i,j,index,data)
  hills[i][j].note_num.pool[index] = data[1]
  hills[i][j].note_timestamp[index] = data[2]
  hills[i][j].high_bound.note = #hills[i][j].note_num.pool
end

calculate_timedeltas = function(i,j)
  for k = 1,#hills[i][j].note_timestamp do
    if k < #hills[i][j].note_timestamp then
      hills[i][j].note_timedelta[k] = hills[i][j].note_timestamp[k+1] - hills[i][j].note_timestamp[k]
    else
      hills[i][j].note_timedelta[k] = 0.01
    end
  end
end

iterate = function(i)
  while true do
    clock.sync(1/100)
    if hills[i].active then
      local h = hills[i]
      local seg = h[h.segment]
      if seg.loop then
        if seg.high_bound.note ~= seg.low_bound.note then
          if seg.note_timestamp[seg.index] ~= nil then
            if util.round(seg.note_timestamp[seg.index],0.01) == util.round(seg.step,0.01) then
              pass_note(i,hills[i].segment,seg,seg.note_num.pool[seg.index],"midi")
              pass_note(i,hills[i].segment,seg,seg.note_num.pool[seg.index],"crow-v8_jf-pulse")
              screen_dirty = true
              seg.index = seg.index + 1
            end
            seg.step = util.round(seg.step + 0.01,0.01)
            local reasonable_max = seg.note_timestamp[seg.high_bound.note+1] ~= nil and seg.note_timestamp[seg.high_bound.note+1] or seg.note_timestamp[seg.high_bound.note] + seg.note_timedelta[seg.high_bound.note]
            if util.round(seg.step,0.01) >= util.round(reasonable_max,0.01) then
              _a.one_shot(i,h.segment)
            end
          end
        else
          if util.round(seg.note_timestamp[seg.index+1],0.01) == util.round(seg.step,0.01) then
            pass_note(i,hills[i].segment,seg,seg.note_num.pool[seg.index],"midi")
            pass_note(i,hills[i].segment,seg,seg.note_num.pool[seg.index],"crow-v8_jf-pulse")
            screen_dirty = true
            seg.step = seg.note_timestamp[seg.index]
          else
            seg.step = util.round(seg.step + 0.01,0.01)
            -- seg.step = 
          end
        end
      else
        if seg.index <= seg.high_bound.note then
          if util.round(seg.note_timestamp[seg.index],0.01) == util.round(seg.step,0.01) then
            -- print(seg.index,seg.note_timestamp[seg.index],seg.note_num.pool[seg.index],seg.step)
            pass_note(i,hills[i].segment,seg,seg.note_num.pool[seg.index],"midi")
            pass_note(i,hills[i].segment,seg,seg.note_num.pool[seg.index],"crow-v8_jf-pulse")
            screen_dirty = true
            -- seg.index = util.clamp(seg.index + 1,seg.low_bound.note,seg.high_bound.note)
            seg.index = seg.index + 1
          end
          seg.step = util.round(seg.step + 0.01,0.01)
          local comparator;
          if seg.bound_mode == "time" then
            comparator = util.round(seg.step,0.01) > util.round(seg.high_bound.time,0.01)
          elseif seg.bound_mode == "note" then
            comparator = seg.index > seg.high_bound.note
          end
          if comparator then -- if `>` then this get us a final tick, which is technically duration + 0.01
            print("stopping")
            -- h.counter:stop()
            -- clock.cancel(hills[i].counter)
            hills[i].active = false
            seg.iterated = true
            seg.step = seg.note_timestamp[seg.low_bound.note] -- reset
            screen_dirty = true
            local ch = params:get("hill "..i.." MIDI note channel")
            local dev = params:get("hill "..i.." MIDI device")
            midi_device[dev]:note_off(pre_note[i],seg.velocity,ch)
            -- seg.index = seg.low_bound.note -- reset
          end
        end
      end
    end
  end
end

inject = function(shape,i,injection_point,duration)
  local h = hills[i]
  local seg = h[h.segment]
  local total_notes = util.round(#seg.note_ocean*seg.population)
  local index = injection_point-1
  local current_val = 0
  local reasonable_max = seg.note_num.min ~= seg.note_num.max and seg.note_num.max or seg.note_num.min+1
  for j = seg.note_timestamp[injection_point+1]*100,(seg.note_timestamp[injection_point]+duration)*100 do
    local last_val = current_val
    current_val = math.floor(util.wrap(curves[shape](j/100,1,total_notes-1,duration),seg.note_num.min,reasonable_max))
    local note_num = seg.note_num.min ~= seg.note_num.max and current_val or seg.note_num.min
    if util.round(last_val) ~= util.round(current_val) then
      index = index + 1
      inject_data_into_storage(i,h.segment,index,{note_num,j/100})
    end
  end
  adjust_timestamps_for_injection(i,h.segment,index+1,duration)
end

inject_data_into_storage = function(i,j,index,data)
  table.insert(hills[i][j].note_num.pool, index, data[1])
  table.insert(hills[i][j].note_timestamp, index, data[2])
  hills[i][j].high_bound.note = #hills[i][j].note_num.pool
end

adjust_timestamps_for_injection = function(i,j,index,duration)
  for k = index,#hills[i][j].note_timestamp do
    hills[i][j].note_timestamp[k] = hills[i][j].note_timestamp[k] + duration
  end
  hills[i][j].high_bound.time = hills[i][j].note_timestamp[#hills[i][j].note_timestamp]
  calculate_timedeltas(i,j)
end

pass_note = function(i,j,seg,note_val,destination)
  local midi_notes = hills[i][j].note_ocean
  local played_note = midi_notes[note_val]
  -- print(hills[i][j].index,i,j,note_val,midi_notes[note_val])
  if destination == "engine" then
    if i < 4 then
      engine.hz(midi_to_hz(played_note))
    end
  elseif destination == "midi" then
    local ch = params:get("hill "..i.." MIDI note channel")
    local dev = params:get("hill "..i.." MIDI device")
    if pre_note[i] ~= nil then
      midi_device[dev]:note_off(pre_note[i],seg.velocity,ch)
    end
    midi_device[dev]:note_on(played_note,seg.velocity,ch)
    for j = 1,5 do
      if params:string("hill "..i.." cc_"..j) ~= "none" then
        midi_device[dev]:cc(params:get("hill "..i.." cc_"..j),seg.cc_val,params:get("hill "..i.." cc_"..j.."_ch"))
      end
    end
    -- midi_device[4]:cc(18,seg.cc_val,9)
    pre_note[i] = played_note
  elseif destination == "crow_pulse" then
    crow.output[i+2]()
  elseif destination == "crow-v8_jf-pulse" then
    crow.output[i].volts = (played_note-60)/12
    crow.ii.jf.trigger(i,1)
  end
end

function enc(n,d)
  _e.parse(n,d)
end

function key(n,z)
  _k.parse(n,z)
end

redraw = function()
  _s.draw()
end

function index_to_grid_pos(val,columns)
  local x = math.fmod(val-1,columns)+1
  local y = math.modf((val-1)/columns)+1
  return {x,y}
end