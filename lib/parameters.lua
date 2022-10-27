local parameters = {}
local frm = require 'formatters'

local vports = {}

local function refresh_params_vports()
  for i = 1,#midi.vports do
    vports[i] = midi.vports[i].name ~= "none" and util.trim_string_to_width(midi.vports[i].name,70) or tostring(i)..": [device]"
  end
end

local function round_form(param,quant,form)
  return(util.round(param,quant)..form)
end

-- local hill_names = {"A","B","C","D","E","F","G","H"}
-- local hill_names = {
--   "[1] (bd)",
--   "[2] (sd)",
--   "[3] (tm)",
--   "[4] (cp)",
--   "[5] (rs)",
--   "[6] (cb)",
--   "[7] (hh)",
--   "[8] (s-1)",
--   "[9] (s-2)",
--   "[10] (s-3)"
-- }

function parameters.change_UI_name(id, new_name)
  params.params[params.lookup[id]].name = new_name
end

function parameters.send_to_engine(voice,param,value)
  if param == 'carHz' then
    engine.set_voice_param(voice, param, mu.note_num_to_freq(value))
  elseif param == 'poly' then
    engine.set_voice_param(voice, param, value == 1 and 0 or 1)
  else
    engine.set_voice_param(voice, param, value)
  end
end

function parameters.init()
  refresh_params_vports()

  params:add_separator('hills_main_header', 'hills')
  for i = 1,number_of_hills do
    params:add_group('hill_'..i..'_group', hill_names[i], i > 7 and 64 or 67)

    params:add_separator('hill_'..i..'_highway_header', 'mode')
    params:add_option('hill_'..i..'_highway', 'mode', {'hill','highway'}, 1)
    params:set_action('hill_'..i..'_highway', function(x)
      if x == 1 then
        hills[i].highway = false
      else
        hills[i].highway = true
      end
      screen_dirty = true
    end)
    params:add_separator('hill_'..i..'_note_header', "note management "..hill_names[i])
    params:add_option("hill "..i.." scale","scale",scale_names,1)
    params:set_action("hill "..i.." scale",
    function(x)
      for j = 1,8 do
        hills[i][j].note_ocean = mu.generate_scale_of_length(params:get("hill "..i.." base note"),x,127)
      end
    end)
    params:add_number("hill "..i.." base note","base note",0,127,60)
    params:set_action("hill "..i.." base note",
    function(x)
      for j = 1,8 do
        hills[i][j].note_ocean = mu.generate_scale_of_length(x,params:get("hill "..i.." scale"),127)
        if params:get("hill "..i.." span") > #hills[i][j].note_ocean then
          params:set("hill "..i.." span",#hills[i][j].note_ocean)
        end
        for k = 1,#hills[i][j].note_num.pool do
          if hills[i][j].note_num.pool[k] > #hills[i][j].note_ocean then
            hills[i][j].note_num.pool[k] = #hills[i][j].note_ocean
          end
        end
      end
    end)
    params:add_number("hill "..i.." span","note degree span",1,127,14)
    params:set_action("hill "..i.." span",
    function(x)
      for j = 1,8 do
        if x > #hills[i][j].note_ocean then
          params:set("hill "..i.." span",#hills[i][j].note_ocean)
        else
          hills[i][j].note_num.max = util.clamp(x+1,1,#hills[i][j].note_ocean)
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
      end
    )
    params:add_trigger("hill "..i.." octave down","base octave down")
    params:set_action("hill "..i.." octave down",
      function()
        local current_note = params:get("hill "..i.." base note")
        if current_note - 12 >= 0 then
          params:set("hill "..i.." base note", current_note - 12)
        end
      end
    )
    params:add_option("hill "..i.." random offset style", "random offset style", {"+ oct","- oct","+/- oct"},1)
    params:add_number("hill "..i.." random offset probability","random offset probability",0,100,0)
    params:add_option("hill "..i.." quant value","quant value",{"1/4", "1/4d", "1/4t", "1/8", "1/8d", "1/8t", "1/16", "1/16d", "1/16t", "1/32", "1/32d", "1/32t"},7)
    params:add_option('hill '..i..' reset at stop', 'reset index @ stop?', {'no','yes'}, 2)

    if i <= 7 then
      params:add_separator('hill_'..i..'_kildare_header', "Kildare management "..hill_names[i])
      params:add_option("hill "..i.." kildare_notes","send pitches?",{"no","yes"},1)
      params:set_action("hill "..i.." kildare_notes",
        function(x)
          if x == 1 then
            local note_to_send = mu.note_num_to_freq(params:get(i.."_"..(params:string('voice_model_'..i)).."_carHz"))
            engine.set_voice_param(i,"carHz", note_to_send)
            engine.set_voice_param(i,"thirdHz", note_to_send)
            engine.set_voice_param(i,"seventhHz", note_to_send)
            params:hide("hill "..i.." kildare_chords")
            params:set("hill "..i.." kildare_chords",1)
          elseif x == 2 then
            params:show("hill "..i.." kildare_chords")
          end
          _menu.rebuild_params()
        end
      )
      params:add_option("hill "..i.." kildare_chords","send chords?",{"no","yes"},1)
      params:set_action("hill "..i.." kildare_chords",
        function(x)
          if x == 1 then
            local return_to = mu.note_num_to_freq(params:get(i.."_"..(params:string('voice_model_'..i)).."_carHz"))
            engine.set_voice_param(i,"thirdHz", return_to)
            engine.set_voice_param(i,"seventhHz", return_to)
          end
        end
      )
      -- params:add_number("hill "..i.." kildare_chord_degree","chord degree",1,7,1)
    end

    params:add_separator('hill_'..i..'_sample_header', "sample management "..hill_names[i])
    params:add_option("hill "..i.." sample output","sample output?",{"no","yes"},i<= 7 and 1 or 2)
    params:set_action("hill "..i.." sample output",
      function(x)
        if x == 1 then
          params:hide("hill "..i.." sample slot")
          params:hide("hill "..i.." sample slice count")
          params:hide("hill "..i.." sample distribution")
          params:hide("hill "..i.." sample probability")
          params:hide("hill "..i.." sample repitch")
          params:hide("hill "..i.." sample momentary")
          _menu.rebuild_params()
        elseif x == 2 then
          if i <= 7 then
            params:show("hill "..i.." sample slot")
          end
          if params:string('sample'..params:string('hill '..i..' sample slot')..'_sampleMode') == 'distribute' then
            params:show("hill "..i.." sample distribution")
            params:hide("hill "..i.." sample slice count")
          elseif params:string('sample'..params:string('hill '..i..' sample slot')..'_sampleMode') == 'chop' then
            params:hide("hill "..i.." sample distribution")
            params:show("hill "..i.." sample slice count")
          else
            params:hide("hill "..i.." sample distribution")
            params:hide("hill "..i.." sample slice count")
          end
          params:show("hill "..i.." sample probability")
          params:show("hill "..i.." sample repitch")
          params:show("hill "..i.." sample momentary")
          _menu.rebuild_params()
        end
      end
    )
    params:add_number("hill "..i.." sample slot", "sample slot",1,3,i<= 7 and 1 or i-7)
    params:set_action("hill "..i.." sample slot", function(x)
      if params:string('sample'..x..'_sampleMode') == 'distribute' then
        params:show("hill "..i.." sample distribution")
        params:hide("hill "..i.." sample slice count")
      elseif params:string('sample'..x..'_sampleMode') == 'chop' then
        params:hide("hill "..i.." sample distribution")
        params:show("hill "..i.." sample slice count")
      else
        params:hide("hill "..i.." sample distribution")
        params:hide("hill "..i.." sample slice count")
      end
      _menu.rebuild_params() 
    end)
    if i > 7 then
      params:hide("hill "..i.." sample slot")
      _menu.rebuild_params() 
    end
    params:add_number("hill "..i.." sample slice count", "slice count",2,48,16)
    params:add_number("hill "..i.." sample distribution", "total distribution",0,100,100, 
      function(param)
        return(util.round(sample_info['sample'..params:get('hill '..i..' sample slot')].sample_count * (param:get()/100))..'/'..sample_info['sample'..params:get('hill '..i..' sample slot')].sample_count)
      end
    )   
    params:add_number("hill "..i.." sample probability", "playback probability",0,100,100, function(param) return(param:get().."%") end)
    params:add_option("hill "..i.." sample repitch", "send pitches?",{"no","yes"},1)
    params:add_option("hill "..i.." sample momentary", "stop when released?", {"no","yes"},1)

    params:add_separator('hill_'..i..'_MIDI_header', "MIDI management "..hill_names[i])
    params:add_option("hill "..i.." MIDI output", "MIDI output?",{"no","yes"},1)
    params:set_action("hill "..i.." MIDI output",
      function(x)
        if x == 1 then
          params:hide("hill "..i.." MIDI device")
          params:hide("hill "..i.." MIDI note channel")
          params:hide("hill "..i.." MIDI device")
          params:hide("hill "..i.." velocity")
          for j = 1,5 do
            params:hide("hill "..i.." cc_"..j)
            params:hide("hill "..i.." cc_"..j.."_ch")
          end
          _menu.rebuild_params()
        elseif x == 2 then
          params:show("hill "..i.." MIDI device")
          params:show("hill "..i.." MIDI note channel")
          params:show("hill "..i.." MIDI device")
          params:show("hill "..i.." velocity")
          -- for j = 1,5 do
          --   params:show("hill "..i.." cc_"..j)
          --   params:show("hill "..i.." cc_"..j.."_ch")
          -- end
          _menu.rebuild_params()
        end
      end
    )
    params:add_option("hill "..i.." MIDI device", "device",vports,1)
    params:add_number("hill "..i.." MIDI note channel","note channel",1,16,1)
    params:add_number("hill "..i.." velocity","velocity",0,127,60)
    local fixed_ccs = {}
    fixed_ccs[1] = "none"
    for j = 0,127 do
      fixed_ccs[j+2] = j
    end
    for j = 1,5 do
      params:add_option("hill "..i.." cc_"..j,"hill "..i.." cc "..j,fixed_ccs,1)
      params:add_number("hill "..i.." cc_"..j.."_ch","hill "..i.." cc "..j.." ch",1,16,1)
    end
    for j = 1,8 do
      params:add_option("hill ["..i.."]["..j.."] shape", "hill ["..i.."]["..j.."] shape", curves.easingNames, math.random(#curves.easingNames))
      params:set_action("hill ["..i.."]["..j.."] shape", function(x)
        hills[i][j].shape = curves.easingNames[x]
      end)
      params:hide("hill ["..i.."]["..j.."] shape")
      params:add_number("hill ["..i.."]["..j.."] population","hill ["..i.."]["..j.."] population",10,100,50)
      params:set_action("hill ["..i.."]["..j.."] population",
      function(x)
        hills[i][j].population = x/100
      end)
      params:hide("hill ["..i.."]["..j.."] population")
    end

    params:add_separator('hill_'..i..'_crow_header', "crow management "..hill_names[i])
    params:add_option("hill "..i.." crow output", "crow output?",{"no","yes"},1)
    params:set_action("hill "..i.." crow output",
      function(x)
        if x == 1 then
          params:hide("hill "..i.." crow output style")
          params:hide("hill "..i.." crow output id")
          params:hide("hill "..i.." crow osc shape")
          params:hide("hill "..i.." crow osc aliasing")
          params:hide("hill "..i.." crow osc level")
          params:hide("hill "..i.." crow osc decay")
        else
          params:show("hill "..i.." crow output style")
          params:show("hill "..i.." crow output id")
        end
        _menu.rebuild_params()
      end
    )
    params:add_option("hill "..i.." crow output style", "output style",{"v/8","v/8+pulse","pulse","osc"},1)
    params:set_action("hill "..i.." crow output style",
      function(x)
        if params:string("hill "..i.." crow output") == "yes" then
          if x ~= 4 then
            params:hide("hill "..i.." crow osc shape")
            params:hide("hill "..i.." crow osc aliasing")
            params:hide("hill "..i.." crow osc level")
            params:hide("hill "..i.." crow osc decay")
          end
          if x == 2 then
            params:show("hill "..i.." crow v/8 pulse output id")
          elseif x ~= 2 then
            params:hide("hill "..i.." crow v/8 pulse output id")
          end
          if x == 4 then
            params:show("hill "..i.." crow osc shape")
            params:show("hill "..i.." crow osc aliasing")
            params:show("hill "..i.." crow osc level")
            params:show("hill "..i.." crow osc decay")
          end
          _menu.rebuild_params()
          hills[i].crow_change_queued = true
        end
      end
    )
    params:add_number("hill "..i.." crow output id", "out id",1,4,1)
    params:set_action("hill "..i.." crow output id",
      function()
        hills[i].crow_change_queued = true
      end
    )
    params:add_number("hill "..i.." crow v/8 pulse output id","secondary out id",1,4,2)
    params:set_action("hill "..i.." crow v/8 pulse output id",
      function()
        hills[i].crow_change_queued = true
      end
    )
    params:add_option("hill "..i.." crow osc shape", "shape",{'linear','sine','logarithmic','exponential','now','wait','over','under','rebound'},1)
    params:set_action("hill "..i.." crow osc shape",
      function()
        hills[i].crow_change_queued = true
      end
    )
    params:add_option("hill "..i.." crow osc aliasing", "aliasing",{'none','soft','harsh'},1)
    params:set_action("hill "..i.." crow osc aliasing",
      function()
        hills[i].crow_change_queued = true
      end
    )
    params:add_number("hill "..i.." crow osc level", "output level",0,100,50)
    params:add_control("hill "..i.." crow osc decay", "output decay", controlspec.new(50,100,'exp',0,95,"%"))

    params:hide("hill "..i.." crow output style")
    params:hide("hill "..i.." crow output id")
    params:hide("hill "..i.." crow v/8 pulse output id")
    params:hide("hill "..i.." crow osc shape")
    params:hide("hill "..i.." crow osc aliasing")
    params:hide("hill "..i.." crow osc level")
    params:hide("hill "..i.." crow osc decay")

    params:add_separator('hill_'..i..'_JF_header', "JF management "..hill_names[i])
    params:add_option("hill "..i.." JF output", "JF output?",{"no","yes"},1)
    params:set_action("hill "..i.." JF output",
      function(x)
        if x == 1 then
          params:hide("hill "..i.." JF output style")
          params:hide("hill "..i.." JF output id")
          _menu.rebuild_params()
        else
          params:show("hill "..i.." JF output style")
          params:show("hill "..i.." JF output id")
          _menu.rebuild_params()
        end
      end
    )
    params:add_option("hill "..i.." JF output style", "output style",{"sound","shape"},1)
    params:add_option("hill "..i.." JF output id","output id",{"IDENTITY","2N","3N","4N","5N","6N","all"},1)
    params:hide("hill "..i.." JF output style")
    params:hide("hill "..i.." JF output id")
  end

  params:add_separator('hills_pattern_header', 'pattern + snapshot settings')
  
  params:add_group('global_pattern_group', 'global', 23)
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

  params:add_separator('global_snapshot_settings','snapshot mods')
  local default_times = {0.1,0.5,1.2,2.0,4.5,10}
  for i = 1,6 do
    params:add_option('global_snapshot_mod_mode_'..i, i..': mode', {'free','clocked'})
    params:set_action('global_snapshot_mod_mode_'..i, function(x)
      if x == 1 then
        params:show('global_snapshot_mod_time_'..i)
        params:hide('global_snapshot_mod_beats_'..i)
      else
        params:hide('global_snapshot_mod_time_'..i)
        params:show('global_snapshot_mod_beats_'..i)
      end
      _menu.rebuild_params()
    end)
    params:add_control(
      'global_snapshot_mod_time_'..i,
      '  duration',
      controlspec.new(0.1,300,'exp',0.01,default_times[i],'sec',0.01)
    )
    params:add_number(
      'global_snapshot_mod_beats_'..i,
      '  duration',
      1,
      64,
      i,
      function(param) return (param:get().." beats") end
    )
  end

  params:add_group('snapshot_crossfade_settings', 'snapshot crossfaders', 32 + 140)

  local function spec_format(param, value, units)
    return value.." "..(units or param.controlspec.units or "")
  end

  function crossfade_widget(param)
    local dots_per_side = 8
    local widget
    local function add_dots(num_dots)
      for i=1,num_dots do widget = (widget or "").."." end
    end
    local function add_bar()
      widget = (widget or "").."|"
    end
  
    local value = param:get()
    local pan_side = math.abs(value)
    local pan_side_percentage = util.round(pan_side*100)
    local descr
    local dots_left
    local dots_right
  
    if value > 0 then
      dots_left = dots_per_side+util.round(pan_side*dots_per_side)
      dots_right = util.round((1-pan_side)*dots_per_side)
      if pan_side_percentage >= 1 then
        descr = "R"..pan_side_percentage
      end
    elseif value < 0 then
      dots_left = util.round((1-pan_side)*dots_per_side)
      dots_right = dots_per_side+util.round(pan_side*dots_per_side)
      if pan_side_percentage >= 1 then
       descr = "L"..pan_side_percentage
      end
    else
      dots_left = dots_per_side
      dots_right = dots_per_side
    end
  
    if descr == nil then
      descr = "C"
    end
  
    add_bar()
    add_dots(dots_left)
    add_bar()
    add_dots(dots_right)
    add_bar()
  
    return spec_format(param, descr.." "..widget, "")
  end

  local function lfo_params_visibility(state, i)
    params[state](params, "lfo_baseline_"..i)
    params[state](params, "lfo_offset_"..i)
    params[state](params, "lfo_depth_"..i)
    params:hide("lfo_scaled_"..i)
    params:hide("lfo_raw_"..i)
    params[state](params, "lfo_mode_"..i)
    if state == "show" then
      if params:get("lfo_mode_"..i) == 1 then
        params:hide("lfo_free_"..i)
        params:show("lfo_clocked_"..i)
      elseif params:get("lfo_mode_"..i) == 2 then
        params:hide("lfo_clocked_"..i)
        params:show("lfo_free_"..i)
      end
    else
      params:hide("lfo_clocked_"..i)
      params:hide("lfo_free_"..i)
    end
    params[state](params, "lfo_shape_"..i)
    params[state](params, "lfo_min_"..i)
    params[state](params, "lfo_max_"..i)
    params[state](params, "lfo_reset_"..i)
    params[state](params, "lfo_reset_target_"..i)
    _menu.rebuild_params()
  end

  local function lfo_bang(i)
    local function lb(prm)
      params:lookup_param("lfo_"..prm.."_"..i):bang()
    end
    lb('depth')
    lb('min')
    lb('max')
    lb('baseline')
    lb('offset')
    lb('mode')
    lb('clocked')
    lb('free')
    lb('shape')
    lb('reset')
    lb('reset_target')
  end

  for i = 1,10 do
    params:add_separator('snapshot_crossfade_header_'..i, 'crossfader '..hill_names[i])
    params:add_number('snapshot_crossfade_left_'..i, 'left snapshot',1,16,1)
    params:add_number('snapshot_crossfade_right_'..i, 'right snapshot',1,16,1)
    params:add_control('snapshot_crossfade_value_'..i, 'crossfade', controlspec.PAN, crossfade_widget)
    params:set('snapshot_crossfade_value_'..i,-1)
    params:set_action('snapshot_crossfade_value_'..i,function(x)
      _snapshots.crossfade(i,params:get('snapshot_crossfade_left_'..i), params:get('snapshot_crossfade_right_'..i), x)
    end)
    snapshot_lfos[i] = _lfo:add{
      min = -1,
      max = 1,
      action = function(s,r) params:set('snapshot_crossfade_value_'..i,s) end,
      ppqn = 32
    }

    snapshot_lfos[i]:add_params('snapshot_'..i)
    parameters.change_UI_name('lfo_snapshot_'..i,'lfo')
    params.params[params.lookup['lfo_min_snapshot_'..i]].formatter = crossfade_widget
    params.params[params.lookup['lfo_max_snapshot_'..i]].formatter = crossfade_widget
    params:set_action("lfo_snapshot_"..i,function(x)
      if x == 1 then
        lfo_params_visibility("hide", 'snapshot_'..i)
        params:set("lfo_scaled_snapshot_"..i,"")
        params:set("lfo_raw_snapshot_"..i,"")
        snapshot_lfos[i]:stop()
      elseif x == 2 then
        lfo_params_visibility("show", 'snapshot_'..i)
        snapshot_lfos[i]:start()
      end
      snapshot_lfos[i]:set('enabled',x-1)
      lfo_bang('snapshot_'..i)
    end)
    
  end

  for i = 1,16 do
    params:add_group('pattern_group_'..i, 'pattern '..i, (1 + 15) + (1 + 3))
    params:add_separator('pattern_'..i..'_options', 'general')
    params:add_option('pattern_'..i..'_start_rec_at', 'start rec at', {'first event','when engaged'}, 1)
    params:add_option('pattern_'..i..'_snapshot_mod_restore', 'capture snapshot mods', {'no','yes'}, 1)
    params:add_option('pattern_'..i..'_parameter_change_restore', 'capture param changes', {'no','yes'}, 1)
    params:add_separator('pattern_'..i..'_links_header', 'links')
    for j = 1,16 do
      if i ~= j then
        params:add_option('pattern_'..i..'_link_'..j, i..' -> '..j,{'no','yes'},1)
        params:set_action('pattern_'..i..'_link_'..j, function(x)
          if x == 1 then
            pattern_links[i][j] = false
          else
            pattern_links[i][j] = true
          end
          grid_dirty = true
        end)
      end
    end
  end

  _menu.rebuild_params()
  clock.run(function() clock.sleep(1) params:bang() end)
end

return parameters