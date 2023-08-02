_a = require 'lib/actions'
grid_lib = require 'lib/grid_actions'
mu = require 'lib/musicutil'
pt = require 'lib/hills_pt'
MIDI = midi.connect_output()
g = grid.connect()
gridDirty = true

number_of_hills = 7

local util_round = util.round
local pre_note = {}

function load_set(set)
  setToLoad = set
  offsetLoad = set+24
  for i = 1,7 do
    hills[i] = loadTable('/Users/danderks/perm/berlin2023/norns-data/'..offsetLoad..'/data/'..i..'.txt')
  end
  for j = 1,16 do
    local to_inherit = loadTable('/Users/danderks/perm/berlin2023/norns-data/'..offsetLoad.."/patterns/"..j..".txt")
    local inheritances = {'end_point', 'count', 'event', 'loop'}
    for adj = 1, #inheritances do
      grid_pattern[j][inheritances[adj]] = to_inherit[inheritances[adj]]
    end
  end
  psetToLoad = "/Users/danderks/perm/berlin2023/norns-data/hills-"..offsetLoad..".pset"
  readPSET(psetToLoad)
  grid_dirty = true
end

function g.key(x,y,z)
  grid_lib.key(x,y,z)
end

function loadTable(sfile)
  local ftables,err = loadfile(sfile)
  if err then return _, err end
  local tables = ftables()
  for idx = 1, #tables do
    local tolinki = {}
    for i, v in pairs(tables[idx]) do
      if type(v) == "table" then
        tables[idx][i] = tables[v[1]]
      end
      if type(i) == "table" and tables[i[1]] then
        table.insert(tolinki, { i, tables[i[1]] })
      end
    end
    -- link indices
    for _, v in ipairs(tolinki) do
      tables[idx][v[2]], tables[idx][v[1]] =  tables[idx][v[1]], nil
    end
  end
  return tables[1]
end

local function unquote(s)
  return s:gsub('^"', ''):gsub('"$', ''):gsub('\\"', '"')
end

function readPSET(filename)
  local fd = io.open(filename, "r")
  if fd then
    io.close(fd)
    local param_already_set = {}
    for line in io.lines(filename) do
      if util.string_starts(line, "--") then
        params.name = string.sub(line, 4, -1)
      else
        local id, value = string.match(line, "(\".-\")%s*:%s*(.*)")

        if id and value then
          id = unquote(id)
          local index = params.lookup[id]

          if index and params.params[index] and not param_already_set[index] then
            if tonumber(value) ~= nil then
              params.params[index]:set(tonumber(value), silent)
            elseif value == "-inf" then
              params.params[index]:set(-math.huge, silent)
            elseif value == "inf" then
              params.params[index]:set(math.huge, silent)
            elseif value then
              params.params[index]:set(value, silent)
            end
            param_already_set[index] = true
          end
        end
      end
    end
    if params.action_read ~= nil then 
      params.action_read(filename,silent,pset_number)
    end
  else
    print("pset :: "..filename.." not read.")
  end
end

function init()
  mods = {alt = false}
  grid_dirty = true
  scale_names = {}
  local scale_count = 1
  for i = 1,#mu.SCALES do
    scale_names[scale_count] = mu.SCALES[i].name
    scale_count = scale_count + 1
  end

  hills = {}
  for i = 1,7 do
    hills[i] = loadTable('/Users/danderks/perm/berlin2023/norns-data/25/data/'..i..'.txt')
    params:add_separator('hill_'..i..'_note_header', "note management "..i)
    params:add_option("hill "..i.." scale","scale",scale_names,1)
    params:set_action("hill "..i.." scale",
    function(x)
      hills[i].note_ocean = mu.generate_scale_of_length(params:get("hill "..i.." base note"),x,127)
      hills[i].note_intervals = tab.invert(mu.SCALES[x].intervals)
      -- track[i].scale.source = mu.generate_scale_of_length(0,x,127)
      -- if track[i].scale.index > #track[i].scale.source then
      --   track[i].scale.index = 1
      -- end
      grid_dirty = true
    end)
    params:add_number("hill "..i.." base note","base note",0,127,60)
    params:set_action("hill "..i.." base note",
    function(x)
      hills[i].note_ocean = mu.generate_scale_of_length(x,params:get("hill "..i.." scale"),127)
      for j = 1,8 do
        if params:get("hill "..i.." span") > #hills[i].note_ocean then
          params:set("hill "..i.." span",#hills[i].note_ocean)
        end
        for k = 1,#hills[i][j].note_num.pool do
          if hills[i][j].note_num.pool[k] > #hills[i].note_ocean then
            hills[i][j].note_num.pool[k] = #hills[i].note_ocean
          end
        end
      end
      grid_dirty = true
    end)
    params:add_number("hill "..i.." span","note degree span",1,127,14)
    params:set_action("hill "..i.." span",
    function(x)
      for j = 1,8 do
        if x > #hills[i].note_ocean then
          params:set("hill "..i.." span",#hills[i].note_ocean)
        else
          hills[i][j].note_num.max = util.clamp(x+1,1,#hills[i].note_ocean)
        end
        for k = 1,#hills[i][j].note_num.pool do
          if hills[i][j].note_num.pool[k] > x+1 then
            hills[i][j].note_num.pool[k] = x+1
          end
        end
      end
    end)
    params:add_trigger("hill "..i.." octave up","base octave up")
    params:set_action("hill "..i.." octave up",
      function()
        local current_note = params:get("hill "..i.." base note")
        if current_note + 12 <= 127 then
          params:set("hill "..i.." base note", current_note + 12)
        end
        grid_dirty = true
      end
    )
    params:add_trigger("hill "..i.." octave down","base octave down")
    params:set_action("hill "..i.." octave down",
      function()
        local current_note = params:get("hill "..i.." base note")
        if current_note - 12 >= 0 then
          params:set("hill "..i.." base note", current_note - 12)
        end
        grid_dirty = true
      end
    )
    params:add_option("hill "..i.." random offset style", "random offset style", {"+ oct","- oct","+/- oct"},1)
    params:add_number("hill "..i.." random offset probability","random offset probability",0,100,0)
    params:add_option('hill '..i..' reset at stop', 'reset index @ stop?', {'no','yes'}, 2)

    params:add_option("hill "..i.." MIDI output", "MIDI output?",{"no","yes"},1)
    
    params:add_number("hill "..i.." MIDI note channel","note channel",1,16,1)
    params:add_number("hill "..i.." velocity","velocity",0,127,60)

    params:add_separator('hill_'..i..'_iso_header', 'isometric keys management')
    params:add_number('hill_'..i..'_iso_velocity', 'fixed velocity', 0, 127, 70)
    params:add_number('hill_'..i..'_iso_octave', 'octave', -4, 4, 0)
    params:add_option('hill_'..i..'_iso_quantize', 'quantize to scale?', {'no','yes'}, 1)

  end

  params:add_separator('global_pattern_settings','patterns')
  params:add_option('global_pattern_start_rec_at', 'start rec at', {'first event','when engaged'}, 1)
  params:set_action('global_pattern_start_rec_at', function(x)
    for i = 1,16 do
      params:set('pattern_'..i..'_start_rec_at',x)
    end
  end)
  params:add_option('global_pattern_snapshot_mod_capture', 'capture snapshot mods', {'no','yes'}, 1)
  params:set_action('global_pattern_snapshot_mod_capture', function(x)
    for i = 1,16 do
      params:set('pattern_'..i..'_snapshot_mod_restore',x)
    end
  end)
  params:add_option('global_pattern_parameter_change_capture', 'capture param changes', {'no','yes'}, 1)
  params:set_action('global_pattern_parameter_change_capture', function(x)
    for i = 1,16 do
      params:set('pattern_'..i..'_parameter_change_restore',x)
    end
  end)

  for i = 1,16 do
    params:add_separator('pattern_'..i..'_options', 'general')
    params:add_option('pattern_'..i..'_start_rec_at', 'start rec at', {'first event','when engaged'}, 1)
    params:add_option('pattern_'..i..'_snapshot_mod_restore', 'capture snapshot mods', {'no','yes'}, 1)
    params:add_option('pattern_'..i..'_parameter_change_restore', 'capture param changes', {'no','yes'}, 1)
  end

  gridInit()
  load_set(1)

  for i = 1,7 do
    hills[i].counter = clock.run(function() iterate(i) end)
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
  grid_dirty = true
  seg.end_of_cycle_clock = clock.run(
    function()
      clock.sleep(1/15)
      if seg.iterated then
        seg.perf_led = false
        grid_dirty = true
        if params:string("hill "..i.." MIDI output") == "yes" then
          MIDI:note_off(pre_note[i],0,ch)
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

pass_note = function(i,j,seg,note_val,index,retrig_index)
  local midi_notes = hills[i].note_ocean
  local played_note;
  if hills[i].highway == true then
    played_note = get_random_offset(i,note_val)
  else
    played_note = get_random_offset(i,midi_notes[note_val])
  end
  local _active, _page, _ap, focused_set;
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
      -- seamstress version:
      trigger_notes(i,j,index,vel_target,'false',played_note)
      manual_iter(i,j)
      local ch = params:get("hill "..i.." MIDI note channel")
      if pre_note[i] ~= nil then
        MIDI:note_off(pre_note[i],0,ch)
      end
      MIDI:note_on(played_note,seg.note_velocity[index],ch)
      pre_note[i] = played_note
      screen_dirty = true
      grid_dirty = true
      --
  end
  screen_dirty = true
  grid_dirty = true
end

force_note = function(i,j,played_note)
  local vel_target = params:get('hill_'..i..'_iso_velocity')
  local ch = params:get("hill "..i.." MIDI note channel")
  if pre_note[i] ~= nil then
    MIDI:note_off(pre_note[i],0,ch)
  end
  MIDI:note_on(played_note,vel_target,ch)
  pre_note[i] = played_note
end

function trigger_notes(i,j,index,velocity,retrigger_bool,played_note)
  -- not needed unless i'm also running tracks...
end

function get_random_offset(i,note)
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