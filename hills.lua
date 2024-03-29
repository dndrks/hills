-- hills

--
-- __/\______/\\___
-- ____/\\\\\___/\_
-- /\///_____/\\\__

-- replace this string with your computer's IP to
-- send OSC to an external instance of Kildare:
-- osc_echo = "224.0.0.1"
-- osc_echo = "169.254.64.84"
-- osc_echo = "224.0.0.1"
-- osc_echo = "169.254.202.238"
-- osc_echo = "192.168.0.137"
-- osc_echo = "169.254.111.133"
osc_echo = "192.168.2.1"

function full_PSET_swap()
  clock.run(
    function()
      clock.sleep(0.1)
      if PSET_SWAPPING == nil then
        PSET_SWAPPING = true
        for i = 1,7 do
          params:set(i..'_voice_state',0)
        end
        clock.sleep(0.1)
        _polyparams.reset_polyparams()
        _ccparams.reset_polyparams()
        clock.sleep(0.1)
        send_to_engine('reset',{})
        clock.sleep(0.3)
        params:read()
        clock.sleep(1)
        params:read()
      end
    end
  )
end

if tonumber(norns.version.update) < 220802 then
  norns.script.clear()
  norns.script.load('code/hills/lib/fail_state.lua')
end

kildare = include('kildare/lib/kildare')

function kildare.restart_needed_callback()
  norns.script.clear()
  norns.script.load('code/hills/lib/restart_notify.lua')
end

engine.name = "Kildare"
if osc_echo ~= nil then
  -- osc.send({osc_echo,57120},"/command",{'establish_engine'})
  osc.send({osc_echo,57120},"/engine/load/name",{'Kildare'})
end

number_of_hills = 7
number_of_patterns = 8
hill_names = {
  "1: bd",
  "2: sd",
  "3: tm",
  "4: cp",
  "5: rs",
  "6: cb",
  "7: hh",
  "8: saw"
}

pre_step_page = 'play'

aubiodone=function(args)
  local id=tonumber(args[1])
  local data_s=args[2]
  print('aubiodone',id,data_s)
end

osc_fun={
  progressbar=function(args)
    print(args[1],tonumber(args[2]))
  end,
  aubiodone=function(args)
    local id=tonumber(args[1])
    stuff=args[2]
    local data=kildare.json.parse(stuff)
    if data==nil then
      print("error getting onset data!")
      do return end
    end
    if data.error~=nil then
      print("error getting onset data: "..data.error)
      do return end
    end
    if data.result==nil then
      print("no onset results!")
      do return end
    end
    cursors=data.result
    -- self:do_move(0)
    -- show_message(string.format("[%d] loaded",self.id),2)
  
    -- -- save the top_slices
    -- print("writing cursor file",self.path_to_cursors)
    -- local file=io.open(self.path_to_cursors,"w+")
    -- io.output(file)
    -- io.write(json.encode({cursors=self.cursors}))
    -- io.close(file)
  end,
}

local make_sound = false

function externalIterator(noteNum)
  local j = noteNum - 35

  if hills[j].highway then
    _htracks.tick(j)
  else
    local k = hills[j].segment
    if hills[j][k].note_num.pool[hills[j][k].index] ~= nil then
      pass_note(j,k,hills[j][k],hills[j][k].note_num.pool[hills[j][k].index],hills[j][k].index,0)
    end
    hills[j][k].index = util.wrap(hills[j][k].index + 1, hills[j][k].low_bound.note,hills[j][k].high_bound.note)
  end
  if params:string('hill_'..j..'_iterator_midi_record') == 'yes' then
    for k = 1,16 do
      local table_to_record =
        {
          ["event"] = "midi_trig",
          ["id"] = k,
          ["hill"] = j,
          ["segment"] = hills[j].segment,
          ["legato"] = params:get('hill_'..j..'_legato') == 1
        }
      write_pattern_data(k,table_to_record,false)
    end
  end
end

osc.event=function(path,args,from)
  -- if string.sub(path,1,1)=="/" then
  --   path=string.sub(path,2)
  -- end
  -- print('osc path: '..path)
  -- if osc_fun[path] ~= 'progressbar' or 'aubiodone' then
  --   osc_fun[path](args)
  -- end
  -- params:delta(path, args[1])
  -- print(args[1])
  -- local d = args[1] == 1 and 1 or -1


  -- if path == '/Velocity1' and args[1] > 0 then
  --   make_sound = true
  -- end
  -- if path == '/Note1' and make_sound then
  --   print(args[1])
  --   externalIterator(args[1])
  --   make_sound = false
  -- end

  
  -- params:delta(path, args[1])
end

_sequins = require 'sequins'
mu = require 'musicutil'
euclid = require 'er'
pt = include 'lib/hills_new_pt'
curves = include 'lib/easing'
_midi = include 'lib/midi'
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
_cp = include 'lib/copy-paste'
_surveyor = include 'lib/surveyor'
_snapshots = include 'lib/snapshot'
_fkprm = include 'lib/fkprm'
_polyparams = include 'lib/polyparams'
_ccparams = include 'lib/ccparams'
_hsteps = include 'lib/highway_steps'
_htracks = include 'lib/highway_tracks'

r = function()
  norns.script.load("code/hills/hills.lua")
end

development_state = function()
  -- song_atoms.transport_active = true
  for i = 1,number_of_hills do
    -- DIAMOND HOLLOW/
    -- params:set('hill_'..i..'_mode', 2)
    -- params:set('hill_'..i..'_iterator',2)
    -- params:set('hill_'..i..'_iterator_midi_device',6)
    -- params:set('hill_'..i..'_iterator_midi_note',35+util.wrap(i,1,4))
    -- -- /DIAMOND HOLLOW
    -- params:set('hill_'..i..'_iterator_midi_record',2)

    -- BERLIN
    params:set('hill_'..i..'_flatten',0)
    params:set('voice_model_'..i, 14)
    params:set('hill '..i..' MIDI output', 2)
    --/BERLIN
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
midi_device = {}

local util_round = util.round
local lin_lin = util.linlin

function init()
  print('starting: '..util.time())
  for i = 1,6 do
    softcut.enable(i,0)
  end
  kildare.init(number_of_hills, true)
  _ca.init() -- initialize clips
  _snapshots.init()
  _flow.init()
  print('initializing song: '..util.time())
  _song.init()
  math.randomseed(os.time())
  _g.init()
  
  key1_hold = false
  key2_hold = false

  -- pulled this down:
  -- _hsteps.init()
  -- for i = 1,10 do
  --   _htracks.init(i,1)
  -- end

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
    midi_device[i].event = function(data)
      local d = midi.to_msg(data)
      if d.type == 'note_on' then
        for j = 1,number_of_hills do
          -- if d.note == params:get('hill_'..j..'_iterator_midi_note')
          -- and d.vel >= params:get('hill_'..j..'_iterator_midi_velocity_lo')
          -- and d.vel <= params:get('hill_'..j..'_iterator_midi_velocity_hi')
          if d.note == _midi.iterator.note[j]
          and d.vel >= _midi.iterator.velocity_lo[j]
          and d.vel <= _midi.iterator.velocity_hi[j]
          and params:string('hill_'..j..'_iterator') == 'external MIDI'
          and params:get('hill_'..j..'_iterator_midi_device') == i
          then
            if hills[j].highway then
              _htracks.tick(j)
            else
              local k = hills[j].segment
              if hills[j][k].note_num.pool[hills[j][k].index] ~= nil then
                pass_note(j,k,hills[j][k],hills[j][k].note_num.pool[hills[j][k].index],hills[j][k].index,0)
              end
              hills[j][k].index = util.wrap(hills[j][k].index + 1, hills[j][k].low_bound.note,hills[j][k].high_bound.note)
            end
            if params:string('hill_'..j..'_iterator_midi_record') == 'yes' then
              for k = 1,16 do
                local table_to_record =
                  {
                    ["event"] = "midi_trig",
                    ["id"] = k,
                    ["hill"] = j,
                    ["segment"] = hills[j].segment,
                    ["legato"] = params:get('hill_'..j..'_legato') == 1
                  }
                write_pattern_data(k,table_to_record,false)
              end
            end
          end
        end
      end
    end
  end

  scale_names = {}
  local scale_count = 1
  for i = 1,#mu.SCALES do
    scale_names[scale_count] = mu.SCALES[i].name
    scale_count = scale_count + 1
  end
  
  prms.init()
  _fkprm.init()
  _polyparams.init()
  _ccparams.init()
  _midi.init()
  -- prms.reload_engine(params:string("global engine"),true)
  
  for i = 1,number_of_hills do
    ui.edit_note[i] = {}

    hills[i] = {}
    hills[i].mode = "iterate"
    hills[i].highway = false
    hills[i].active = false
    hills[i].crow_change_queued = false

    hills[i].segment = 1
    hills[i].looper = {["clock"] = nil}

    hills[i].snapshot = {["partial_restore"] = false}
    hills[i].snapshot.restore_times = {["beats"] = {1,2,4,8,16,32,64,128}, ["time"] = {1,2,4,8,16,32,64,128}, ["mode"] = "beats"}
    hills[i].snapshot.mod_index = 0
    hills[i].snapshot.focus = 0

    hills[i].iter_links = {}
    hills[i].iter_pulses = {}
    hills[i].iter_counter = {}
    for j = 1,number_of_hills do
      hills[i].iter_links[j] = false
      hills[i].iter_pulses[j] = 1
      hills[i].iter_counter[j] = 1
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

    hills[i].note_ocean = mu.generate_scale_of_length(params:get("hill "..i.." base note"),params:get("hill "..i.." scale"),127) -- the full range of notes

    for j = 1,8 do
      hills[i][j] = {}
      hills[i][j].duration = util_round(clock.get_beat_sec() * 16,0.01)
      hills[i][j].eject = hills[i][j].duration
      hills[i][j].base_step = 0
      hills[i][j].population = math.random(10,100)/100
      hills[i][j].current_val = 0
      hills[i][j].step = 0
      hills[i][j].index = 1
      hills[i][j].timing = {}
      hills[i][j].shape =  params:string("hill ["..i.."]["..j.."] shape")
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

      -- construct(i,j,true)

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

    startup_animation = clock.run(
      function()
        while true do
          clock.sleep(1/15)
          redraw()
        end
      end
    )

    menu_rebuild_clock = clock.run(function()
      while true do
        clock.sleep(1/15)
        if screen_dirty then
          redraw()
        end
        if menu_rebuild_queued then
          _menu.rebuild_params()
          menu_rebuild_queued = false
        end
      end
    end)
  end

  print('built hills: '..util.time())

  params.action_preread = function(filename,name,number)
    -- readingPSET = true
    -- for i = 1,7 do params:set(i..'_voice_state',0) end
    -- _polyparams.reset_polyparams()
    -- send_to_engine('reset',{})
  end

  params.action_read = function(filename,name,number)
    readingPSET = true
    print("loading hills data for PSET: "..number)
    for i = 1,number_of_hills do
      if params:get(i..'_voice_state') == 0 then
        _menu.m.PARAMS.on[params.lookup[i..'_voice_state']] = 0
      else
        _menu.m.PARAMS.on[params.lookup[i..'_voice_state']] = 1
      end
    end
    -- for i = 1,7 do params:set(i..'_voice_state',0) end
    local this_filepath = _path.data..'hills/'..number..'/'
    for i = 1,number_of_hills do
      if hills[i].active then
        stop(i,true)
      end
      hills[i] = tab.load(this_filepath.."data/"..i..".txt")
      -- // TODO: this is temporary for luck dragon performance loading...
      -- shouldn't be needed for release.
      if hills[i].iter_pulses == nil then
        hills[i].iter_pulses = {}
        hills[i].iter_counter = {}
        for j = 1,number_of_hills do
          hills[i].iter_pulses = 1
          hills[i].iter_counter = 1
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
      local to_inherit = tab.load(this_filepath.."patterns/"..j..".txt")
      local inheritances = {'end_point', 'count', 'event', 'loop'}
      for adj = 1, #inheritances do
        grid_pattern[j][inheritances[adj]] = to_inherit[inheritances[adj]]
      end
    end
    for j = 1,#song_atoms do
      song_atoms[j] = tab.load(this_filepath.."song/"..j..".txt")
    end
    snapshots = tab.load(this_filepath.."snapshots/all.txt")
    snapshot_overwrite = tab.load(this_filepath.."snapshots/overwrite_state.txt")
    _fkprm.adjusted_params = tab.load(this_filepath.."per-step/_fkprm.txt")
    -- _fkprm.adjusted_params_lock_trigs = tab.load(this_filepath.."per-step/_fkprm-lock_trigs.txt")
    if util.file_exists(this_filepath.."per-voice/_polyparams.txt") then
      _polyparams.adjusted_params = tab.load(this_filepath.."per-voice/_polyparams.txt")
    end
    for j = 1,number_of_hills do
      track[j] = tab.load(this_filepath.."track/"..j..".txt")
      for subs = 1,#track[j] do
        local collect_sequins = {}
        for data_steps = 1,track[j][subs].page_chain.length do
          collect_sequins[data_steps] = track[j][subs].page_chain.data[data_steps]
        end
        track[j][subs].page_chain = _sequins{table.unpack(collect_sequins)}
      end
    end
    -- params:bang() -- TODO VERIFY IF THIS IS OKAY TO LEAVE OUT
    grid_dirty = true
    print('loading pset!'..this_filepath)
    if util.file_exists(this_filepath.."poly-params.txt") then
      print('loading poly params!')
      -- kildare.queued_read_file = this_filepath.."poly-params.txt"
      engine.load_poly_params(this_filepath.."poly-params.txt")
    end
    full_PSET_swap()
    clock.run(
      function()
        clock.sleep(0.3)
        readingPSET = false
        if PSET_LOOP == nil then PSET_LOOP = 0 end
        PSET_LOOP = PSET_LOOP + 1
        print('PSET NOT READING')
        if PSET_LOOP == 3 then
          PSET_LOOP = 0
          PSET_SWAPPING = nil
        end
      end
    )
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
    util.make_dir(_path.data.."hills/"..number.."/track")
    util.make_dir(_path.data.."hills/"..number.."/per-step")
    util.make_dir(_path.data.."hills/"..number.."/per-voice")
    for i = 1,number_of_hills do
      tab.save(hills[i],_path.data.."hills/"..number.."/data/"..i..".txt")
      tab.save(track[i],_path.data.."hills/"..number.."/track/"..i..".txt")
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
    -- tab.save(_fkprm.adjusted_params_lock_trigs, _path.data.."hills/"..number.."/per-step/_fkprm-lock_trigs.txt")
    tab.save(_polyparams.adjusted_params, _path.data.."hills/"..number.."/per-voice/_polyparams.txt")
    params_write_silent(filename,name)
    os.execute('touch '.._path.data..'hills/'..number..'/poly-params.txt')
    engine.save_poly_params(_path.data..'hills/'..number..'/poly-params.txt')
  end

  params.action_delete = function(filename, name, pset_number)
    local delete_this_folder = _path.audio..'kildare/'..pset_number..'/'
    if util.file_exists(delete_this_folder) then
      os.execute('rm -r '..delete_this_folder)
    end
    delete_this_folder = _path.data..'hills/'..pset_number..'/'
    if util.file_exists(delete_this_folder) then
      os.execute('rm -r '..delete_this_folder)
    end
  end

  function kildare.voice_param_callback(voice, param, val)
    if snapshot_overwrite_mod then
      local d_voice = type(voice) ~= 'string' and selectedVoiceModels[voice] or voice
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
            ['model'] = selectedVoiceModels[voice],
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
            ['model'] = selectedVoiceModels[voice],
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

    if model == 'sample' then
      params:set('hill '..hill..' sample output',2)
    end
    -- snapshot_overwrite_mod = false
  end

  _hsteps.init()
  for i = 1,number_of_hills do
    _htracks.init(i,1)
  end

  print('wrapped with startup: '..util.time())
  clock.run(
    function()
      clock.sleep(2)
      development_state()
      if kildare.queued_read_file ~= nil then
        print('!!!!!!!!!!!!!!!!!!!!!!!!queud read')
        engine.load_poly_params(kildare.queued_read_file)
        kildare.queued_read_file = nil
      end
      -- print('dev state: '..util.time())
      -- print('starting from toggle')
      clock.run(function() clock.sleep(1) loading_done = true clock.cancel(startup_animation) end)
    end
  )

  for i = 1,number_of_hills do
    for j = 1, number_of_patterns do
      hodgepodge(i,j)
    end
  end

  print('done: '..util.time())

  last_voice_param = params.lookup[number_of_hills..'_sample_feedbackSend']
end

function pass_data_into_storage(i,j,index,data)
  if data[1] ~= data[1] then
    print('woulda been nan', i,j, index)
    hills[i][j].note_num.pool[index] = math.random(hills[i][j].note_num.min, hills[i][j].note_num.max)
  else
    hills[i][j].note_num.pool[index] = data[1]
  end
  hills[i][j].note_timestamp[index] = data[2]
  hills[i][j].high_bound.note = #hills[i][j].note_num.pool
  hills[i][j].note_num.active[index] = true
  hills[i][j].note_num.chord_degree[index] = util.wrap(hills[i][j].note_num.pool[index], 1, 7)
  hills[i][j].note_velocity[index] = 127

  hills[i][j].sample_controls.loop[index] = false
  hills[i][j].sample_controls.rate[index] = 9
end

-- construct = function(i,j,shuffle)
--   local h = hills[i]
--   local seg = h[j]
--   local total_notes = util_round(#h.note_ocean*seg.population)
--   local index = 0
--   local reasonable_max = seg.note_num.min ~= seg.note_num.max and seg.note_num.max or seg.note_num.min+1
--   for k = 0,seg.duration*100 do
--     local last_val = seg.current_val
--     seg.current_val = math.floor(util.wrap(curves[seg.shape](k/100,1,total_notes-1,seg.duration),seg.note_num.min,reasonable_max))
--     local note_num = seg.note_num.min ~= seg.note_num.max and seg.current_val or seg.note_num.min
--     if util_round(last_val) ~= util_round(seg.current_val) then
--       if i == 1 and j == 1 then print(k/100) end
--       index = index + 1
--       pass_data_into_storage(i,j,index,{note_num,k/100})
--     end
--   end
--   calculate_timedeltas(i,j)
--   if shuffle then
--     _t['shuffle notes'](i,j,hills[i][j].low_bound.note,hills[i][j].high_bound.note)
--   end
--   -- TODO: redraws for every construct
--   screen_dirty = true
-- end

stepOffset = 0

hodgepodge = function(i,j)
  local h = hills[i]
  local seg = h[j]
  local populous = params:get("hill ["..i.."]["..j.."] population")/100
  local total_notes = util.clamp(util_round(48*populous),10,inf)
  -- print(i,j,params:get("hill ["..i.."]["..j.."] population")/100)
  local index = 0
  local reasonable_max = seg.note_num.min ~= seg.note_num.max and seg.note_num.max or seg.note_num.min+1

  -- just generate times

  local splitter = {}
  local splits = 5
  local tests = {}
  for stuff = 1,splits do
    splitter[stuff] = math.floor(total_notes / splits)
  end
  for stuff = 1,total_notes % splits do
    splitter[stuff] = splitter[stuff] + 1
  end
  -- splitter[1] = math.floor(total_notes/3)
  -- local nt = (total_notes - splitter[1])
  -- splitter[2] = math.floor(nt/2)
  -- splitter[3] = math.floor((nt - splitter[2]))

  easedTimes = {}
  easedNotes = {}
  -- for steps = 1,total_notes do
  for splitsteps = 1,#splitter do
    seg.shape = easingNames[math.random(#easingNames)] -- change shape
    easedTimes[splitsteps] = {}
    easedNotes[splitsteps] = {}
    for steps = 1,splitter[splitsteps] do
      easedTimes[splitsteps][steps] = util.linlin(
        curves[seg.shape](
          util.clamp(stepOffset, 0, total_notes-1),
          0,
          seg.duration,
          total_notes
        ),
        seg.duration,
        0,
        seg.duration/2,
        curves[seg.shape](
          util.clamp((steps-1) + stepOffset, 0, total_notes-1),
          0,
          seg.duration,
          total_notes
        )
      )
      easedNotes[splitsteps][steps] = math.floor(
        util.wrap(
          curves[seg.shape](
            util.clamp((steps-1) + stepOffset, 0, total_notes-1),
            1,
            total_notes-1,
            seg.duration
          ),
          seg.note_num.min,
          reasonable_max
        )
      )
      easedNotes[splitsteps][steps] = seg.note_num.min ~= seg.note_num.max and easedNotes[splitsteps][steps] or seg.note_num.min
      if steps > 1 then
        if easedTimes[splitsteps][steps] < 0
        or easedTimes[splitsteps][steps] <= easedTimes[splitsteps][steps-1]
        or easedTimes[splitsteps][steps] - easedTimes[splitsteps][steps-1] < 0.01 then
          easedTimes[splitsteps][steps] = easedTimes[splitsteps][steps-1] + (math.random(1,6)/100)
        end
      end
    end
    -- print(seg.shape, seg.population)
    -- tab.print(easedTimes[splitsteps])
  end

  allTimes = {}
  allNotes = {}

  for times = 1,#easedTimes[1] do
    allTimes[times] = easedTimes[1][times]
    allNotes[times] = easedNotes[1][times]
  end
  local currentCount = #allTimes
  for finalCount = 2,#easedTimes do

    -- print('there are '..finalCount)

    for times = 2,#easedTimes[finalCount] do
      local thisLast = easedTimes[finalCount][#easedTimes[finalCount]]
      local prevLast = allTimes[currentCount]
      allTimes[#allTimes+1] = util.linlin(
        0,
        thisLast,
        prevLast,
        prevLast + thisLast,
        easedTimes[finalCount][times]
      )
      allNotes[#allNotes+1] = easedNotes[finalCount][times]
    end
    currentCount = #allTimes

  end
  -- for times = 2,#easedTimes[2] do
  --   -- allTimes[#allTimes+1] = easedTimes[2][times] +  allTimes[#allTimes]
  --   local thisLast = easedTimes[2][#easedTimes[2]]
  --   local prevLast = allTimes[currentCount]
  --   allTimes[#allTimes+1] = util.linlin(
  --     0,
  --     thisLast,
  --     prevLast,
  --     prevLast + thisLast,
  --     easedTimes[2][times]
  --   )
  --   allNotes[#allNotes+1] = easedNotes[2][times]
  -- end
  -- currentCount = #allTimes
  -- for times = 2,#easedTimes[3] do
  --   local thisLast = easedTimes[3][#easedTimes[3]]
  --   local prevLast = allTimes[currentCount]
  --   -- allTimes[#allTimes+1] = easedTimes[3][times] +  allTimes[#allTimes]
  --   allTimes[#allTimes+1] = util.linlin(
  --     0,
  --     thisLast,
  --     prevLast,
  --     prevLast + thisLast,
  --     easedTimes[3][times]
  --   )
  --   allNotes[#allNotes+1] = easedNotes[3][times]
  -- end

  -- tab.print(allTimes)

  for index = 1,#allTimes do
    if allTimes[index] < 0 then print('WOAHHH') end
    pass_data_into_storage(i,j,index,{allNotes[index],allTimes[index]})
  end
  
  calculate_timedeltas(i,j)

  _t['shuffle notes'](i,j,hills[i][j].low_bound.note,hills[i][j].high_bound.note)
  screen_dirty = true

  -- print(i,j,total_notes,populous, #allTimes)
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
    print('reconstructing curves '..curves[new_shape](seg.note_timestamp[k],beginVal,change,duration))
    local new_timestamp = curves[new_shape](seg.note_timestamp[k],beginVal,change,duration)
    seg.note_timestamp[k] = new_timestamp
  end
  calculate_timedeltas(i,j)
  screen_dirty = true
end

calculate_timedeltas = function(i,j)
  for k = 1,#hills[i][j].note_timestamp do
    if k < #hills[i][j].note_timestamp then
      hills[i][j].note_timedelta[k] = util.clamp(hills[i][j].note_timestamp[k+1] - hills[i][j].note_timestamp[k], 0.1, inf)
    else
      hills[i][j].note_timedelta[k] = 0.06
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
              pass_note(i,hills[i].segment,seg,seg.note_num.pool[seg.index],seg.index,0)
              seg.index = seg.index + 1
              seg.perf_led = true
            end
            seg.step = util_round(seg.step + 0.01,0.01)
            -- local reasonable_max = seg.note_timestamp[seg.high_bound.note+1] ~= nil and seg.note_timestamp[seg.high_bound.note+1] or seg.note_timestamp[seg.high_bound.note] + seg.note_timedelta[seg.high_bound.note]
            local reasonable_max = seg.note_timestamp[seg.high_bound.note]
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
            pass_note(i,hills[i].segment,seg,seg.note_num.pool[seg.index],seg.index,0)
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
            pass_note(i,hills[i].segment,seg,seg.note_num.pool[seg.index],seg.index,0)
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
          midi_device[dev]:note_off(pre_note[i],0,ch)
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

-- local function inject_data_into_storage(i,j,index,data)
--   table.insert(hills[i][j].note_num.pool, index, data[1])
--   table.insert(hills[i][j].note_timestamp, index, data[2])
--   table.insert(hills[i][j].note_num.chord_degree, index, util.wrap(data[1], 1, 7))
--   hills[i][j].high_bound.note = #hills[i][j].note_num.pool
-- end

local function adjust_timestamps_for_injection(i,j,index,duration)
  for k = index,#hills[i][j].note_timestamp do
    hills[i][j].note_timestamp[k] = hills[i][j].note_timestamp[k] + duration
  end
  hills[i][j].high_bound.time = hills[i][j].note_timestamp[#hills[i][j].note_timestamp]
  calculate_timedeltas(i,j)
end

-- local function inject(shape,i,injection_point,duration)
--   local h = hills[i]
--   local seg = h[h.segment]
--   local total_notes = util_round(#h.note_ocean*seg.population)
--   local index = injection_point-1
--   local current_val = 0
--   local reasonable_max = seg.note_num.min ~= seg.note_num.max and seg.note_num.max or seg.note_num.min+1
--   for j = seg.note_timestamp[injection_point+1]*100,(seg.note_timestamp[injection_point]+duration)*100 do
--     local last_val = current_val
--     current_val = math.floor(util.wrap(curves[shape](j/100,1,total_notes-1,duration),seg.note_num.min,reasonable_max))
--     local note_num = seg.note_num.min ~= seg.note_num.max and current_val or seg.note_num.min
--     if util_round(last_val) ~= util_round(current_val) then
--       index = index + 1
--       inject_data_into_storage(i,h.segment,index,{note_num,j/100})
--     end
--   end
--   adjust_timestamps_for_injection(i,h.segment,index+1,duration)
-- end

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
  -- local target_trig;
  -- local _page = track[i][j].page
  -- if hills[i].highway == true then
  --   if track[i][j][_page].trigs[index] then
  --     target_trig = _fkprm.adjusted_params
  --   else
  --     target_trig = _fkprm.adjusted_params_lock_trigs
  --   end
  -- else
  --   target_trig = _fkprm.adjusted_params
  -- end
  -- if target_trig[i] ~= nil
  -- and target_trig[i][j] ~= nil
  -- and target_trig[i][j][_page][index] ~= nil
  -- and target_trig[i][j][_page][index].params ~= nil
  -- then
  --   return true
  -- else
  --   return false
  -- end
  return true -- 230725, this is always true
end

per_step_params_adjusted = {}
trigless_params_adjusted = {}
for i = 1,number_of_hills do
  per_step_params_adjusted[i] = {param = {}, value = {}}
  trigless_params_adjusted[i] = {param = {}, value = {}}
end

local non_indexed_voices = {'delay', 'feedback', 'main'}

function fkmap(i,j,index,p)
  local target_trig;
  local _page = track[i][j].page
  if hills[i].highway == true then
    if track[i][j][_page].trigs[index] then
      target_trig = _fkprm.adjusted_params
    else
      target_trig = _fkprm.adjusted_params_lock_trigs
    end
  else
    -- print('230520: when is this true???') -- true when doing hills with step params!
    target_trig = _fkprm.adjusted_params
  end
  local value = target_trig[i][j][_page][index].params[p]
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
  local id = params.lookup[parent[k]]
  local is_drum_voice = id <= last_voice_param
  local drum_target = params:get_id(id):match('(.+)_(.+)_(.+)')
  drum_target = tonumber(drum_target)

  local value = params:get(id)

  if is_drum_voice and type(drum_target) == 'number' and drum_target == i then
    local p_name = string.gsub(params:get_id(id),drum_target..'_'..selectedVoiceModels[drum_target]..'_','')
    -- print('reseeding default value for voice', drum_target, p_name, value)
    prms.send_to_engine(drum_target,p_name,value)
  elseif is_drum_voice and type(drum_target) == 'string' then
    -- local target_voice = drum_target
    -- local p_name = string.gsub(params:get_id(id),target_voice..'_','')
    -- prms.send_to_engine(target_voice,p_name,value)
    -- print('reseeding default value for sample voice', i, j, index, id)
    print("this shouldn't be happening: 879")
  elseif drum_target == i then
    local p_name = extract_voice_from_string(params:get_id(id))
    local sc_target = string.gsub(params:get_id(id),p_name..'_','')
    -- print('reseeding default value to fx', i, j, index, id)
    engine['set_'..p_name..'_param'](sc_target,value)
  end
end

-- function play_chord(i,j,index)
--   local chord_target = hills[i].highway == false and hills[i][j].note_num.chord_degree[index] or track[i][j].chord_degrees[index]
--   local base_note;
--   if params:string('hill_'..i..'_mode') == 'highway' then
--     if track[i][j].focus == 'main' then
--       base_note = track[i][j].base_note[index]
--     else
--       base_note = track[i][j].fill.base_note[index]
--     end
--     if base_note == -1 then
--       base_note = params:get(i..'_'..selectedVoiceModels[i]..'_carHz')
--     end
--   else
--     base_note = params:get('hill '..i..' base note')
--   end
--   -- print(index,base_note)
--   local shell_notes = mu.generate_chord_scale_degree(
--     base_note,
--     params:string('hill '..i..' scale'),
--     chord_target,
--     true
--   )
--   -- engine.set_voice_param(i,"carHzThird",midi_to_hz(shell_notes[2]))
--   -- engine.set_voice_param(i,"carHzSeventh",midi_to_hz(shell_notes[4]))
-- end

local function play_linked_sample(i, j, played_note, vel_target, retrig_index, force)
  if params:string("hill "..i.." sample output") == "yes" then
    if params:get("hill "..i.." sample probability") >= math.random(100) then
      local should_play;
      if hills[i].highway then
        local index = track[i][j].step
        local _page = track[i][j].page
        if track[i][j][_page].trigs[index] or force then
          should_play = true
        end
      else
        should_play = true
      end
      if should_play then
        local pad_id = util.wrap((played_note - params:get("hill "..i.." base note")) + 1,1,16)
        _ccparams:unpack_pad(i,pad_id)
      end
      local target = i..'_sample_'
      if params:string(target..'sampleMode') == 'chop' and should_play then
        local slice_count = params:get('hill '..i..' sample slice count') - 1
        local slice = util.wrap(played_note - params:get("hill "..i.." base note"),0,slice_count) + 1
        _ca.play_slice(i,slice,vel_target,i,j,played_note, retrig_index)
      elseif params:string(target..'sampleMode') == 'playthrough' and should_play then
        _ca.play_through(i,vel_target,i,j,played_note, retrig_index)
      elseif params:string(target..'sampleMode') == 'distribute' and should_play then
        local scaled_idx = util_round(sample_info[i].sample_count * (params:get('hill '..i..' sample distribution')/100))
        if scaled_idx ~= 0 then
          local idx = util.wrap(played_note - params:get("hill "..i.." base note"),0,scaled_idx-1) + 1
          _ca.play_index(i,idx,vel_target,i,j,played_note, retrig_index) -- TODO: adjust for actual sample pool size
        end
      end
    end
  end
end

force_note = function(i,j,played_note)
  local vel_target = params:get('hill_'..i..'_iso_velocity')
  local retrig_index = 0
  if selectedVoiceModels[i] ~= 'sample' then
    if params:get('hill_'..i..'_legato') == 0 then
      kildare.allocVoice[i] = util.wrap(kildare.allocVoice[i]+1, 1, params:get(i..'_poly_voice_count'))
      -- engine.trig(i,vel_target,'false',kildare.allocVoice[i])
      send_to_engine('trig',{i,vel_target,'false',kildare.allocVoice[i]})
    end
    send_note_data(i,j,index,played_note)
  else
    play_linked_sample(i, j, played_note, vel_target, retrig_index, true)
  end

  if params:string("hill "..i.." MIDI output") == "yes" then
    local ch = params:get("hill "..i.." MIDI note channel")
    local dev = params:get("hill "..i.." MIDI device")
    if pre_note[i] ~= nil and params:get('hill_'..i..'_legato') ~= 1 then
      midi_device[dev]:note_off(pre_note[i],0,ch)
    end
    midi_device[dev]:note_on(played_note,127,ch)
  end

  pre_note[i] = played_note

end

local function trigger_notes(i,j,index,velocity,retrigger_bool,played_note)
  if params:get('hill_'..i..'_legato') == 0 then
    kildare.allocVoice[i] = util.wrap(kildare.allocVoice[i]+1, 1, params:get(i..'_poly_voice_count'))
    send_to_engine('trig',{i,velocity,retrigger_bool,kildare.allocVoice[i]})
    print(clock.get_beats())
  end
  if params:get('hill_'..i..'_flatten') == 1 then
    send_note_data(i,j,index,params:get(i..'_'..selectedVoiceModels[i]..'_carHz'))
  else
    if params:string("hill "..i.." kildare_notes") == "yes" then
      send_note_data(i,j,index,played_note)
    end
    if hills[i].highway then
      local _page = track[i][j].page
      local focused_notes = track[i][j].focus == 'main' and track[i][j][_page].base_note[index] or track[i][j][_page].fill.base_note[index]
      local focused_chords = track[i][j].focus == 'main' and track[i][j][_page].chord_notes[index] or track[i][j][_page].fill.chord_notes[index]
      local note_check;
      if selectedVoiceModels[i] ~= 'sample' and selectedVoiceModels[i] ~= 'input' then
        note_check = params:get(i..'_'..selectedVoiceModels[i]..'_carHz')
      else
        note_check = params:get('hill '..i..' base note')
      end
      for notes = 1,3 do
        if focused_chords[notes] ~= 0 then
          force_note(i,j,focused_notes == -1 and note_check+focused_chords[notes] or focused_notes+focused_chords[notes])
        end
      end
    end
  end
end

send_note_data = function(i,j,index,played_note)
  -- engine.set_voice_param(i,"carHz",midi_to_hz(played_note))
  send_to_engine('set_voice_param',{i,"carHz",midi_to_hz(played_note)})
end

pass_note = function(i,j,seg,note_val,index,retrig_index)
  local midi_notes = hills[i].note_ocean
  local played_note;
  if hills[i].highway == true then
    played_note = get_random_offset(i,note_val)
  else
    played_note = get_random_offset(i,midi_notes[note_val])
  end
  local _active, _page, _ap, focused_set;
  -- local _active = track[i][j]
  -- local _page = _active.page
  -- local _a = _active[_page]
  if hills[i].highway == true then
    _active = track[i][j]
    _page = _active.page
    _ap = _active[_page]
    focused_set = _active.focus == 'main' and _ap or _ap.fill
  else
    _page = 1
  end
  if (played_note ~= nil and hills[i].highway == false and hills[i][j].note_num.active[index]) or
    (played_note ~= nil and hills[i].highway == true and not focused_set.muted_trigs[index]) then
    -- per-step params //
    -- TODO / FIXME: 230615, added to highway check in next line to avoid errors with hills:
    -- if i <= number_of_hills then
    -- if i <= number_of_hills and hills[i].highway == true then
    if i <= number_of_hills then
      if check_subtables(i,j,index) then
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
            -- print('>S>S>S'..check_prm)
            if _fkprm.adjusted_params[i][j][_page][index].params[check_prm] == nil then
              local lock_trig = track[i][j].focus == 'main' and track[i][j][_page].lock_trigs[index] or track[i][j][_page].fill.lock_trigs[index]
              local is_drum_voice = params.lookup[check_prm] <= last_voice_param
              local id = check_prm
              if is_drum_voice and i <= number_of_hills then
                local target_voice = string.match(id,"%d+")
                local target_drum = id:match('(.*_)')
                target_drum = string.gsub(target_drum, target_voice..'_', '')
                target_drum = string.gsub(target_drum, '_', '')
                local p_name = string.gsub(id,target_voice..'_'..target_drum..'_','')
                prms.send_to_engine(target_voice,p_name,params:get(id))
                -- print('reseeding non-adjusted value for voice', target_voice, j, index, id, p_name)
              else
                local p_name = extract_voice_from_string(id)
                local sc_target = string.gsub(id,p_name..'_','')
                engine['set_'..p_name..'_param'](sc_target,params:get(id))
              end
            end
          end
          per_step_params_adjusted[i] = {param = {}, value = {}}
        end
        -- this step's entry handling:
        -- per_step_params_adjusted[i] = {param = {}, value = {}}
        for k,v in next,target_trig[i][j][_page][index].params do
          -- print('this is ahppening!!')
          local param_id = k
          -- print(k, last_voice_param)
          k = params.lookup[k]
          -- print(k, last_voice_param)
          local is_drum_voice = k <= last_voice_param
          local drum_target = param_id:match('(.+)_(.+)_(.+)')
          drum_target = tonumber(drum_target)
          -- print('huh! '..drum_target, k, params:get_id(k), param_id)
          if is_drum_voice and type(drum_target) == 'number' and drum_target <= number_of_hills then
            if retrig_index == 0 then
              local target_voice = drum_target
              local target_drum = param_id:match('(.*_)')
              target_drum = string.gsub(target_drum, target_voice..'_', '')
              target_drum = string.gsub(target_drum, '_', '')
              local p_name = string.gsub(param_id,target_voice..'_'..target_drum..'_','')
              -- print('sending voice param',target_voice,p_name,fkmap(i,j,index,param_id))
              if target_voice ~= i then
                if not tab.contains(track[target_voice].external_prm_change,param_id) then
                  track[target_voice].external_prm_change[#track[target_voice].external_prm_change+1] = param_id
                end
              end
              prms.send_to_engine(target_voice,p_name,fkmap(i,j,index,param_id))
            end
          else
            local p_name = extract_voice_from_string(param_id)
            local sc_target = string.gsub(param_id,p_name..'_','')
            -- print('sending step param to fx', i, j, index, k)
            engine['set_'..p_name..'_param'](sc_target,fkmap(i,j,index,param_id))
          end
          per_step_params_adjusted[i].param[#per_step_params_adjusted[i].param+1] = param_id
          per_step_params_adjusted[i].value[#per_step_params_adjusted[i].value+1] = v
        
        end
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
    local accent_vel = tonumber(params:string("hill "..i.." accent mult"):sub(1,-2))
    local vel_target = hills[i].highway == false
      and hills[i][j].note_velocity[index]
      or (focused_set.velocities[index] * (focused_set.accented_trigs[index] and accent_vel or 1))
    if hills[i].highway then
      local lock_trig = track[i][j].focus == 'main' and track[i][j][_page].lock_trigs[index] or track[i][j][_page].fill.lock_trigs[index]
      if focused_set.trigs[index] and not focused_set.muted_trigs[index] then
        if retrig_index == nil then
          if selectedVoiceModels[i] ~= 'sample' then
            trigger_notes(i,j,index,vel_target,'false',played_note)
          end
          play_linked_sample(i, j, played_note, vel_target, retrig_index)
        else
          local destination_vel = focused_set.velocities[index] * (focused_set.accented_trigs[index] and accent_vel or 1)
          local destination_count = focused_set.conditional.retrig_count[index]
          local destination_curve = focused_set.conditional.retrig_slope[index]
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
          if selectedVoiceModels[i] ~= 'sample' then
            trigger_notes(i,j,index,retrig_vel,'true',played_note)
          end
          play_linked_sample(i, j, played_note, retrig_vel, retrig_index)
        end
      end
    else
      if selectedVoiceModels[i] ~= 'sample' then
        trigger_notes(i,j,index,vel_target,'false',played_note)
      end
      play_linked_sample(i, j, played_note, vel_target, retrig_index)
    end
    manual_iter(i,j)
    if params:string("hill "..i.." MIDI output") == "yes" then
      local ch = params:get("hill "..i.." MIDI note channel")
      local dev = params:get("hill "..i.." MIDI device")
      if pre_note[i] ~= nil and params:get('hill_'..i..'_legato') ~= 1 then
        midi_device[dev]:note_off(pre_note[i],0,ch)
      end
      midi_device[dev]:note_on(played_note,seg.note_velocity[index],ch)
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
  for idx = 1,#hills[i].iter_links do
    if hills[i].iter_links[idx] == true then
      if hills[i].iter_counter[idx] == 1 then
        local c_hill = hills[idx].segment
        if hills[idx].highway then
          _htracks.tick(idx)
        else
          if hills[idx][c_hill].note_num.pool[hills[idx][c_hill].index] ~= nil then
            pass_note(idx,c_hill,hills[idx][c_hill],hills[idx][c_hill].note_num.pool[hills[idx][c_hill].index],hills[idx][c_hill].index,0)
          end
          hills[idx][c_hill].index = util.wrap(hills[idx][c_hill].index + 1, hills[idx][c_hill].low_bound.note,hills[idx][c_hill].high_bound.note)
        end
      end
      hills[i].iter_counter[idx] = util.wrap(hills[i].iter_counter[idx]+1, 1, hills[i].iter_pulses[idx])
    end
  end
end

function enc(n,d)
  if loading_done then
    if ui.control_set ~= "song" then
      _e.parse(n,d)
    else
      _flow.process_encoder(n,d)
    end
    screen_dirty = true
  end
end

function key(n,z)
  if loading_done then
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
end

redraw = function()
  screen.clear()
  if loading_done then
    screen.font_size(8)
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
  else
    if frames == nil then
      frames = 0
    else
      frames = frames + 1
    end
    -- if frames <= 10 then
    --   screen.move(64,32)
    --   screen.font_size(8)
    --   screen.level(15)
    --   screen.text_center('hills')
    --   screen.level(math.random(3,15))
    --   screen.move(math.random(0,128),math.random(0,64))
    --   screen.font_size(math.random(8,30))
    --   screen.text_center('/')
    --   screen.level(math.random(3,15))
    --   screen.move(math.random(0,128),math.random(0,64))
    --   screen.font_size(math.random(8,30))
    --   screen.text_center('_ _ _')
    --   screen.level(math.random(3,15))
    --   screen.move(math.random(0,128),math.random(0,64))
    --   screen.font_size(math.random(8,30))
    --   screen.text_center('\\ \\ \\')
    --   screen.level(math.random(3,15))
    --   screen.move(math.random(0,128),math.random(0,64))
    --   screen.font_size(math.random(8,30))
    --   screen.text_center('/ /  \\ / \\/ / /')
    -- else
    --   screen.move(54,32)
    --   screen.font_size(8)
    --   -- screen.text_center('hills')
    --   screen.level(math.random(3,15))
    --   screen.text_center('__/\\______/\\\\___')
    --   screen.move(64,32)
    --   screen.level(math.random(3,15))
    --   screen.text_center('____/\\\\\\\\\\___/\\_')
    --   screen.move(74,32)
    --   screen.level(math.random(3,15))
    --   screen.text_center('/\\///_____/\\\\\\__')
    -- end
    if frames > 94 then
      screen.move(64,22)
      screen.level(15)
      -- screen.text_center('hills')
      screen.move(54,32)
      screen.font_size(8)
      -- screen.text_center('hills')
      screen.level(math.random(3,15))
      screen.text_center('__/\\______/\\\\___')
      screen.move(64,32)
      screen.level(math.random(3,15))
      screen.text_center('____/\\\\\\\\\\___/\\_')
      screen.move(74,32)
      screen.level(math.random(3,15))
      screen.text_center('/\\///_____/\\\\\\__')
      screen.update()
      screen_dirty = true
    end
  end
end

function index_to_grid_pos(val,columns)
  local x = math.fmod(val-1,columns)+1
  local y = math.modf((val-1)/columns)+1
  return {x,y}
end

function cleanup ()
  print("cleanup")
  -- if osc_echo ~= nil then
  --   osc.send({osc_echo,57120},"/cleanup",{})
  -- end
  metro.free_all()
end