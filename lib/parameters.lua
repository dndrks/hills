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

local current_audio_route = 1

local function route_audio(selected_route)
  clock.sleep(0.5)
  if rerouting_audio == true then
    rerouting_audio = false
    if selected_route == 2 then -- audio in + softcut output -> supercollider
      os.execute("jack_connect crone:output_5 SuperCollider:in_1;")  
      os.execute("jack_connect crone:output_6 SuperCollider:in_2;")
      os.execute("jack_connect softcut:output_1 SuperCollider:in_1;")  
      os.execute("jack_connect softcut:output_2 SuperCollider:in_2;")
    elseif selected_route == 1 then --just audio in -> supercollider
      os.execute("jack_disconnect softcut:output_1 SuperCollider:in_1;")  
      os.execute("jack_disconnect softcut:output_2 SuperCollider:in_2;")
      os.execute("jack_connect crone:output_5 SuperCollider:in_1;")  
      os.execute("jack_connect crone:output_6 SuperCollider:in_2;")
    end
  end
end

function parameters.init()
  refresh_params_vports()

  params:add_separator("hills")
  for i = 1,number_of_hills do
    params:add_group(hill_names[i],61)

    params:add_separator("note management "..hill_names[i])
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

    if i <= 7 then
      params:add_separator("Kildare management "..hill_names[i])
      params:add_option("hill "..i.." kildare_notes","send pitches?",{"no","yes"},1)
      params:set_action("hill "..i.." kildare_notes",
        function(x)
          if x == 1 then
            engine.set_voice_param(kildare.drums[i],"carHz", mu.note_num_to_freq(params:get(kildare.drums[i].."_".."carHz")))
          end
        end
      )
    end

    params:add_separator("softcut management "..hill_names[i])
    params:add_option("hill "..i.." softcut output","softcut output?",{"no","yes"},i<= 7 and 1 or 2)
    params:set_action("hill "..i.." softcut output",
      function(x)
        if x == 1 then
          params:hide("hill "..i.." softcut slot")
          params:hide("hill "..i.." softcut probability")
          params:hide("hill "..i.." softcut repitch")
          params:hide("hill "..i.." softcut momentary")
          _menu.rebuild_params()
        elseif x == 2 then
          params:show("hill "..i.." softcut slot")
          params:show("hill "..i.." softcut probability")
          params:show("hill "..i.." softcut repitch")
          params:show("hill "..i.." softcut momentary")
          _menu.rebuild_params()
        end
      end
    )
    params:add_number("hill "..i.." softcut slot", "sample slot",1,3,i<= 7 and 1 or i-7)
    params:add_number("hill "..i.." softcut probability", "playback probability",0,100,100, function(param) return(param:get().."%") end)
    params:add_option("hill "..i.." softcut repitch", "send pitches?",{"no","yes"},1)
    params:add_option("hill "..i.." softcut momentary", "stop when released?", {"no","yes"},1)

    if i > 7 then
      params:add_option("hill "..i.." reset softcut level lfo", "reset level lfo on trig?", {"no","yes"}, 1)
      params:add_option("hill "..i.." reset softcut level lfo style", "reset lfo to", {"floor","ceiling"}, 1)
    end

    params:add_separator("MIDI management "..hill_names[i])
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

    params:add_separator("crow management "..hill_names[i])
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

    params:add_separator("JF management "..hill_names[i])
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

  local base_note_checker = function(sign)
    local current_note = params:get('multi base note')
    if sign == 'multi octave up' then
      if current_note + 12 <= 127 then
        params:set("multi base note", current_note + 12)
      end
    else
      if current_note - 12 >= 0 then
        params:set("multi base note", current_note - 12)
      end
    end
  end

  -- local multi_note_manager = {
  --   {id = 'multi kildare note', name = 'send pitches to kildare', type = 'option', options = {"no","yes"}, default = 1},
  --   {id = 'multi scale', name = 'scale', type = 'option', options = scale_names, default = 1},
  --   {id = 'multi base note', name = 'base note', type = 'number', min = 0, max = 127, default = 60},
  --   {id = 'multi span', name = 'note degree span', type = 'number', min = 1, max = 127, default = 14},
  --   {id = 'multi octave up', name = 'base octave up', type = 'trigger'},
  --   {id = 'multi octave down', name = 'base octave down', type = 'trigger'},
  --   {id = 'multi random offset style', name = 'random offset style', type = 'option', options = {"+ oct","- oct","+/- oct"}, default = 1},
  --   {id = 'multi random offset probability', name = 'random offset probability', type = 'number', min = 0, max = 100, default = 0},
  --   {id = 'multi quant value', name = 'quant value', type = 'option', options = {"1/4", "1/4d", "1/4t", "1/8", "1/8d", "1/8t", "1/16", "1/16d", "1/16t", "1/32", "1/32d", "1/32t"}, default = 7},
  -- }
  -- params:add_group("MULTI",23 + (#multi_note_manager*2))
  -- -- indent for readability:
  --   params:add_separator("note management")

  --   for i = 1,#multi_note_manager do
  --     local prm = multi_note_manager[i]
  --     if prm.type == 'option' then
  --       params:add_option(
  --         prm.id,
  --         prm.name,
  --         prm.options,
  --         prm.default
  --       )
  --     elseif prm.type == 'number' then
  --       params:add_number(
  --         prm.id,
  --         prm.name,
  --         prm.min,
  --         prm.max,
  --         prm.default
  --       )
  --     elseif prm.type == 'trigger' then
  --       params:add_trigger(
  --         prm.id,
  --         prm.name
  --       )
  --       params:set_action(
  --         prm.id, function() base_note_checker(prm.id) end
  --       )
  --     end
  --     params:add_trigger("send "..prm.id,"--> send")
  --     params:set_action("send "..prm.id,
  --       function()
  --         for j = 1,(prm.id == 'multi kildare note' and 7 or #number_of_hills) do
  --           local destination = string.gsub(prm.id,"multi ","")
  --           params:set("hill "..i.." "..destination,params:get(prm.id))
  --         end
  --       end
  --     )
  --     if prm.id == 'multi octave up' or prm.id == 'multi octave down' then
  --       params:hide("send "..prm.id)
  --     end
  --   end

  --   params:add_separator("softcut management")
  --   params:add_option("multi softcut output","softcut output?",{"no","yes"},1)
  --   params:set_action("multi softcut output",
  --     function(x)
  --       if x == 1 then
  --         params:hide("multi softcut slot")
  --         params:hide("multi softcut probability")
  --         _menu.rebuild_params()
  --       elseif x == 2 then
  --         params:show("multi softcut slot")
  --         params:show("multi softcut probability")
  --         _menu.rebuild_params()
  --       end
  --     end
  --   )
  --   params:add_number("multi softcut slot", "sample slot",1,6,1)
  --   params:add_number("multi softcut probability", "playback probability",0,100,100, function(param) return(param:get().."%") end)
  --   params:add_trigger("send multi softcut management","send to multiple (see below)")
  --   params:set_action("send multi softcut management",
  --     function()
  --       for i = 1,number_of_hills do
  --         if params:string("send to "..i) == "yes" then
  --           params:set("hill "..i.." softcut output",params:get("multi softcut output"))
  --           params:set("hill "..i.." softcut slot",params:get("multi softcut slot"))
  --           params:set("hill "..i.." softcut probability",params:get("multi softcut probability"))
  --         end
  --       end
  --     end
  --   )

  --   params:add_separator("MIDI management")
  --   params:add_option("multi MIDI output", "MIDI output?",{"no","yes"},1)
  --   params:set_action("multi MIDI output",
  --     function(x)
  --       if x == 1 then
  --         params:hide("multi MIDI device")
  --         params:hide("multi MIDI note channel")
  --         params:hide("multi MIDI device")
  --         params:hide("multi velocity")
  --         _menu.rebuild_params()
  --       elseif x == 2 then
  --         params:show("multi MIDI device")
  --         params:show("multi MIDI note channel")
  --         params:show("multi MIDI device")
  --         params:show("multi velocity")
  --         _menu.rebuild_params()
  --       end
  --     end
  --   )
  --   params:add_option("multi MIDI device", "device",vports,1)
  --   params:add_number("multi MIDI note channel","note channel",1,16,1)
  --   params:add_number("multi velocity","velocity",0,127,60)
  --   params:add_trigger("send multi MIDI management","send to multiple (see below)")
  --   params:set_action("send multi MIDI management",
  --     function()
  --       for i = 1,number_of_hills do
  --         if params:string("send to "..i) == "yes" then
  --           params:set("hill "..i.." MIDI output",params:get("multi MIDI output"))
  --           params:set("hill "..i.." MIDI device",params:get("multi MIDI device"))
  --           params:set("hill "..i.." MIDI note channel",params:get("multi MIDI note channel"))
  --           params:set("hill "..i.." velocity",params:get("multi velocity"))
  --         end
  --       end
  --     end
  --   )
  --   params:add_separator("send to...")
  --   for i = 1,number_of_hills do
  --     params:add_option("send to "..i,hill_names[i],{"no","yes"},2)
  --   end
  -- -- / MULTI group

  params:add_group("SAMPLES",(3 * 17) + 17)
  params:add{
    type = "option", id = "sample_routing", name = "audio routing", 
    options = {"-x kildare","-> kildare"},
    default = 1,
    action = function(value)
      if current_audio_route ~= value then
        print("rerouting audio, don't worry about the 'cannot allocate memory' messages!")
        rerouting_audio = true
        clock.run(route_audio,value)
      end
      if value == 1 then
        params:hide('sample_fx')
        params:hide('sample_to_delay')
        params:hide('sample_to_reverb')
        params:hide('sample_squishPitch')
        params:hide('sample_squishChunk')
        params:hide('sample_amDepth')
        params:hide('sample_amHz')
        params:hide('sample_eqHz')
        params:hide('sample_eqAmp')
        params:hide('sample_bitRate')
        params:hide('sample_bitCount')
        params:hide('sample_lpHz')
        params:hide('sample_hpHz')
        params:hide('sample_filterQ')
        _menu.rebuild_params()
      else
        params:show('sample_fx')
        params:show('sample_to_delay')
        params:show('sample_to_reverb')
        params:show('sample_squishPitch')
        params:show('sample_squishChunk')
        params:show('sample_amDepth')
        params:show('sample_amHz')
        params:show('sample_eqHz')
        params:show('sample_eqAmp')
        params:show('sample_bitRate')
        params:show('sample_bitCount')
        params:show('sample_lpHz')
        params:show('sample_hpHz')
        params:show('sample_filterQ')
        _menu.rebuild_params()
      end
    end
    }
  params:add_separator('sample_fx', 'global sample fx')
  params:add_control("sample_to_delay","delay send level",controlspec.new(0,5,'lin',0,1,''), function(param) return (round_form(param:get()*100,1,"%")) end)
  params:set_action("sample_to_delay", function(x)
    engine.set_softcut_param('delaySend',x)
  end)
  params:add_control("sample_to_reverb","reverb send level",controlspec.new(0,5,'lin',0,1,''), function(param) return (round_form(param:get()*100,1,"%")) end)
  params:set_action("sample_to_reverb", function(x)
    engine.set_softcut_param('reverbSend',x)
  end)

  params:add_control("sample_squishPitch","squish pitch",controlspec.new(1,10,'lin',0,1,'',1/9),function(param) return (round_form(param:get(),1,'')) end)
  params:set_action("sample_squishPitch", function(x)
    engine.set_softcut_param('squishPitch',x)
  end)
  params:add_control("sample_squishChunk","squish chunkiness",controlspec.new(1,10,'lin',0,1,'',1/9),function(param) return (round_form(param:get(),1,'')) end)
  params:set_action("sample_squishChunk", function(x)
    engine.set_softcut_param('squishChunk',x)
  end)

  params:add_control("sample_amDepth","amp mod depth",controlspec.new(0,1,'lin',0,0,''),function(param) return (round_form(param:get()*100,1,"%")) end)
  params:set_action("sample_amDepth", function(x)
    engine.set_softcut_param('amDepth',x)
  end)
  params:add_control("sample_amHz","amp mod freq",controlspec.new(0.001,12000,'exp',0,8175.08,''),function(param) return (round_form(param:get(),0.01," Hz")) end)
  params:set_action("sample_amHz", function(x)
    engine.set_softcut_param('amHz',x)
  end)

  params:add_control("sample_eqHz","eq freq",controlspec.new(20,20000,'exp',0,6000,''),function(param) return (round_form(param:get(),0.01," Hz")) end)
  params:set_action("sample_eqHz", function(x)
    engine.set_softcut_param('eqHz',x)
  end)
  params:add_control("sample_eqAmp","eq gain",controlspec.new(-2,2,'lin',0,0,''),function(param) return (round_form(param:get()*100,1,"%")) end)
  params:set_action("sample_eqAmp", function(x)
    engine.set_softcut_param('eqAmp',x)
  end)

  params:add_control("sample_bitRate","bit rate",controlspec.new(20,24000,'exp',0,24000,''),function(param) return (util.round(param:get(),0.1).." Hz") end)
  params:set_action("sample_bitRate", function(x)
    engine.set_softcut_param('bitRate',x)
  end)
  params:add_control("sample_bitCount","bit depth",controlspec.new(1,24,'lin',0,24,'',1/23),function(param) return (round_form(param:get(),1," bit")) end)
  params:set_action("sample_bitCount", function(x)
    engine.set_softcut_param('bitCount',x)
  end)
  
  params:add_control("sample_lpHz","lo-pass freq",controlspec.new(20,20000,'exp',0,20000),function(param) return (round_form(param:get(),0.01," Hz")) end)
  params:set_action("sample_lpHz", function(x)
    engine.set_softcut_param('lpHz',x)
  end)
  params:add_control("sample_hpHz","hi-pass freq",controlspec.new(20,24000,'exp',0,20,''),function(param) return (util.round(param:get(),0.1).." Hz") end)
  params:set_action("sample_hpHz", function(x)
    engine.set_softcut_param('hpHz',x)
  end)
  params:add_control("sample_filterQ","filter q",controlspec.new(0,100,'lin',0,50,''),function(param) return (util.round(param:get()).."%") end)
  params:set_action("sample_filterQ", function(x)
    engine.set_softcut_param('filterQ',x)
  end)

  for i = 1,3 do
    params:add_separator("s"..i)
    params:add_option("clip "..i.." sample mode", "mode", {"single (chop)", "single (playthrough)", "folder (distribute)"},1)
    params:set_action("clip "..i.." sample mode",
      function(x)
        if x == 1 then
          params:show("clip "..i.." sample")
          params:hide("clip "..i.." sample folder")
          params:hide("clip "..i.." playthrough sample")
        elseif x == 2 then
          params:show("clip "..i.." playthrough sample")
          params:hide("clip "..i.." sample")
          params:hide("clip "..i.." sample folder")
        elseif x == 3 then
          params:show("clip "..i.." sample folder")
          params:hide("clip "..i.." sample")
          params:hide("clip "..i.." playthrough sample")
        end
        _menu.rebuild_params()
      end
    )
    params:add_file("clip "..i.." sample", "load", _path.audio)
    params:set_action("clip "..i.." sample",
      function(file)
        if file ~= _path.audio and file ~= "playthrough" and file ~= "distributed" then
          _ca.load_sample(file,i)
          print(i.."1")
          parameters.toggle_softcut_params("show", i)
        else
          parameters.toggle_softcut_params("hide", i)
        end
      end
    )
    params:add_file("clip "..i.." sample folder", "load", _path.audio)
    params:set_action("clip "..i.." sample folder",
      function(file)
        if file ~= _path.audio then
          _ca.folder_callback(file,i)
          print(i.."2")
          parameters.toggle_softcut_params("show", i)
        else
          parameters.toggle_softcut_params("hide", i)
        end
      end
    )

    params:add_file("clip "..i.." playthrough sample", "load", _path.audio)
    params:set_action("clip "..i.." playthrough sample",
      function(file)
        if file ~= _path.audio then
          params:set("clip "..i.." sample", "playthrough", 1)
          _ca.load_sample(file,i)
          print(i.."3")
          parameters.toggle_softcut_params("show", i)
        else
          parameters.toggle_softcut_params("hide", i)
        end
      end
    )
    
    params:add_option("speed_clip_"..i,"speed (all slices)", sample_speedlist[1])
    params:set("speed_clip_"..i, 9)
    params:set_action("speed_clip_"..i,
      function(x)
        -- softcut.rate(i, speedlist[i][params:get("speed_clip_"..i)]*offset[i])
        softcut.rate(i, _ca.get_total_pitch_offset(i))
        for j = 1,8 do
          for k = 1,#hills[i+7][j].softcut_controls.rate do
            hills[i+7][j].softcut_controls.rate[k] = x
          end
        end
        if x < 6 then
          if not sample_track[i].reverse then sample_track[i].reverse = true end
        elseif x > 6 then
          if sample_track[i].reverse then sample_track[i].reverse = false end
        end
      end
    )
    params:add_number("semitone_offset_"..i, "offset", -24,24,0, function(param) return (param:get().." st") end)
    params:set_action("semitone_offset_"..i,
      function(value)
        sample_offset[i] = math.pow(0.5, -value / 12)
        softcut.rate(i, _ca.get_total_pitch_offset(i))
      end
    )
    params:add_number(
      "playhead_distance_L_"..i,
      "playhead distance (L)",
      -100,
      100,
      0,
      function(param) return ((param:get()*10).."ms") end
    )
    params:add_number(
      "playhead_distance_R_"..i,
      "playhead distance (R)",
      -100,
      100,
      0,
      function(param) return ((param:get()*10).."ms") end
    )
    params:set_action("playhead_distance_L_"..i,
      function()
        if params:get("clip "..i.." sample") == "playthrough" then
          _ca.set_loop_start(i,softcut_offsets[i])
        end
      end
    )
    params:set_action("playhead_distance_R_"..i,
      function()
        if params:get("clip "..i.." sample") == "playthrough" then
          _ca.set_loop_start(i,softcut_offsets[i])
        end
      end
    )
    params:add_control("vol_clip_"..i,"level",controlspec.new(0,5,'lin',0,1,''))
    params:set_action("vol_clip_"..i, function(x)
      _ca.set_level(i, x)
    end)
    
    params:add_control("pan_clip_"..i,"pan",controlspec.new(-1,1,'lin',0.01,0,''),frm.bipolar_as_pan_widget)
    params:set_action("pan_clip_"..i, function(x)
      _ca.set_pan(i, x)
    end)

    params:add_control("post_filter_fc_"..i,"filter cutoff",controlspec.new(20,12000,'exp',0.01,12000,''))
    params:set_action("post_filter_fc_"..i, function(x) _ca.set_filter("post_filter_fc",i,x) end)
    params:add_control("post_filter_lp_"..i,"lopass",controlspec.new(0,1,'lin',0.01,0,''))
    params:set_action("post_filter_lp_"..i, function(x) _ca.set_filter("post_filter_lp",i,x) end)
    params:add_control("post_filter_hp_"..i,"hipass",controlspec.new(0,1,'lin',0.01,0,''))
    params:set_action("post_filter_hp_"..i, function(x) _ca.set_filter("post_filter_hp",i,x) end)
    params:add_control("post_filter_bp_"..i,"bandpass",controlspec.new(0,1,'lin',0.01,0,''))
    params:set_action("post_filter_bp_"..i, function(x) _ca.set_filter("post_filter_bp",i,x) end)
    params:add_control("post_filter_dry_"..i,"dry",controlspec.new(0,1,'lin',0.01,1,''))
    params:set_action("post_filter_dry_"..i, function(x) _ca.set_filter("post_filter_dry",i,x) end)
    params:add_number("post_filter_rq_"..i,"filter q",0,100,50,function(param) return (util.round(param:get(),0.01).."%") end)
    params:set_action("post_filter_rq_"..i, function(x) _ca.set_filter("post_filter_rq",i,util.linlin(0,100,2.0,0.001,x)) end)

  end
  params:add_separator("global")
  params:add_control("pitch_control","pitch control",controlspec.new(-12,12,'lin',0,0,'%'))
  params:set_action("pitch_control",function(x)
    for i = 1,3 do
      softcut.rate(i,_ca.get_total_pitch_offset(i))
    end
  end)

  vol_lfos = {}
  params:add_group('level_lfos','SAMPLE LEVEL LFOs',45)
  for i = 1,3 do
    vol_lfos[i] = sc_lfos:add{min = 0, max = 5, action = function(s,r) params:lookup_param('vol_clip_'..i).action(s) end}
    vol_lfos[i]:add_params('lfo_vol_clip_'..i, "["..i.."]")
  end

  -- sc_lfos.add_params("vol_clip_")
  -- sc_lfos.add_params("pan_clip_")
  -- sc_lfos.add_params("post_filter_fc_")

  _menu.rebuild_params()
  clock.run(function() clock.sleep(1) params:bang() end)
end

function parameters.toggle_softcut_params(state, i)
  params[state](params, "speed_clip_"..i)
  params[state](params, "semitone_offset_"..i)
  params[state](params, "playhead_distance_L_"..i)
  params[state](params, "playhead_distance_R_"..i)
  params[state](params, "vol_clip_"..i)
  params[state](params, "pan_clip_"..i)
  params[state](params, "post_filter_fc_"..i)
  params[state](params, "post_filter_lp_"..i)
  params[state](params, "post_filter_hp_"..i)
  params[state](params, "post_filter_bp_"..i)
  params[state](params, "post_filter_dry_"..i)
  params[state](params, "post_filter_rq_"..i)
  _menu.rebuild_params()
  print("happening",i,state)
end

return parameters