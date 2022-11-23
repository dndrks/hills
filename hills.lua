-- hills
--
-- __/\______/\\___
-- ____/\\\\\___/\_
-- /\///_____/\\\__

if tonumber(norns.version.update) < 220802 then
  norns.script.clear()
  norns.script.load('code/hills/lib/fail_state.lua')
end

kildare = include('kildare/lib/kildare')

engine.name = "Kildare"

number_of_hills = 10
hill_names = {
  "1: bd",
  "2: sd",
  "3: tm",
  "4: cp",
  "5: rs",
  "6: cb",
  "7: hh",
  "8: s1",
  "9: s2",
  "10: s3"
}

pre_step_page = 'play'

pt = include 'lib/hills_new_pt'
curves = include 'lib/easing'
prms = include 'lib/parameters'
_t = include 'lib/transformations'
_a = include 'lib/actions'
_g = include 'lib/grid_lib'
_e = include 'lib/enc_actions'
_k = include 'lib/key_actions'
_s = include 'lib/screen_actions'
local _flow = include 'lib/flow'
_song = include 'lib/song'
_ca = include 'lib/clip'
_snapshots = include 'lib/snapshot'
_fkprm = include 'lib/fkprm'
_hsteps = include 'lib/highway_steps'
_htracks = include 'lib/highway_tracks'
mu = require 'musicutil'
euclid = require 'er'

r = function()
  norns.script.load("code/hills/hills.lua")
end

development_state = function()
  song_atoms.transport_active = true
  for i = 1,9 do
    hills[i].highway = true
  end
  _htracks.sync_playheads()
  screen_dirty = true
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

local pre_note = {}
local midi_device = {}

local util_round = util.round
local lin_lin = util.linlin

function init()
  print('starting: '..util.time())
  kildare.init(true)
  _ca.init() -- initialize clips
  _snapshots.init()
  _flow.init()
  print('initializing song: '..util.time())
  _song.init()
  math.randomseed(os.time())
  _g.init()
  
  key1_hold = false
  key2_hold = false
  
  _hsteps.init()
  for i = 1,10 do
    _htracks.init(i,1)
  end

  print('initialized tracks: '..util.time())

  key2_hold_counter = metro.init()
  key2_hold_counter.time = 0.25
  key2_hold_counter.count = 1
  key2_hold_counter.event =
    function()
      key2_hold = true
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

  for i = 1,#midi.vports do -- query all ports
    midi_device[i] = midi.connect(i) -- connect each device
  end

  scale_names = {}
  local scale_count = 1
  for i = 1,#mu.SCALES do
    scale_names[scale_count] = mu.SCALES[i].name
    scale_count = scale_count + 1
  end
  
  prms.init()
  _fkprm.init()
  -- prms.reload_engine(params:string("global engine"),true)
  
  for i = 1,number_of_hills do
    ui.edit_note[i] = {}

    hills[i] = {}
    hills[i].mode = "iterate"
    hills[i].highway = false
    hills[i].active = false
    hills[i].crow_change_queued = false

    hills[i].note_scale = mu.generate_scale_of_length(60,1,28)
    hills[i].segment = 1
    hills[i].looper = {["clock"] = nil}

    hills[i].snapshot = {["partial_restore"] = false}
    hills[i].snapshot.restore_times = {["beats"] = {1,2,4,8,16,32,64,128}, ["time"] = {1,2,4,8,16,32,64,128}, ["mode"] = "beats"}
    hills[i].snapshot.mod_index = 0
    hills[i].snapshot.focus = 0

    hills[i].iter_links = {}
    hills[i].iter_pulses = {}
    hills[i].iter_counter = {}
    for j = 1,8 do
      hills[i].iter_links[j] = {}
      hills[i].iter_pulses[j] = {}
      hills[i].iter_counter[j] = {}
      for k = 1,10 do
        hills[i].iter_links[j][k] = 0
        hills[i].iter_pulses[j][k] = 1
        hills[i].iter_counter[j][k] = 1
      end
    end
    
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
      hills[i][j].duration = util_round(clock.get_beat_sec() * 16,0.01)
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
        ["active"] = {}, -- tracks whether the note should play
        ["chord_degree"] = {}, -- defines the shell voicing chord degree
      }
      hills[i][j].note_velocity = {}

      hills[i][j].sample_controls = -- this is where we track the slices for the constructed hill
      {
        ["loop"] = {}, -- gets filled with the constructed hill's loop states
        ["rate"] = {} -- gets filled with the constructed hill's rates
      }

      hills[i][j].note_timestamp = {}
      hills[i][j].note_timedelta = {}
      hills[i][j].mute = false

      construct(i,j,true)

      ui.edit_note[i][j] = 1
      ui.screen_controls[i][j] =
      {
        ["hills"] = {["focus"] = 1, ["max"] = 12}
      , ["bounds"] = {["focus"] = 1, ["max"] = 2}
      , ["notes"] = {["focus"] = 1, ["max"] = 12, ["transform"] = "mute step", ["velocity"] = false}
      , ["loop"] = {["focus"] = 1, ["max"] = 2}
      , ["samples"] = {["focus"] = 1, ["max"] = 12, ["transform"] = "shuffle"}
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

  print('built hills: '..util.time())

  params.action_read = function(filename,name,number)
    print("loading hills data for PSET: "..number)
    for i = 1,number_of_hills do
      if hills[i].active then
        stop(i,true)
      end
      hills[i] = tab.load(_path.data.."hills/"..number.."/data/"..i..".txt")
      -- // TODO: this is temporary for luck dragon performance loading...
      -- shouldn't be needed for release.
      if hills[i].iter_pulses == nil then
        hills[i].iter_pulses = {}
        hills[i].iter_counter = {}
        for j = 1,8 do
          hills[i].iter_pulses[j] = {}
          hills[i].iter_counter[j] = {}
          for k = 1,10 do
            hills[i].iter_pulses[j][k] = 1
            hills[i].iter_counter[j][k] = 1
          end
        end
      end
      for j = 1,8 do
        if hills[i][j].mute == nil then
          hills[i][j].mute = false
        end
      end
      -- //
      if hills[i].active then
        stop(i,true)
      end
    end
    for j = 1,16 do
      if grid_pattern[j].play == 1 then
        _g.stop_pattern_playback(j)
      end
      local to_inherit = tab.load(_path.data.."hills/"..number.."/patterns/"..j..".txt")
      local inheritances = {'end_point', 'count', 'event', 'loop'}
      for adj = 1, #inheritances do
        grid_pattern[j][inheritances[adj]] = to_inherit[inheritances[adj]]
      end
    end
    for j = 1,#song_atoms do
      song_atoms[j] = tab.load(_path.data.."hills/"..number.."/song/"..j..".txt")
    end
    snapshots = tab.load(_path.data.."hills/"..number.."/snapshots/all.txt")
    snapshot_overwrite = tab.load(_path.data.."hills/"..number.."/snapshots/overwrite_state.txt")
    if util.file_exists(_path.data.."hills/"..number.."/per-step/_fkprm.txt") then
      _fkprm.adjusted_params = tab.load(_path.data.."hills/"..number.."/per-step/_fkprm.txt")
    end
    -- params:bang() -- TODO VERIFY IF THIS IS OKAY TO LEAVE OUT
    grid_dirty = true
  end

  local function params_write_silent(filename,name)
    print("pset >>>>>>> write: "..filename)
    local fd = io.open(filename, "w+")
    if fd then
      io.output(fd)
      io.write("-- "..name.."\n")
      for _,param in ipairs(params.params) do
        if param.id and param.save and param.t ~= params.tTRIGGER and param.t ~= params.tSEPARATOR then
          io.write(string.format("%s: %s\n", quote(param.id), param:get()))
        end
      end
      io.close(fd)
    end
  end

  params.action_write = function(filename,name,number)
    -- local pset_string = string.sub(filename,string.len(filename) - 6, -1)
    -- local pset_number = pset_string:gsub(".pset","")
    print("saving hills data for PSET: "..number)
    kildare.move_audio_into_perm(_path.audio..'kildare/'..number..'/')
    util.make_dir(_path.data.."hills/"..number.."/data")
    util.make_dir(_path.data.."hills/"..number.."/patterns")
    util.make_dir(_path.data.."hills/"..number.."/song")
    util.make_dir(_path.data.."hills/"..number.."/snapshots")
    util.make_dir(_path.data.."hills/"..number.."/per-step")
    for i = 1,number_of_hills do
      tab.save(hills[i],_path.data.."hills/"..number.."/data/"..i..".txt")
    end
    for i = 1,16 do
      tab.save(grid_pattern[i],_path.data.."hills/"..number.."/patterns/"..i..".txt")
    end
    for i = 1,#song_atoms do
      tab.save(song_atoms[i],_path.data.."hills/"..number.."/song/"..i..".txt")
    end
    tab.save(snapshots,_path.data.."hills/"..number.."/snapshots/all.txt")
    tab.save(snapshot_overwrite, _path.data.."hills/"..number.."/snapshots/overwrite_state.txt")
    tab.save(_fkprm.adjusted_params, _path.data.."hills/"..number.."/per-step/_fkprm.txt")
    params_write_silent(filename,name)
  end

  params.action_delete = function(filename, name, pset_number)
    local delete_this_folder = _path.audio..'kildare/'..pset_number..'/'
    os.execute('rm -r '..delete_this_folder)
  end

  function kildare.voice_param_callback(voice, param, val)
    if snapshot_overwrite_mod then
      local d_voice = type(voice) ~= 'string' and params:string('voice_model_'..voice) or voice
      if util.string_starts(voice, 'sample') then
        voice = tonumber(string.sub(voice,-1)) + 7 -- TODO: CONFIRM CPU OKAY
      end
      for i = 1,8 do
        local should_overwrite = snapshot_overwrite[voice][d_voice][i]
        if should_overwrite and params:string('lfo_snapshot_'..voice) == 'off' then
          -- print('overwriting', snapshots[voice][d_voice][i][param])
          snapshots[voice][d_voice][i][param] = val
        end
      end
    end
    for i = 1,16 do
      if (grid_pattern[i].rec == 1 or grid_pattern[i].overdub == 1) and params:string('pattern_'..i..'_parameter_change_restore') == 'yes' then
        grid_pattern[i]:watch_mono(
          {
            ['event'] = 'parameter_value_change',
            ['voice'] = voice,
            ['param'] = param,
            ['value'] = val,
            ['model'] = params:string('voice_model_'..voice),
            ['id'] = i
          }
        )
      end
      if grid_pattern[i].clear_mono == 1 then
        grid_pattern[i]:clear_mono_events(
          {
            ['voice'] = voice,
            ['param'] = param,
            ['value'] = val,
            ['model'] = params:string('voice_model_'..voice),
            ['id'] = i
          }
        )
      end
    end
  end

  function kildare.model_change_callback(hill,model)
    hill_names[hill] = hill..': '..model
    
    prms.change_UI_name('hill_'..hill..'_group', hill_names[hill])
    prms.change_UI_name('hill_'..hill..'_note_header', 'note management '..hill_names[hill])
    prms.change_UI_name('hill_'..hill..'_kildare_header', 'Kildare management '..hill_names[hill])
    prms.change_UI_name('hill_'..hill..'_sample_header', 'sample management '..hill_names[hill])
    prms.change_UI_name('hill_'..hill..'_MIDI_header', 'MIDI management '..hill_names[hill])
    prms.change_UI_name('hill_'..hill..'_crow_header', 'crow management '..hill_names[hill])
    prms.change_UI_name('hill_'..hill..'_JF_header', 'JF management '..hill_names[hill])
    prms.change_UI_name('snapshot_crossfade_header_'..hill, 'crossfader '..hill_names[hill])

    grid_dirty = true
    for i = 1,8 do
      snapshot_overwrite[hill][model][i] = false
    end
    -- snapshot_overwrite_mod = false
  end

  print('wrapped with startup: '..util.time())
  clock.run(
    function()
      clock.sleep(0.5)
      development_state()
      print('dev state: '..util.time())
    end
  )

  print('done: '..util.time())

end

local function pass_data_into_storage(i,j,index,data)
  hills[i][j].note_num.pool[index] = data[1]
  hills[i][j].note_timestamp[index] = data[2]
  hills[i][j].high_bound.note = #hills[i][j].note_num.pool
  hills[i][j].note_num.active[index] = true
  hills[i][j].note_num.chord_degree[index] = util.wrap(hills[i][j].note_num.pool[index], 1, 7)
  hills[i][j].note_velocity[index] = 127

  hills[i][j].sample_controls.loop[index] = false
  hills[i][j].sample_controls.rate[index] = 9
end

construct = function(i,j,shuffle)
  local h = hills[i]
  local seg = h[j]
  local total_notes = util_round(#seg.note_ocean*seg.population)
  local index = 0
  local reasonable_max = seg.note_num.min ~= seg.note_num.max and seg.note_num.max or seg.note_num.min+1
  for k = 0,seg.duration*100 do
    local last_val = seg.current_val
    seg.current_val = math.floor(util.wrap(curves[seg.shape](k/100,1,total_notes-1,seg.duration),seg.note_num.min,reasonable_max))
    local note_num = seg.note_num.min ~= seg.note_num.max and seg.current_val or seg.note_num.min
    if util_round(last_val) ~= util_round(seg.current_val) then
      index = index + 1
      pass_data_into_storage(i,j,index,{note_num,k/100})
    end
  end
  calculate_timedeltas(i,j)
  if shuffle then
    _t['shuffle notes'](i,j,hills[i][j].low_bound.note,hills[i][j].high_bound.note)
  end
  -- TODO: redraws for every construct
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
            if util_round(seg.note_timestamp[seg.index],0.01) == util_round(seg.step,0.01) then
              pass_note(i,hills[i].segment,seg,seg.note_num.pool[seg.index],seg.index)
              seg.index = seg.index + 1
              seg.perf_led = true
            end
            seg.step = util_round(seg.step + 0.01,0.01)
            local reasonable_max = seg.note_timestamp[seg.high_bound.note+1] ~= nil and seg.note_timestamp[seg.high_bound.note+1] or seg.note_timestamp[seg.high_bound.note] + seg.note_timedelta[seg.high_bound.note]
            if util_round(seg.step,0.01) >= util_round(reasonable_max,0.01) then
              if seg.looper.mode == "phase" then
                _a.start(i,h.segment)
              else
                stop(i)
              end
            end
          grid_dirty = true
          end
        else
          if util_round(seg.note_timestamp[seg.index+1],0.01) == util_round(seg.step,0.01) then
            pass_note(i,hills[i].segment,seg,seg.note_num.pool[seg.index],seg.index)
            seg.step = seg.note_timestamp[seg.index]
            seg.perf_led = true
          else
            seg.step = util_round(seg.step + 0.01,0.01)
          end
          grid_dirty = true
        end
      else
        seg.iterated = false
        if seg.index <= seg.high_bound.note then
          if util_round(seg.note_timestamp[seg.index],0.01) == util_round(seg.step,0.01) then
            pass_note(i,hills[i].segment,seg,seg.note_num.pool[seg.index],seg.index)
            seg.index = seg.index + 1
            seg.perf_led = true
          end
          seg.step = util_round(seg.step + 0.01,0.01)
          local comparator;
          if seg.bound_mode == "time" then
            comparator = util_round(seg.step,0.01) > util_round(seg.high_bound.time,0.01)
          elseif seg.bound_mode == "note" then
            comparator = seg.index > seg.high_bound.note
          end
          if comparator then -- if `>` then this get us a final tick, which is technically duration + 0.01
            stop(i,true)
          end
          grid_dirty = true
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
  if params:string('hill '..i..' reset at stop') == 'yes' then
    seg.step = seg.note_timestamp[seg.low_bound.note] -- reset
  end
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
          midi_device[dev]:note_off(pre_note[i],seg.note_velocity,ch)
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
  screen_dirty = true
  grid_dirty = true
end

local function inject_data_into_storage(i,j,index,data)
  table.insert(hills[i][j].note_num.pool, index, data[1])
  table.insert(hills[i][j].note_timestamp, index, data[2])
  table.insert(hills[i][j].note_num.chord_degree, index, util.wrap(data[1], 1, 7))
  hills[i][j].high_bound.note = #hills[i][j].note_num.pool
end

local function adjust_timestamps_for_injection(i,j,index,duration)
  for k = index,#hills[i][j].note_timestamp do
    hills[i][j].note_timestamp[k] = hills[i][j].note_timestamp[k] + duration
  end
  hills[i][j].high_bound.time = hills[i][j].note_timestamp[#hills[i][j].note_timestamp]
  calculate_timedeltas(i,j)
end

local function inject(shape,i,injection_point,duration)
  local h = hills[i]
  local seg = h[h.segment]
  local total_notes = util_round(#seg.note_ocean*seg.population)
  local index = injection_point-1
  local current_val = 0
  local reasonable_max = seg.note_num.min ~= seg.note_num.max and seg.note_num.max or seg.note_num.min+1
  for j = seg.note_timestamp[injection_point+1]*100,(seg.note_timestamp[injection_point]+duration)*100 do
    local last_val = current_val
    current_val = math.floor(util.wrap(curves[shape](j/100,1,total_notes-1,duration),seg.note_num.min,reasonable_max))
    local note_num = seg.note_num.min ~= seg.note_num.max and current_val or seg.note_num.min
    if util_round(last_val) ~= util_round(current_val) then
      index = index + 1
      inject_data_into_storage(i,h.segment,index,{note_num,j/100})
    end
  end
  adjust_timestamps_for_injection(i,h.segment,index+1,duration)
end

local function get_random_offset(i,note)
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

local function check_subtables(i,j,index)
  local target_trig;
  if hills[i].highway == true then
    if track[i][j].trigs[index] then
      target_trig = _fkprm.adjusted_params
    else
      target_trig = _fkprm.adjusted_params_lock_trigs
    end
  else
    target_trig = _fkprm.adjusted_params
  end
  if target_trig[i] ~= nil
  and target_trig[i][j] ~= nil
  and target_trig[i][j][index] ~= nil
  and target_trig[i][j][index].params ~= nil
  then
    -- print('yep')
    return true
  else
    -- print('nope')
    return false
  end
end

per_step_params_adjusted = {}
trigless_params_adjusted = {}
for i = 1,10 do
  per_step_params_adjusted[i] = {param = {}, value = {}}
  trigless_params_adjusted[i] = {param = {}, value = {}}
end

local non_indexed_voices = {'delay', 'feedback', 'main'}

function fkmap(i,j,index,p)
  local target_trig;
  if hills[i].highway == true then
    if track[i][j].trigs[index] then
      target_trig = _fkprm.adjusted_params
    else
      target_trig = _fkprm.adjusted_params_lock_trigs
    end
  else
    target_trig = _fkprm.adjusted_params
  end
  local value = target_trig[i][j][index].params[p]
  local clamped = util.clamp(value, 0, 1)
  local cs = params:lookup_param(p).controlspec
  local rounded = util_round(cs.warp.map(cs, clamped), cs.step)
  return rounded
end

local function extract_voice_from_string(s)
  for i = 1,#non_indexed_voices do
    if util.string_starts(s,non_indexed_voices[i]) then
      return non_indexed_voices[i]
    end
  end
end

local function process_params_per_step(parent,i,j,k,index)
  local is_drum_voice = parent[k] <= params.lookup['sample3_feedbackSend']
  local id = parent[k]
  local drum_target;
  if id < params.lookup['sample1_sampleMode'] then
    drum_target = params:get_id(id):match('(.+)_(.+)_(.+)')
    drum_target = tonumber(drum_target)
  else
    drum_target = params:get_id(id):match('(.+)_(.+)')
  end

  if is_drum_voice and type(drum_target) == 'number' and drum_target <= 7 and drum_target == i then
    local p_name = string.gsub(params:get_id(id),drum_target..'_'..params:string('voice_model_'..drum_target)..'_','')
    print('reseeding default value for voice', drum_target, j, index, id)
    prms.send_to_engine(drum_target,p_name,params:get(id))
  elseif is_drum_voice and type(drum_target) == 'string' then
    local target_voice = drum_target
    local p_name = string.gsub(params:get_id(id),target_voice..'_','')
    prms.send_to_engine(target_voice,p_name,params:get(id))
    -- print('reseeding default value for sample voice', i, j, index, id)
  elseif drum_target == i then
    local p_name = extract_voice_from_string(params:get_id(id))
    local sc_target = string.gsub(params:get_id(id),p_name..'_','')
    -- print('reseeding default value to fx', i, j, index, id)
    engine['set_'..p_name..'_param'](sc_target,params:get(id))
  end
end

pass_note = function(i,j,seg,note_val,index,retrig_index)
  local midi_notes = hills[i][j].note_ocean
  local played_note = get_random_offset(i,midi_notes[note_val])
  local _active = track[i][j]
  local focused_set = _active.focus == 'main' and _active or _active.fill
  if (played_note ~= nil and hills[i].highway == false and hills[i][j].note_num.active[index]) or
    (played_note ~= nil and hills[i].highway == true and not focused_set.muted_trigs[index]) then
    -- per-step params //
    if i <= 10 then
      -- print(i,j,index,check_subtables(i,j,index),retrig_index)
      if check_subtables(i,j,index) then
        -- tab.print(per_step_params_adjusted[i].param)
        -- step to step params resets:
        local target_trig;
        if hills[i].highway == true then
          if focused_set.trigs[index] then
            target_trig = _fkprm.adjusted_params
          else
            target_trig = _fkprm.adjusted_params_lock_trigs
          end
        else
          target_trig = _fkprm.adjusted_params
        end
        if target_trig == _fkprm.adjusted_params then
          for k = 1,#per_step_params_adjusted[i].param do
            local check_prm = per_step_params_adjusted[i].param[k]
            -- print(check_prm)
            if _fkprm.adjusted_params[i][j][index].params[check_prm] == nil then
              local lock_trig = track[i][j].focus == 'main' and track[i][j].lock_trigs[index] or track[i][j].fill.lock_trigs[index]
              local is_drum_voice = check_prm <= params.lookup['sample3_feedbackSend']
              local id = check_prm
              if is_drum_voice and i <= 7 then
                local target_voice = string.match(params:get_id(id),"%d+")
                local target_drum = params:get_id(id):match('(.*_)')
                target_drum = string.gsub(target_drum, target_voice..'_', '')
                target_drum = string.gsub(target_drum, '_', '')
                local p_name = string.gsub(params:get_id(id),target_voice..'_'..target_drum..'_','')
                prms.send_to_engine(target_voice,p_name,params:get(id))
                print('reseeding non-adjusted value for voice', target_voice, j, index, id, p_name)
              elseif is_drum_voice and i >= 8 then
                local target_voice = 'sample'..(i-7)
                local p_name = string.gsub(params:get_id(id),target_voice..'_','')
                prms.send_to_engine(target_voice,p_name,params:get(id))
                print('reseeding non-adjusted value for sample voice', target_voice, j, index, id, p_name, check_prm)
              else
                local p_name = extract_voice_from_string(params:get_id(id))
                local sc_target = string.gsub(params:get_id(id),p_name..'_','')
                -- print('reseeding non-adjusted value for fx', i, j, index, id)
                engine['set_'..p_name..'_param'](sc_target,params:get(id))
              end
            end
          end
          per_step_params_adjusted[i] = {param = {}, value = {}}
        end
        -- this step's entry handling:
        -- per_step_params_adjusted[i] = {param = {}, value = {}}
        -- for k,v in next,_fkprm.adjusted_params[i][j][index].params do
        for k,v in next,target_trig[i][j][index].params do

          local is_drum_voice = k <= params.lookup['sample3_feedbackSend']
          local id = k
          local drum_target;
          if id < params.lookup['sample1_sampleMode'] then
            drum_target = params:get_id(id):match('(.+)_(.+)_(.+)')
            drum_target = tonumber(drum_target)
          else
            drum_target = params:get_id(id):match('(.+)_(.+)')
          end

          if is_drum_voice and type(drum_target) == 'number' and drum_target <= 7 then
            if retrig_index == 0 then
              local target_voice = drum_target
              local target_drum = params:get_id(k):match('(.*_)')
              target_drum = string.gsub(target_drum, target_voice..'_', '')
              target_drum = string.gsub(target_drum, '_', '')
              local p_name = string.gsub(params:get_id(k),target_voice..'_'..target_drum..'_','')
              print('sending voice param',target_voice,p_name,fkmap(i,j,index,k))
              if target_voice ~= i then
                if not tab.contains(track[target_voice].external_prm_change,k) then
                  track[target_voice].external_prm_change[#track[target_voice].external_prm_change+1] = k
                end
              end
              prms.send_to_engine(target_voice,p_name,fkmap(i,j,index,k))
            end
          elseif is_drum_voice and type(drum_target) == 'string' then
            if retrig_index == 0 then
              local target_voice = drum_target
              local p_name = string.gsub(params:get_id(k),target_voice..'_','')
              -- TODO: how does this work??
              -- FIXME: breaks if sending value for delay...
              if target_voice ~= 'sample'..(i-7) then
                if not tab.contains(track[target_voice].external_prm_change,k) then
                  track[target_voice].external_prm_change[#track[target_voice].external_prm_change+1] = k
                end
              end
              prms.send_to_engine(target_voice,p_name,fkmap(i,j,index,k))
              -- print('sending sample param')
            end
          else
            local p_name = extract_voice_from_string(params:get_id(k))
            local sc_target = string.gsub(params:get_id(k),p_name..'_','')
            -- print('sending step param to fx', i, j, index, k)
            engine['set_'..p_name..'_param'](sc_target,fkmap(i,j,index,k))
          end
          
          per_step_params_adjusted[i].param[#per_step_params_adjusted[i].param+1] = k
          per_step_params_adjusted[i].value[#per_step_params_adjusted[i].value+1] = v
        
        end

        -- print(i,j,index)
      else
        -- restore default param value:
        for k = 1,#per_step_params_adjusted[i].param do
          process_params_per_step(per_step_params_adjusted[i].param,i,j,k,index)
        end
        per_step_params_adjusted[i] = {param = {}, value = {}}
        for k = 1,#track[i].external_prm_change do
          process_params_per_step(track[i].external_prm_change,i,j,k,index)
        end
        track[i].external_prm_change = {}
      end
    end
    -- // per-step params
    -- print('done with fkprm stuff')
    if i <= 7 then
      if params:string("hill "..i.." kildare_notes") == "yes" then
        engine.set_voice_param(i,"carHz",midi_to_hz(played_note))
        if params:string("hill "..i.." kildare_chords") == 'yes' then
          local chord_target = hills[i].highway == false and hills[i][j].note_num.chord_degree[index] or track[i][j].chord_degrees[index]
          local shell_notes = mu.generate_chord_scale_degree(
            -- played_note,
            params:get('hill '..i..' base note'),
            params:string('hill '..i..' scale'),
            -- hills[i][j].note_num.chord_degree[index],  -- TODO: this won't always be hill-active...track-active!!
            chord_target,
            true
          )
          engine.set_voice_param(i,"thirdHz",midi_to_hz(shell_notes[2]))
          engine.set_voice_param(i,"seventhHz",midi_to_hz(shell_notes[4]))
        else
          engine.set_voice_param(i,"thirdHz",midi_to_hz(played_note))
          engine.set_voice_param(i,"seventhHz",midi_to_hz(played_note))
        end
      end
      local vel_target = hills[i].highway == false and hills[i][j].note_velocity[index] or track[i][j].velocities[index]
      if hills[i].highway then
        local lock_trig = track[i][j].focus == 'main' and track[i][j].lock_trigs[index] or track[i][j].fill.lock_trigs[index]
        if focused_set.trigs[index] and not focused_set.muted_trigs[index] then
          if retrig_index == nil then
            engine.trig(i,vel_target,'false')
          else
            local destination_vel = track[i][j].focus == 'main' and track[i][j].velocities[index] or track[i][j].fill.velocities[index]
            local destination_count = track[i][j].focus == 'main' and track[i][j].conditional.retrig_count[index] or track[i][j].fill.conditional.retrig_count[index]
            local destination_curve = track[i][j].focus == 'main' and track[i][j].conditional.retrig_slope[index] or track[i][j].fill.conditional.retrig_slope[index]
            local retrig_vel;
            if destination_curve < 0 and destination_count > 0 then
              local destination_min = lin_lin(-128, -1, 0, destination_vel, destination_curve)
              retrig_vel = util_round(lin_lin(0, destination_count, destination_vel, destination_min, retrig_index))
            elseif destination_curve > 0 and destination_count > 0 then
              local destination_max = lin_lin(1, 128, 0, destination_vel, destination_curve)
              retrig_vel = util_round(lin_lin(0, destination_count, 0, destination_max, retrig_index))
            else
              retrig_vel = destination_vel
            end
            engine.trig(i,retrig_vel,'true')
          end
        end
      else
        engine.trig(i,vel_target,'false')
      end
      if params:string("hill "..i.." sample output") == "yes" then
        if params:get("hill "..i.." sample probability") >= math.random(100) then
          local target = "sample"..params:get("hill "..i.." sample slot")
          if params:string(target..'_sampleMode') == 'chop' then
            local slice_count = params:get('hill '..i..' sample slice count') - 1
            local slice = util.wrap(played_note - params:get("hill "..i.." base note"),0,slice_count) + 1
            _ca.play_slice(target,slice,vel_target,i,j,played_note, retrig_index)  -- TODO: this won't always be hill-active...track-active!!
          elseif params:string(target..'_sampleMode') == 'playthrough' then
            _ca.play_through(target,vel_target,i,j,played_note, retrig_index)  -- TODO: this won't always be hill-active...track-active!!
          elseif params:string(target..'_sampleMode') == 'distribute' then
            local scaled_idx = util_round(sample_info[target].sample_count * (params:get('hill '..i..' sample distribution')/100))
            if scaled_idx ~= 0 then
              local idx = util.wrap(played_note - params:get("hill "..i.." base note"),0,scaled_idx-1) + 1
               -- TODO: this won't always be hill-active...track-active!!:
              _ca.play_index(target,idx,vel_target,i,j,played_note, retrig_index) -- TODO: adjust for actual sample pool size
            end
          end
        end
      end
    else
      -- TRIGGER SAMPLE
      local vel_target = hills[i].highway == false and hills[i][j].note_velocity[index] or track[i][j].velocities[index]
      if params:string("hill "..i.." sample output") == "yes" then
        if params:get("hill "..i.." sample probability") >= math.random(100) then
          local should_play;
          if hills[i].highway then
            -- local lock_trig = track[i][j].focus == 'main' and track[i][j].lock_trigs[index] or track[i][j].fill.lock_trigs[index]
            if track[i][j].trigs[index] then
              should_play = true
            end
          else
            should_play = true
          end
          local target = "sample"..i-7
          if params:string(target..'_sampleMode') == 'chop' and should_play then
            local slice_count = params:get('hill '..i..' sample slice count') - 1
            local slice = util.wrap(played_note - params:get("hill "..i.." base note"),0,slice_count) + 1
            _ca.play_slice(target,slice,vel_target,i,j,played_note, retrig_index)
          elseif params:string(target..'_sampleMode') == 'playthrough' and should_play then
            _ca.play_through(target,vel_target,i,j,played_note, retrig_index)
          elseif params:string(target..'_sampleMode') == 'distribute' and should_play then
            local scaled_idx = util_round(sample_info[target].sample_count * (params:get('hill '..i..' sample distribution')/100))
            if scaled_idx ~= 0 then
              local idx = util.wrap(played_note - params:get("hill "..i.." base note"),0,scaled_idx-1) + 1
              _ca.play_index(target,idx,vel_target,i,j,played_note, retrig_index) -- TODO: adjust for actual sample pool size
            end
          end
        end
      end
    end
    manual_iter(i,j)
    if params:string("hill "..i.." MIDI output") == "yes" then
      local ch = params:get("hill "..i.." MIDI note channel")
      local dev = params:get("hill "..i.." MIDI device")
      if pre_note[i] ~= nil then
        midi_device[dev]:note_off(pre_note[i],seg.note_velocity,ch)
      end
      midi_device[dev]:note_on(played_note,seg.note_velocity,ch)
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
        -- print(ch,(played_note - 60)/12,5)
      elseif params:string("hill "..i.." JF output style") == "shape" then
        crow.ii.jf.trigger(ch,1)
      end
    end
    pre_note[i] = played_note
  end
  screen_dirty = true
  grid_dirty = true
end

function manual_iter(i,j)
  for idx = 1,#hills[i].iter_links[j] do
    if hills[i].iter_links[j][idx] ~= 0 then
      if hills[i].iter_counter[j][idx] == 1 then
        local c_hill = hills[i].iter_links[j][idx]
        if hills[idx][c_hill].note_num.pool[hills[idx][c_hill].index] ~= nil then
          pass_note(idx,j,hills[idx][c_hill],hills[idx][c_hill].note_num.pool[hills[idx][c_hill].index],hills[idx][c_hill].index)
        end
        hills[idx][c_hill].index = util.wrap(hills[idx][c_hill].index + 1, hills[idx][c_hill].low_bound.note,hills[idx][c_hill].high_bound.note)
      end
      hills[i].iter_counter[j][idx] = util.wrap(hills[i].iter_counter[j][idx]+1, 1, hills[i].iter_pulses[j][idx])
    end
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
  if key2_hold and (ui.control_set == 'play' or ui.control_set == 'song') then
    _flow.process_key(n,z)
  else
    if ui.control_set ~= "song" then
      _k.parse(n,z)
    else
      _flow.process_key(n,z)
    end
  end
  screen_dirty = true
end

redraw = function()
  screen.clear()
  if key2_hold and (ui.control_set == 'play' or ui.control_set == 'song') then
    _flow.draw_transport_menu()
  else
    if ui.control_set ~= "song" and hills[ui.hill_focus].highway == false then
      _s.draw()
    elseif ui.control_set ~= "song" and hills[ui.hill_focus].highway then
      _hsteps.draw_menu()
    else
      if not key2_hold then
        _flow.draw_song_menu()
      else
        _flow.draw_transport_menu()
      end
    end
  end
  screen.update()
  screen_dirty = false
  if key2_hold then
    screen_dirty = true
  end
end

function index_to_grid_pos(val,columns)
  local x = math.fmod(val-1,columns)+1
  local y = math.modf((val-1)/columns)+1
  return {x,y}
end

function cleanup ()
  print("cleanup")
  metro.free_all()
end