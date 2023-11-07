-- adapted from @markeats

local musicutil = require 'musicutil'

lfos = {}
lfos.count = 32

lfos.rates = {1/16,1/8,1/4,5/16,1/3,3/8,1/2,3/4,1,1.5,2,3,4,6,8,16,32,64,128,256,512,1024}
lfos.rates_as_strings = {"1/16","1/8","1/4","5/16","1/3","3/8","1/2","3/4","1","1.5","2","3","4","6","8","16","32","64","128","256","512","1024"}

lfos.targets = {}
lfos.current_baseline = {}
lfos.specs = {}

lfos.params_list = {}
lfos.last_param = {}
lfos.last_track = {}
for i = 1,lfos.count do
  lfos.last_param[i] = "empty"
  lfos.last_track[i] = 'none'
end
_ps.lfos = {}
for i = 1,lfos.count do
  _ps.lfos[i] = {
    lfoTargetTrack = {},
    lfoTargetTrack_string = {},
    lfo_target_param = {},
    lfo_target_param_string = {},
    lfo_min = {}
  }
end

_lfo = require 'lfo'

all_loaded = false

klfo = {}

ivals = {}

function lfos.add_params(track_count, fx_names, poly)

  for i = 1,lfos.count do
    klfo[i] = _lfo:add{
      action = 
      function(s,r)
        local target_track = _ps.lfos[i].lfoTargetTrack_string
        local target_param = _ps.lfos[i].lfo_target_param
        local param_name = lfos.params_list[target_track]
        if not lfos.current_baseline[i] then
          lfos.send_param_value(target_track, param_name.ids[(target_param)], s)
        else
          local current_centroid = math.abs(_ps.lfos[i].min - params:get("lfo_max_"..i)) * klfo[i].depth
          local scaled_min = util.clamp(params:get(target_track..'_'..lfos.params_list[target_track].ids[target_param]) - current_centroid, _ps.lfos[i].min, params:get("lfo_max_"..i))
          local scaled_max = util.clamp(params:get(target_track..'_'..lfos.params_list[target_track].ids[target_param]) + current_centroid, _ps.lfos[i].min, params:get("lfo_max_"..i))
          r = util.linlin(0,1,scaled_min, scaled_max,r + klfo[i].offset)
          lfos.send_param_value(target_track, param_name.ids[(target_param)], r)
        end
      end
    }
    klfo[i]:set('ppqn',32)
  end

  local lfo_target_iter = 1
  for i = 1,track_count do
    lfos.targets[lfo_target_iter] = i
    lfo_target_iter = lfo_target_iter + 1
  end

  for i = 1,#fx_names do
    lfos.targets[lfo_target_iter] = fx_names[i]
    lfo_target_iter = lfo_target_iter + 1
  end

  for i = 1,#lfos.targets do
    local v = lfos.targets[i]
    ivals[v] = {1 + (16*(i-1)), (16 * i)}
  end

  local fx_iter = 1
  for i = 1,#fx_names do -- 3 = number of fx parameters
    local fx = fx_names[i]
    lfos[fx.."_params"] = {}
    for j = 1,#kildare_fx_params[fx] do
      local prm = kildare_fx_params[fx][j]
      local prm_iter = 1
      if prm.type ~= "separator" then
        lfos[fx.."_params"][prm_iter] = prm.id
        prm_iter = prm_iter + 1
      end
    end
  end

  local ival_iter = 1
  for i = 1,#lfos.targets do
    local spec_target = lfos.targets[i]
    lfos.rebuild_model_spec(spec_target,poly)
  end

  lfos.build_params_static(poly)

  params:add_group("lfos",lfos.count * 16)
  for i = 1,lfos.count do
    lfos.last_track[i] = 1
    lfos.last_param[i] = "amp"
    
    params:add_separator('lfo_'..i..'_separator', "lfo "..i)
    params:add_control(
      "lfo_"..i,
      "state",
      controlspec.new(1,2,'lin',1,1,'',1),
      function(param) local modes = {"off","on"} return modes[(type(param) == 'table' and param:get() or param)] end
    )
    
    params:set_action("lfo_"..i,function(x)
      if x == 1 then
        klfo[i]:stop()
        if all_loaded then
          print('lfo state callback',i)
          lfos.return_to_baseline(i,true,true)
          params:set("lfo_target_param_"..i,1)
          params:set("lfo_depth_"..i,0)
        end
        params:hide("lfoTargetTrack_"..i)
        params:hide("lfo_target_track_"..i)
        params:hide("lfo_target_param_"..i)
        params:hide("lfo_shape_"..i)
        params:hide("lfo_beats_"..i)
        params:hide("lfo_free_"..i)
        params:hide("lfo_offset_"..i)
        params:hide("lfo_depth_"..i)
        params:hide("lfo_min_"..i)
        params:hide("lfo_max_"..i)
        params:hide("lfo_mode_"..i)
        params:hide("lfo_baseline_"..i)
        params:hide("lfo_reset_"..i)
        params:hide("lfo_reset_target_"..i)
        -- _menu.rebuild_params()
        menu_rebuild_queued = true
      elseif x == 2 then
        klfo[i]:start()
        params:show("lfo_target_track_"..i)
        params:show("lfo_target_param_"..i)
        params:show("lfo_shape_"..i)
        if params:get("lfo_mode_"..i) == 1 then
          params:show("lfo_beats_"..i)
        else
          params:show("lfo_free_"..i)
        end
        params:show("lfo_offset_"..i)
        params:show("lfo_depth_"..i)
        params:show("lfo_min_"..i)
        params:show("lfo_max_"..i)
        params:show("lfo_mode_"..i)
        params:show("lfo_baseline_"..i)
        params:show("lfo_reset_"..i)
        params:show("lfo_reset_target_"..i)
        -- _menu.rebuild_params()
        menu_rebuild_queued = true
      end
    end)

    params:add_option("lfoTargetTrack_"..i, "track", lfos.targets, 1)
    params:set_action("lfoTargetTrack_"..i,
      function(x)
        _ps.lfos[i].lfoTargetTrack = x
			  _ps.lfos[i].lfoTargetTrack_string = lfos.targets[x])
        lfos.change_target(i,x)
      end
    )
    local endcaps = {'delay','feedback','main'}
    
    params:add_control(
      "lfo_target_track_"..i,
      "track",
      controlspec.new(1,10,'lin',1,1,nil,1/10),
      function(param)
        if param:get() <=  kildare_total_tracks then
          return (param:get() .. ': ' .. params:string('voice_model_'..param:get()))
        else
          return (endcaps[param:get() - kildare_total_tracks])
        end
      end
    )
    params:set_action("lfo_target_track_"..i, function(x) params:set('lfoTargetTrack_'..i, x) end)

    params:add_option("lfo_target_param_"..i, "param",lfos.params_list[lfos.targets[1]].names,1)
    params:set_action("lfo_target_param_"..i,
      function(x)
        _ps.lfos[i].lfo_target_param = x
        _ps.lfos[i].lfo_target_param_string = lfos.params_list[lfos.targets[1]].names[x]
        lfos.rebuild_param("min",i)
        lfos.rebuild_param("max",i)
        if params:string('lfo_'..i) ~= 'off' then
          print('lfo param callback',i)
          lfos.return_to_baseline(i,nil,true)
        end
        lfos.reset_bounds_in_menu(i)
      end
    )

    -- params:add_option("lfo_shape_"..i, "shape", {"sine","saw","square","random"},1)
    local lfo_shapes = {'sine','tri','square','random','up','down'}
    params:add_control(
      "lfo_shape_"..i,
      "shape",
      controlspec.new(1,#lfo_shapes,'lin',1,1,'',1/(#lfo_shapes-1)),
      function(param) return lfo_shapes[(type(param) == 'table' and param:get() or param)] end
    )
    params:set_action('lfo_shape_'..i, function(x)
      klfo[i]:set('shape', lfo_shapes[x])
    end)

    -- params:add_option("lfo_beats_"..i, "rate", lfos.rates_as_strings, tab.key(lfos.rates_as_strings,"1"))
    params:add_control(
      "lfo_beats_"..i,
      "rate",
      controlspec.new(1,#lfos.rates_as_strings,'lin',1,tab.key(lfos.rates_as_strings,"1"),'',1/(#lfos.rates_as_strings-1)),
      function(param) return lfos.rates_as_strings[(type(param) == 'table' and param:get() or param)] end
    )
    params:set_action("lfo_beats_"..i,
      function(x)
        if params:string("lfo_mode_"..i) == "clocked bars" then
          klfo[i]:set('period',lfos.rates[x] * 4)
        end
      end
    )

    params:add{
      type = 'control',
      id = "lfo_free_"..i,
      name = "rate",
      controlspec = controlspec.new(0.1,300,'exp',0.1,1,'sec')
    }
    params:set_action("lfo_free_"..i,
      function(x)
        if params:string("lfo_mode_"..i) == "free" then
          klfo[i]:set('period',x)
        end
      end
    )

    params:add_control(
      "lfo_depth_"..i,
      "depth",
      controlspec.new(0,100,'lin',1,0,'',0.01),
      function(param) return (type(param) == 'table' and (param:get()..'%') or (param..'%')) end
    )
    params:set_action("lfo_depth_"..i, function(x)
      klfo[i]:set('depth',x/100)
      if x == 0 then
        if params:string('lfo_'..i) ~= 'off' then
          print('lfo depth callback',i)
          lfos.return_to_baseline(i,true,true)
        end
      end
    end)

    params:add_control(
      "lfo_offset_"..i,
      "offset",
      controlspec.new(-100,100,'lin',1,0,'',0.005),
      function(param) return (type(param) == 'table' and (param:get()..'%') or (param..'%')) end
    )
    params:set_action("lfo_offset_"..i, function(x)
      klfo[i]:set('offset',x/100)
    end)

    local target_track =  _ps.lfos[i].lfoTargetTrack_string
    local target_param = _ps.lfos[i].lfo_target_param
    params:add{
      type='control',
      id="lfo_min_"..i,
      name="lfo min",
      controlspec = controlspec.new(
        lfos.specs[target_track][target_param].min,
        lfos.specs[target_track][target_param].max,
        lfos.specs[target_track][target_param].warp,
        lfos.specs[target_track][target_param].step,
        lfos.specs[target_track][target_param].min,
        '',
        lfos.specs[target_track][target_param].quantum
      )
    }
    params:set_action('lfo_min_'..i, function(x)
      _ps.lfos[i].min = x
      klfo[i]:set('min',x)
    end)

    params:add{
      type='control',
      id="lfo_max_"..i,
      name="lfo max",
      controlspec = controlspec.new(
        lfos.specs[target_track][target_param].min,
        lfos.specs[target_track][target_param].max,
        lfos.specs[target_track][target_param].warp,
        lfos.specs[target_track][target_param].step,
        lfos.specs[target_track][target_param].default,
        '',
        lfos.specs[target_track][target_param].quantum
      )
    }
    params:set_action('lfo_max_'..i, function(x)
      klfo[i]:set('max',x)
    end)

    params:add_option("lfo_mode_"..i, "update mode", {"clocked bars","free"},1)
    params:set_action("lfo_mode_"..i,
      function(x)
        if x == 1 and params:string("lfo_"..i) == "on" then
          params:hide("lfo_free_"..i)
          params:show("lfo_beats_"..i)
          klfo[i]:set('mode', 'clocked')
        elseif x == 2 then
          params:hide("lfo_beats_"..i)
          params:show("lfo_free_"..i)
          klfo[i]:set('mode', 'free')
        end
        menu_rebuild_queued = true
      end
    )

    local baseline_options = {"from min", "from center", "from max", 'from current'}
    params:add_option("lfo_baseline_"..i, "lfo baseline", baseline_options, 1)
    params:set_action("lfo_baseline_"..i, function(x)
      if x ~= 4 then
        lfos.current_baseline[i] = false
        klfo[i]:set('baseline',string.gsub(params:lookup_param("lfo_baseline_"..i).formatter(x),"from ",""))
      else
        lfos.current_baseline[i] = true
        klfo[i]:set('baseline','min')
      end
    end)

    params:add_trigger("lfo_reset_"..i, "reset lfo")
    params:set_action("lfo_reset_"..i, function() klfo[i]:reset_phase() end)

    params:add_option("lfo_reset_target_"..i, "reset lfo to", {"floor","ceiling"}, 1)
    params:set_action("lfo_reset_target_"..i, function(x)
      klfo[i]:set('reset_target', params:lookup_param("lfo_reset_target_"..i).formatter(x))
    end)

    menu_rebuild_queued = true

  end

end

function lfos.reset_bounds_in_menu(i)
  local target_track =  _ps.lfos[i].lfoTargetTrack_string
  local target_param = _ps.lfos[i].lfo_target_param
  local restore_min = lfos.specs[target_track][target_param].min
  local restore_max
  restore_max = params:get(target_track.."_midi_"..lfos.params_list[target_track].ids[(target_param)])
  if restore_min == restore_max then
    restore_max = lfos.specs[target_track][target_param].max
  end
  if _ps.lfos[i].lfo_target_param_string == "pan" then
    restore_max = 1
  end
  params:set("lfo_min_"..i, restore_min)
  params:set("lfo_max_"..i, restore_max)
end

function lfos.change_target(i,x)
  local new_target = x
  local target_param_id = params.lookup["lfo_target_param_"..i] -- just looks up the ID for this parameter bucket
  local target_params_selector = params.params[target_param_id] -- the parameter bucket
  local track_id = lfos.targets[_ps.lfos[i].lfoTargetTrack]
  target_params_selector.options = lfos.params_list[track_id].names -- rebuild parameter names
  target_params_selector.count = tab.count(target_params_selector.options) -- count the names
  -- print(params:get("lfo_target_param_"..i))
  lfos.rebuild_param("min",i)
  lfos.rebuild_param("max",i)
  if params:string('lfo_'..i) ~= 'off' then
    print('lfo change target callback',i)
    print(i,lfos.last_param[i],x)
    lfos.return_to_baseline(i,nil,true) -- i kinda want this to be the *previous* param OR the current, depending on situation.
  end
  params:set("lfo_target_param_"..i,1)
  params:set("lfo_depth_"..i,0)
  lfos.reset_bounds_in_menu(i)
end

function lfos.return_to_baseline(i,silent,poly)
  if not readingPSET then
    local drum_target = params:get("lfoTargetTrack_"..i)
    local parent = lfos.targets[drum_target]
    local current_param_name = parent.."_"..(lfos.params_list[parent].ids[(_ps.lfos[i].lfo_target_param)])
    local param_exclusions = {'delay','feedback','main'}
    print('returning to baseline',drum_target,parent,current_param_name,lfos.last_track[i],lfos.last_param[i])
    if not tab.contains(param_exclusions, parent) then
      if lfos.last_param[i] == "time" or lfos.last_param[i] == "decay" or lfos.last_param[i] == "lSHz" or lfos.last_param[i] == "sampleMode" then
        lfos.last_param[i] = "amp"
      end
      local focus_voice = params:string('voice_model_'..parent)
      if params.lookup[parent.."_"..focus_voice..'_'..lfos.last_param[i]] ~= nil then
        if lfos.last_param[i] ~= "carHz" then
          send_to_engine('set_voice_param', {parent,lfos.last_param[i],params:get(parent.."_"..focus_voice..'_'..lfos.last_param[i])})
        elseif lfos.last_param[i] == "carHz" then
          -- idk what this is:
          -- engine.set_voice_param(parent,lfos.last_param[i],musicutil.note_num_to_freq(params:get(parent.."_"..focus_voice..'_'..lfos.last_param[i])))
        end
      end
    -- elseif (parent == "delay" or parent == "feedback" or parent == "main") and engine.name == "Kildare" then
    elseif (parent == "delay" or parent == "feedback" or parent == "main") then
      local sources = {delay = lfos.delay_params, feedback = lfos.feedback_params, main = lfos.main_params}
      if not tab.contains(sources[parent],lfos.last_param[i]) then
        lfos.last_param[i] = sources[parent][1]
      end
      if params.lookup[parent.."_"..lfos.last_param[i]] ~= nil then
        if parent == "delay" and lfos.last_param[i] == "time" then
          send_to_engine("set_"..parent.."_param",{lfos.last_param[i],clock.get_beat_sec() * params:get(parent.."_"..lfos.last_param[i])/128})
        elseif parent ~= 'feedback' then
          send_to_engine("set_"..parent.."_param",{lfos.last_param[i],params:get(parent.."_"..lfos.last_param[i])})
        end
      end
    end
    if not silent then
      lfos.last_track[i] = parent
      lfos.last_param[i] = (lfos.params_list[parent].ids[_ps.lfos[i].lfo_target_param])
    end
  end
end

function lfos.rebuild_param(param,i)
  if not readingPSET then
    local param_id = params.lookup["lfo_"..param.."_"..i]
    local target_track =  _ps.lfos[i].lfoTargetTrack_string
    local target_param = _ps.lfos[i].lfo_target_param
    local default_value
    if  _ps.lfos[i].lfoTargetTrack <= kildare_total_tracks then
      -- print(i, target_track, target_param)
      default_value = param == "min" and lfos.specs[target_track][target_param].min
      or params:get(target_track.."_"..params:string('voice_model_'.. _ps.lfos[i].lfoTargetTrack_string)..'_'..lfos.params_list[target_track].ids[(target_param)])
    else
      default_value = param == "min" and lfos.specs[target_track][target_param].min
      or params:get(target_track.."_"..lfos.params_list[target_track].ids[(target_param)])
    end
    if param == "max" then
      if lfos.specs[target_track][target_param].min == default_value then
        default_value = lfos.specs[target_track][target_param].max
      end
    end
    params.params[param_id].controlspec = controlspec.new(
      lfos.specs[target_track][target_param].min,
      lfos.specs[target_track][target_param].max,
      lfos.specs[target_track][target_param].warp,
      lfos.specs[target_track][target_param].step,
      default_value,
      '',
      lfos.specs[target_track][target_param].quantum
    )
    if param == "max" then
      if _ps.lfos[i].lfo_target_param_string == "pan" then
        default_value = 1
      end
      params.params[param_id]:set_raw(params.params[param_id].controlspec:unmap(default_value))
    end
    if lfos.specs[target_track][target_param].formatter ~= nil then
      params.params[param_id].formatter = lfos.specs[target_track][target_param].formatter
    end
    if param == 'min' then
      klfo[i]:set(param,lfos.specs[target_track][target_param][param])
    else
      klfo[i]:set(param,default_value)
    end
  end
end

function lfos.build_params_static(poly)
  for i = 1,#lfos.targets do
    local style = lfos.targets[i]
    lfos.params_list[style] = {ids = {}, names = {}}
    local focus_voice
    if type(style) == 'number' then
      focus_voice = params:string('voice_model_'..style)
    else
      focus_voice = style
    end
    local parent = (style ~= "delay" and style ~= "feedback" and style ~= "main") and kildare_drum_params[focus_voice] or kildare_fx_params[focus_voice]
    local style_id_iter = 1
    local style_name_iter = 1
    for j = 1,#parent do
      if parent[j].type ~= "separator" and parent[j].lfo_exclude == nil then
        lfos.params_list[style].ids[style_id_iter] = parent[j].id
        lfos.params_list[style].names[style_name_iter] = parent[j].name
        style_id_iter = style_id_iter + 1
        style_name_iter = style_name_iter + 1
      end
    end

  end
end

function lfos.set_delay_param(param_target,value)
  if param_target == "time" then
    send_to_engine('set_delay_param', {param_target,clock.get_beat_sec() * value/128})
    -- engine.set_delay_param(param_target,clock.get_beat_sec() * value/128)
  else
    send_to_engine('set_delay_param', {param_target,value})
    -- engine.set_delay_param(param_target,value)
  end
end

function lfos.send_param_value(target_track, target_id, value)
  if target_track ~= "delay" and target_track ~= "feedback" and target_track ~= "main" then
    if target_id == "carHz" then
      value = musicutil.note_num_to_freq(value)
    end
    if string.find(target_track,'sample') and (target_id == 'playbackRateBase' or target_id == 'loop') then
      params:set(target_track..'_'..target_id,util.round(value))
    else
      send_to_engine('set_voice_param', {target_track,target_id,value})
      -- engine.set_voice_param(target_track,target_id,value)
    end
  else
    if target_track == "delay" then
      lfos.set_delay_param(target_id,value)
    elseif target_track ~= 'feedback' then
      -- engine["set_"..target_track.."_param"](target_id,value)
      send_to_engine("set_"..target_track.."_param", {target_id,value})
    elseif target_track == 'feedback' then
      local sub = '_'
      local keys = {}
      for str in string.gmatch(target_id, "([^"..sub.."]+)") do
        table.insert(keys,str)
      end
      local targetKey = keys[1]
      local paramKey = keys[2]
      -- print(targetKey, paramKey)
      local targetLine = string.upper(string.sub(targetKey, 1, 1))
      if paramKey == 'outA' then
        -- engine['set_feedback_param']('aMixer','in'..targetLine, value)
        send_to_engine('set_feedback_param', {'aMixer','in'..targetLine, value})
      elseif paramKey == 'outB' then
        -- engine['set_feedback_param']('bMixer','in'..targetLine, value)
        send_to_engine('set_feedback_param', {'bMixer','in'..targetLine, value})
      elseif paramKey == 'outC' then
        -- engine['set_feedback_param']('cMixer','in'..targetLine, value)
        send_to_engine('set_feedback_param', {'cMixer','in'..targetLine, value})
      end
      -- print('todo! send lfos to feedback matrix', target_id)
      -- engine['set_feedback_param'](targetKey, paramKey, value)
      send_to_engine('set_feedback_param', {targetKey, paramKey, value})
    end
  end
end

function lfos.rebuild_model_spec(k,poly)
  print('rebuilding lfo model spec ', k, poly)
  lfos.specs[k] = {}
  local i = 1

  -- t values:
  -- 0: separator
  -- 1: number
  -- 2: option
  -- 3: control
  -- 4: file
  -- 5: taper
  -- 6: trigger
  -- 7: group
  -- 8: text
  -- 9: binary

  local focus_voice
  if type(k) == 'number' then
    focus_voice = params:string('voice_model_'..k)
  else
    focus_voice = k
  end
  local param_group = (k ~= "delay" and k ~= "feedback" and k ~= "main") and kildare_drum_params or kildare_fx_params
  for key,val in pairs(param_group[focus_voice]) do
    if param_group[focus_voice][key].type ~= "separator" then
      if param_group[focus_voice][key].lfo_exclude == nil then
        local concat_name = type(k) == 'number' and (k.."_"..focus_voice..'_'..param_group[focus_voice][key].id) or (k.."_"..param_group[focus_voice][key].id)
        local system_id = params.lookup[concat_name]
        local quantum_size
        -- print(system_id, concat_name)
        if params.params[system_id].controlspec ~= nil then
          quantum_size = params.params[system_id].controlspec.quantum
        else
          quantum_size = param_group[focus_voice][key].quantum ~= nil and param_group[focus_voice][key].quantum or 0.01
        end
        lfos.specs[k][i] = {
          min = param_group[focus_voice][key].min,
          max = param_group[focus_voice][key].max,
          warp = param_group[focus_voice][key].warp,
          step = 0,
          default = param_group[focus_voice][key].default,
          quantum = quantum_size,
          formatter = param_group[focus_voice][key].formatter
        }
        i = i+1 -- do not increment by the separators' gaps...
      end
    end
  end
end

function lfos.map_last_pressed()
  if #Kildare.last_adjusted_param > 0 then
  elseif #Kildare.last_adjusted_param == 2 then
  end
end

return lfos