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

function parameters.init()
  refresh_params_vports()

  params:add_separator("hills")
  for i = 1,number_of_hills do
    params:add_group(hill_names[i], i > 7 and 59 or 61)

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

    params:add_separator("sample management "..hill_names[i])
    params:add_option("hill "..i.." sample output","sample output?",{"no","yes"},i<= 7 and 1 or 2)
    params:set_action("hill "..i.." sample output",
      function(x)
        if x == 1 then
          params:hide("hill "..i.." sample slot")
          params:hide("hill "..i.." sample probability")
          params:hide("hill "..i.." sample repitch")
          params:hide("hill "..i.." sample momentary")
          _menu.rebuild_params()
        elseif x == 2 then
          params:show("hill "..i.." sample slot")
          params:show("hill "..i.." sample probability")
          params:show("hill "..i.." sample repitch")
          params:show("hill "..i.." sample momentary")
          _menu.rebuild_params()
        end
      end
    )
    params:add_number("hill "..i.." sample slot", "sample slot",1,3,i<= 7 and 1 or i-7)
    params:add_number("hill "..i.." sample probability", "playback probability",0,100,100, function(param) return(param:get().."%") end)
    params:add_option("hill "..i.." sample repitch", "send pitches?",{"no","yes"},1)
    params:add_option("hill "..i.." sample momentary", "stop when released?", {"no","yes"},1)

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

  --   params:add_separator("sample management")
  --   params:add_option("multi sample output","sample output?",{"no","yes"},1)
  --   params:set_action("multi sample output",
  --     function(x)
  --       if x == 1 then
  --         params:hide("multi sample slot")
  --         params:hide("multi sample probability")
  --         _menu.rebuild_params()
  --       elseif x == 2 then
  --         params:show("multi sample slot")
  --         params:show("multi sample probability")
  --         _menu.rebuild_params()
  --       end
  --     end
  --   )
  --   params:add_number("multi sample slot", "sample slot",1,6,1)
  --   params:add_number("multi sample probability", "playback probability",0,100,100, function(param) return(param:get().."%") end)
  --   params:add_trigger("send multi sample management","send to multiple (see below)")
  --   params:set_action("send multi sample management",
  --     function()
  --       for i = 1,number_of_hills do
  --         if params:string("send to "..i) == "yes" then
  --           params:set("hill "..i.." sample output",params:get("multi sample output"))
  --           params:set("hill "..i.." sample slot",params:get("multi sample slot"))
  --           params:set("hill "..i.." sample probability",params:get("multi sample probability"))
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

  _menu.rebuild_params()
  clock.run(function() clock.sleep(1) params:bang() end)
end

return parameters