-- hills
--
-- __/\______/\\___
-- ____/\\\\\___/\_
-- /\///_____/\\\__

kildare = include('kildare/lib/kildare')

engine.name = "Kildare"

number_of_hills = 10
hill_names = {
  "[1] (bd)",
  "[2] (sd)",
  "[3] (tm)",
  "[4] (cp)",
  "[5] (rs)",
  "[6] (cb)",
  "[7] (hh)",
  "[8] (s1)",
  "[9] (s2)",
  "[10] (s3)"
}

pt = include 'lib/hills_pt'
curves = include 'lib/easing'
prms = include 'lib/parameters'
_t = include 'lib/transformations'
_a = include 'lib/actions'
_g = include 'lib/grid_lib'
_e = include 'lib/enc_actions'
_k = include 'lib/key_actions'
_s = include 'lib/screen_actions'
_flow = include 'lib/flow'
_song = include 'lib/song'
_ca = include 'lib/clip'
_snapshots = include 'lib/snapshot'
sc_lfos = include 'lib/sc_lfos'
mu = require 'musicutil'

r = function()
  norns.script.load("code/hills/hills.lua")
end

function grid.add(dev)
  grid_dirty = true
end

for i = 1,3 do
  norns.enc.sens(i,2)
end

function midi_to_hz(note)
  return (440 / 32) * (2 ^ ((note - 9) / 12))
end

function init()
  kildare.init()
  kildare_drums = {"bd","sd","tm","cp","rs","cb","hh"}
  _ca.init() -- initialize clips
  _snapshots.init()
  _flow.init()
  _song.init()
  math.randomseed(os.time())
  _g.init()
  key1_hold = false
  key2_hold = false

  key2_hold_counter = metro.init()
  key2_hold_counter.time = 0.25
  key2_hold_counter.count = 1
  key2_hold_counter.event =
    function()
      key2_hold = true
      print("K2 held!")
      screen_dirty = true
    end

  
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
  -- prms.reload_engine(params:string("global engine"),true)

  for i = 1,number_of_hills do
    ui.edit_note[i] = {}

    hills[i] = {}
    hills[i].mode = "iterate"
    hills[i].active = false
    hills[i].crow_change_queued = false

    hills[i].note_scale = mu.generate_scale_of_length(60,1,28)
    hills[i].segment = 1
    hills[i].looper = {["clock"] = nil}

    hills[i].snapshot = {["partial_restore"] = false}
    hills[i].snapshot.restore_times = {["beats"] = {1,2,4,8,16,32,64,128}, ["time"] = {1,2,4,8,16,32,64,128}, ["mode"] = "beats"}
    hills[i].snapshot.mod_index = 0
    hills[i].snapshot.focus = 0
    
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
      hills[i][j].duration = util.round(clock.get_beat_sec() * 16,0.01)
      hills[i][j].eject = hills[i][j].duration
      hills[i][j].base_step = 0
      hills[i][j].population = math.random(10,100)/100
      hills[i][j].current_val = 0
      hills[i][j].step = 0
      hills[i][j].index = 1
      hills[i][j].note_ocean = mu.generate_scale_of_length(params:get("hill "..i.." base note"),params:get("hill "..i.." scale"),127) -- the full range of notes
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
      hills[i][j].looper = {
        ["clock"] = nil,
        ["runner"] = 1,
        ["mode"] = "phase",
        ["clock_time"] = 0
      }
      hills[i][j].playmode = "momentary"
      hills[i][j].counter_div = 1
      hills[i][j].perf_led = false
      hills[i][j].iterated = true

      hills[i][j].note_num = -- this is where we track the note entries for the constructed hill
      {
        ["min"] = 1, -- defines the lowest note degree
        ["max"] = 15, -- defines the highest note degree
        ["pool"] = {}, -- gets filled with the constructed hill's notes
        ["active"] = {} -- tracks whether the note should play
      }

      hills[i][j].softcut_controls = -- this is where we track the slices for the constructed hill
      {
        ["loop"] = {}, -- gets filled with the constructed hill's loop states
        ["rate"] = {} -- gets filled with the constructed hill's rates
      }

      hills[i][j].note_timestamp = {}
      hills[i][j].note_timedelta = {}

      construct(i,j,true)

      ui.edit_note[i][j] = 1
      ui.screen_controls[i][j] =
      {
        ["hills"] = {["focus"] = 1, ["max"] = 12}
      , ["bounds"] = {["focus"] = 1, ["max"] = 2}
      , ["notes"] = {["focus"] = 1, ["max"] = 12, ["transform"] = "shuffle"}
      , ["loop"] = {["focus"] = 1, ["max"] = 2}
      }
    end

    hills[i].counter = clock.run(function() _G[hills[i].mode](i) end)

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

  params.action_read = function(filename)
    for i = 1,number_of_hills do
      if hills[i].active then
        stop(i,true)
      end
      hills[i] = tab.load(_path.data.."hills/"..params.name.."/data/"..i..".txt")
      if hills[i].active then
        stop(i,true)
      end
    end
    for j = 1,16 do
      if grid_pattern[j].play == 1 then
        _g.stop_pattern_playback(j)
      end
      local to_inherit = tab.load(_path.data.."hills/"..params.name.."/patterns/"..j..".txt")
      grid_pattern[j].event = to_inherit.event
      grid_pattern[j].count = #grid_pattern[j].event
      grid_pattern[j].time = to_inherit.time
    end
    for j = 1,#song_atoms do
      song_atoms[j] = tab.load(_path.data.."hills/"..params.name.."/song/"..j..".txt")
    end
    snapshots = tab.load(_path.data.."hills/"..params.name.."/snapshots/all.txt")
    params:bang()
    grid_dirty = true
  end

  params.action_write = function(filename,name)
    os.execute("mkdir -p ".._path.data.."hills/"..name.."/data")
    os.execute("mkdir -p ".._path.data.."hills/"..name.."/patterns")
    os.execute("mkdir -p ".._path.data.."hills/"..name.."/song")
    os.execute("mkdir -p ".._path.data.."hills/"..name.."/snapshots")
    for i = 1,number_of_hills do
      tab.save(hills[i],_path.data.."hills/"..name.."/data/"..i..".txt")
    end
    for i = 1,16 do
      tab.save(grid_pattern[i],_path.data.."hills/"..name.."/patterns/"..i..".txt")
    end
    for i = 1,#song_atoms do
      tab.save(song_atoms[i],_path.data.."hills/"..name.."/song/"..i..".txt")
    end
    tab.save(snapshots,_path.data.."hills/"..name.."/snapshots/all.txt")
  end

end

process_events = function(i)
  _G[hills[i].mode](i)
end

construct = function(i,j,shuffle)
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
  calculate_timedeltas(i,j)
  if shuffle then
    _t.shuffle(i,j,hills[i][j].low_bound.note,hills[i][j].high_bound.note)
  end
  screen_dirty = true
end

reconstruct = function(i,j,new_shape)
  local h = hills[i]
  local seg = h[j]
  -- keep min and max timestamps the same...
  local beginVal = seg.note_timestamp[seg.low_bound.note]
  local endVal = seg.note_timestamp[seg.high_bound.note]
  local change = endVal - beginVal
  local duration = endVal - beginVal
  for k = seg.low_bound.note,seg.high_bound.note do
    print(curves[new_shape](seg.note_timestamp[k],beginVal,change,duration))
    local new_timestamp = curves[new_shape](seg.note_timestamp[k],beginVal,change,duration)
    seg.note_timestamp[k] = new_timestamp
  end
  calculate_timedeltas(i,j)
  screen_dirty = true
end

pass_data_into_storage = function(i,j,index,data)
  hills[i][j].note_num.pool[index] = data[1]
  hills[i][j].note_timestamp[index] = data[2]
  hills[i][j].high_bound.note = #hills[i][j].note_num.pool
  hills[i][j].note_num.active[index] = true

  hills[i][j].softcut_controls.loop[index] = false
  hills[i][j].softcut_controls.rate[index] = 9 -- mirrors ("speed_clip_"..i) in parameters
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
    clock.sync(1/(32*hills[i][hills[i].segment].counter_div))
    if hills[i].active then
      local h = hills[i]
      local seg = h[h.segment]
      if seg.loop then
        if seg.high_bound.note ~= seg.low_bound.note then
          if seg.note_timestamp[seg.index] ~= nil then
            if util.round(seg.note_timestamp[seg.index],0.01) == util.round(seg.step,0.01) then
              pass_note(i,hills[i].segment,seg,seg.note_num.pool[seg.index],seg.index)
              screen_dirty = true
              seg.index = seg.index + 1
              seg.perf_led = true
              grid_dirty = true 
            else
              grid_dirty = true
            end
            seg.step = util.round(seg.step + 0.01,0.01)
            local reasonable_max = seg.note_timestamp[seg.high_bound.note+1] ~= nil and seg.note_timestamp[seg.high_bound.note+1] or seg.note_timestamp[seg.high_bound.note] + seg.note_timedelta[seg.high_bound.note]
            if util.round(seg.step,0.01) >= util.round(reasonable_max,0.01) then
              if seg.looper.mode == "phase" then
                _a.start(i,h.segment)
              else
                stop(i)
              end
            end
          end
        elseif not seg.loop then
          print("WHY WOULD THIS EVER HAPPEN ANYWAY??")
          -- if util.round(seg.note_timestamp[seg.index+1],0.01) == util.round(seg.step,0.01) then
          --   pass_note(i,hills[i].segment,seg,seg.note_num.pool[seg.index],seg.index)
          --   screen_dirty = true
          --   seg.step = seg.note_timestamp[seg.index]
          --   seg.perf_led = true
          --   grid_dirty = true 
          -- else
          --   seg.step = util.round(seg.step + 0.01,0.01)
          --   grid_dirty = true
          -- end
        end
      else
        seg.iterated = false
        if seg.index <= seg.high_bound.note then
          if util.round(seg.note_timestamp[seg.index],0.01) == util.round(seg.step,0.01) then
            -- print(seg.index,seg.note_timestamp[seg.index],seg.note_num.pool[seg.index],seg.step)
            pass_note(i,hills[i].segment,seg,seg.note_num.pool[seg.index],seg.index)
            screen_dirty = true
            seg.index = seg.index + 1
            seg.perf_led = true
            grid_dirty = true
          else
            -- seg.perf_led = false
            grid_dirty = true
          end
          seg.step = util.round(seg.step + 0.01,0.01)
          local comparator;
          if seg.bound_mode == "time" then
            comparator = util.round(seg.step,0.01) > util.round(seg.high_bound.time,0.01)
          elseif seg.bound_mode == "note" then
            comparator = seg.index > seg.high_bound.note
          end
          if comparator then -- if `>` then this get us a final tick, which is technically duration + 0.01
            stop(i,true)
          end
        end
      end
    end
  end
end

stop = function(i,clock_synced_loop)
  local h = hills[i]
  local seg = h[h.segment]
  seg.perf_led = true
  hills[i].active = false
  seg.iterated = true
  seg.step = seg.note_timestamp[seg.low_bound.note] -- reset
  screen_dirty = true
  local ch = params:get("hill "..i.." MIDI note channel")
  local dev = params:get("hill "..i.." MIDI device")
  grid_dirty = true
  seg.end_of_cycle_clock = clock.run(
    function()
      clock.sleep(1/15)
      if seg.iterated then
        seg.perf_led = false
        grid_dirty = true
        if params:string("hill "..i.." MIDI output") == "yes" then
          midi_device[dev]:note_off(pre_note[i],seg.velocity,ch)
        end
        if params:string("hill "..i.." JF output") == "yes" then
          local ch = params:get("hill "..i.." JF output id")
          if pre_note[i] ~= nil then
            if params:string("hill "..i.." JF output style") == "sound" then
              crow.ii.jf.play_voice(ch,0)
            elseif params:string("hill "..i.." JF output style") == "shape" then
              crow.ii.jf.trigger(ch,0)
            end
          end
        end
      end
    end
  )
  if clock_synced_loop then
    if hills[i].looper.clock ~= nil then
      _a.kill_clock(i)
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

get_random_offset = function(i,note)
  if params:get("hill "..i.." random offset probability") == 0 then
    return note
  elseif params:get("hill "..i.." random offset probability") >= math.random(0,100) then
    if params:string("hill "..i.." random offset style") == "+ oct" then
      if note + 12 <= 127 then
        return note + 12
      else
        return note
      end
    elseif params:string("hill "..i.." random offset style") == "- oct" then
      if note + 12 >= 0 then
        return note - 12
      else
        return note
      end
    elseif params:string("hill "..i.." random offset style") == "+/- oct" then
      local modifier = math.random(0,100) <= 50 and 12 or -12;
      if (note + modifier >= 0) and (note + modifier <=127) then
        return note + modifier
      else
        return note
      end
    end 
  else
    return note
  end
end

pass_note = function(i,j,seg,note_val,index,destination)
  local midi_notes = hills[i][j].note_ocean
  local played_note = get_random_offset(i,midi_notes[note_val])
  if played_note ~= nil and hills[i][j].note_num.active[index] then
    if i <= 7 then
      if params:string("hill "..i.." kildare_notes") == "yes" then
        engine.set_param(kildare_drums[i],"carHz",midi_to_hz(played_note))
      end
      engine.trig(kildare_drums[i])
      if params:string("hill "..i.." softcut output") == "yes" then
        if params:get("hill "..i.." softcut probability") >= math.random(100) then
          -- print("489",i,j,played_note)
          _ca.calculate_sc_positions(i,j,played_note)
        end
      end
    else
      -- TRIGGER SOFTCUT
      -- TODO: all 6 softcut voices are distributed on the channel
      -- TODO: we can also just assign a drum voice to do the same manipulation...!
      if params:string("hill "..i.." softcut output") == "yes" then
        if params:get("hill "..i.." softcut probability") >= math.random(100) then
          if params:string("hill "..i.." reset softcut level lfo") == "yes" then
            sc_lfos.reset_phase_from_hill(i-7,params:string("hill "..i.." reset softcut level lfo style"))
          end
          -- if params:string("hill "..i.." reset softcut pan lfo") == "yes" then
          --   sc_lfos.reset_phase_from_hill(i-4,params:string("hill "..i.." reset softcut pan lfo style"))
          -- end
          -- if params:string("hill "..i.." reset softcut filter lfo") == "yes" then
          --   sc_lfos.reset_phase_from_hill(i-1,params:string("hill "..i.." reset softcut filter lfo style"))
          -- end
          _ca.calculate_sc_positions(i,j,played_note)
        end
      end
    end
    if params:string("hill "..i.." MIDI output") == "yes" then
      local ch = params:get("hill "..i.." MIDI note channel")
      local dev = params:get("hill "..i.." MIDI device")
      if pre_note[i] ~= nil then
        midi_device[dev]:note_off(pre_note[i],seg.velocity,ch)
      end
      midi_device[dev]:note_on(played_note,seg.velocity,ch)
    end
    if params:string("hill "..i.." crow output") == "yes" then
      if params:string("hill "..i.." crow output style") == "osc" then
        local out = params:get("hill "..i.." crow output id")
        if hills[i].crow_change_queued then
          crow.output[out].action = "oscillate( dyn{pitch="..mu.note_num_to_freq(played_note).."}, dyn{lev="..(params:get("hill "..i.." crow osc level")/100).."}:mul(dyn{dur="..(params:get("hill "..i.." crow osc decay")/100).."}), '"..params:string("hill "..i.." crow osc shape").."')"
          crow.output[out]()
          if params:string("hill "..i.." crow osc aliasing") == 'none' then
            crow.output[out].scale('none')
          elseif params:string("hill "..i.." crow osc aliasing") == 'soft' then
            crow.output[out].scale({0,2,3,5,7,8,10})
          elseif params:string("hill "..i.." crow osc aliasing") == 'harsh' then
            crow.output[out].scale({0})
          end
          hills[i].crow_change_queued = false
        else
          if params:string("hill "..i.." crow osc aliasing") == 'none' then
            crow.output[out].scale('none')
          elseif params:string("hill "..i.." crow osc aliasing") == 'soft' then
            crow.output[out].scale({0,2,3,5,7,8,10})
          elseif params:string("hill "..i.." crow osc aliasing") == 'harsh' then
            crow.output[out].scale({0})
          end
          crow.output[out].dyn.pitch = mu.note_num_to_freq(played_note)
          crow.output[out].dyn.lev = params:get("hill "..i.." crow osc level")/100
          crow.output[out].dyn.dur = params:get("hill "..i.." crow osc decay")/100
        end
      elseif params:string("hill "..i.." crow output style") == "v/8" then
        local out = params:get("hill "..i.." crow output id")
        crow.output[out].scale('none')
        -- crow.output[out].volts = (played_note - params:get("hill "..i.." base note"))/12
        crow.output[out].volts = (played_note - 60)/12
      elseif params:string("hill "..i.." crow output style") == "v/8+pulse" then
        local v8_out = params:get("hill "..i.." crow output id")
        local pulse_out = params:get("hill "..i.." crow v/8 pulse output id")
        crow.output[v8_out].scale('none')
        crow.output[v8_out].volts = (played_note - 60)/12
        norns.crow.send ("output["..pulse_out.."]( pulse(0.001) )")
      elseif params:string("hill "..i.." crow output style") == "pulse" then
        local out = params:get("hill "..i.." crow output id")
        norns.crow.send ("output["..out.."]( pulse(0.001) )")
      end
    end
    if params:string("hill "..i.." JF output") == "yes" then
      local ch = params:get("hill "..i.." JF output id")
      if pre_note[i] ~= nil then
        if params:string("hill "..i.." JF output style") == "sound" then
          crow.ii.jf.play_voice(ch,0)
        elseif params:string("hill "..i.." JF output style") == "shape" then
          crow.ii.jf.trigger(ch,0)
        end
      end
      if params:string("hill "..i.." JF output style") == "sound" then
        crow.ii.jf.play_voice(ch,(played_note - 60)/12,5)
        print(ch,(played_note - 60)/12,5)
      elseif params:string("hill "..i.." JF output style") == "shape" then
        crow.ii.jf.trigger(ch,1)
      end
    end
    pre_note[i] = played_note
  end
end

function enc(n,d)
  if ui.control_set ~= "song" then
    _e.parse(n,d)
  else
    _flow.process_encoder(n,d)
  end
  screen_dirty = true
end

function key(n,z)
  if ui.control_set ~= "song" then
    _k.parse(n,z)
  else
    _flow.process_key(n,z)
  end
  screen_dirty = true
end

redraw = function()
  screen.clear()
  if ui.control_set ~= "song" then
    _s.draw()
  else
    _flow.draw_menu()
  end
  screen.update()
  screen_dirty = false
end

function index_to_grid_pos(val,columns)
  local x = math.fmod(val-1,columns)+1
  local y = math.modf((val-1)/columns)+1
  return {x,y}
end