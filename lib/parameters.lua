local parameters = {}

_mx.dests ={"none","none","none"}

local vports = {}

local function refresh_params_vports()
  for i = 1,#midi.vports do
    vports[i] = midi.vports[i].name ~= "none" and util.trim_string_to_width(midi.vports[i].name,70) or tostring(i)..": [device]"
  end
end

local hill_names = {"A","B","C","D","E","F","G","H"}

function parameters.init()
  table.insert(_mx.instrument_list,1,"none")
  refresh_params_vports()

  params:add_separator("hills")
  params:add_option("global engine","global engine",engine_options,1)
  params:add_trigger("reload engine","reload engine")
  params:set_action("reload engine",
    function()
      parameters.reload_engine(params:get("global engine"))
    end
  )
  for i = 1,8 do
    params:add_group(hill_names[i],76)

    params:add_separator("note management ["..hill_names[i].."]")
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

    params:add_separator("PolyPerc management ["..hill_names[i].."]")
    params:add_text("hill "..i.." pp_state","not selected, no params")
    params:hide("hill "..i.." pp_state")
    params:add{type="control",id="hill "..i.." pp_amp",name="amp",controlspec=controlspec.new(0,1,'lin',0,0.25,'')}
    params:add{type="control",id="hill "..i.." pp_pw",name="pw",controlspec=controlspec.new(0,100,'lin',0,50,'%')}
    params:add{type="control",id="hill "..i.." pp_release",name="release",controlspec=controlspec.new(0.1,3.2,'lin',0,1.2,'s')}
    params:add{type="control",id="hill "..i.." pp_cut",name="cutoff",controlspec=controlspec.new(50,12000,'exp',0,800,'hz')}

    params:add_separator("MxSamples management ["..hill_names[i].."]")
    params:add_text("hill "..i.." mx_state","not selected, no params")
    params:add_option("hill "..i.." mx_voice", "mx.voice",_mx.instrument_list,1)
    params:set_action("hill "..i.." mx_voice",function(x)
      _mx.dests[i] = _mx.instrument_list[x]
    end)
    params:add{type="number",id="hill "..i.." mx_velocity",name="mx.velocity",min=0,max=127,default=80}
    params:add{type='control',id="hill "..i.." mx_amp",name="mx.amp",controlspec=controlspec.new(0,2,'lin',0.01,0.5,'amp',0.01/2)}
    params:add{type="control",id="hill "..i.." mx_pan",name="mx.pan",controlspec=controlspec.new(-1,1,'lin',0,0)}
    params:add{type='control',id="hill "..i.." mx_attack",name="mx.attack",controlspec=controlspec.new(0,10,'lin',0,0,'s')}
    params:add{type='control',id="hill "..i.." mx_release",name="mx.release",controlspec=controlspec.new(0,10,'lin',0,2,'s')}
    params:hide("hill "..i.." mx_voice")
    params:hide("hill "..i.." mx_velocity")
    params:hide("hill "..i.." mx_amp")
    params:hide("hill "..i.." mx_pan")
    params:hide("hill "..i.." mx_attack")
    params:hide("hill "..i.." mx_release")

    params:add_separator("Thebangs management ["..hill_names[i].."]")
    params:add_text("hill "..i.." thebangs_state","not selected, no params")
    params:add{type="option",id="hill "..i.." thebangs_algo",name="algo",options={"square", "square_mod1", "square_mod2","sinfmlp", "sinfb","reznoise"},1}
    params:set_action("hill "..i.." thebangs_algo",
      function(x)
        if engine.name == "Thebangs" then
          engine.algoIndex(x)
        end
      end
    )
    params:add{type="control",id="hill "..i.." thebangs_pw",name="pw",controlspec=controlspec.new(0,100,'lin',0,50,'%')}
    params:set_action("hill "..i.." thebangs_pw",
      function(x)
        if engine.name == "Thebangs" then
          engine.pw(x/100)
        end
      end
    )
    params:add{type="control",id="hill "..i.." thebangs_attack",name="attack",controlspec=controlspec.new(0.0001, 1, 'exp', 0, 0.01, '')}
    params:set_action("hill "..i.." thebangs_attack",
      function(x)
        if engine.name == "Thebangs" then
          engine.attack(x)
        end
      end
    )
    params:add{type="control",id="hill "..i.." thebangs_release",name="release",controlspec=controlspec.new(0.1,3.2,'lin',0,1.2,'s')}
    params:set_action("hill "..i.." thebangs_release",
      function(x)
        if engine.name == "Thebangs" then
          engine.release(x)
        end
      end
    )
    params:add{type="control",id="hill "..i.." thebangs_cut",name="cutoff",controlspec=controlspec.new(50,19000,'exp',0,12000,'hz')}
    params:set_action("hill "..i.." thebangs_cut",
      function(x)
        if engine.name == "Thebangs" then
          engine.cutoff(x)
        end
      end
    )
    params:add{type="control",id="hill "..i.." thebangs_amp",name="amp",controlspec=controlspec.new(0,1,'lin',0,0.25,'')}
    params:set_action("hill "..i.." thebangs_amp",
      function(x)
        if engine.name == "Thebangs" then
          engine.amp(x)
        end
      end
    )
    params:add{type="control",id="hill "..i.." thebangs_pan",name="pan",controlspec=controlspec.new(-1,1,'lin',0,0,'')}
    params:set_action("hill "..i.." thebangs_pan",
      function(x)
        if engine.name == "Thebangs" then
          engine.pan(x)
        end
      end
    )
    params:hide("hill "..i.." thebangs_algo")
    params:hide("hill "..i.." thebangs_pw")
    params:hide("hill "..i.." thebangs_attack")
    params:hide("hill "..i.." thebangs_release")
    params:hide("hill "..i.." thebangs_cut")
    params:hide("hill "..i.." thebangs_amp")
    params:hide("hill "..i.." thebangs_pan")

    params:add_separator("MIDI management ["..hill_names[i].."]")
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

    params:add_separator("crow management ["..hill_names[i].."]")
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

    params:add_separator("JF management ["..hill_names[i].."]")
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
  params:add_group("MULTI",25)
  params:add_separator("note management")
  params:add_option("multi scale","scale",scale_names,1)
  params:add_number("multi base note","base note",0,127,60)
  params:add_number("multi span","note degree span",1,127,14)
  params:add_trigger("multi octave up","base octave up")
  params:set_action("multi octave up",
    function()
      local current_note = params:get("multi base note")
      if current_note + 12 <= 127 then
        params:set("multi base note", current_note + 12)
      end
    end
  )
  params:add_trigger("multi octave down","base octave down")
  params:set_action("multi octave down",
    function()
      local current_note = params:get("multi base note")
      if current_note - 12 >= 0 then
        params:set("multi base note", current_note - 12)
      end
    end
  )
  params:add_option("multi random offset style", "random offset style", {"+ oct","- oct","+/- oct"},1)
  params:add_number("multi random offset probability","random offset probability",0,100,0)
  params:add_option("multi quant value","quant value",{"1/4", "1/4d", "1/4t", "1/8", "1/8d", "1/8t", "1/16", "1/16d", "1/16t", "1/32", "1/32d", "1/32t"},7)
  params:add_trigger("send multi note management","send to multiple (see below)")
  params:set_action("send multi note management",
    function()
      for i = 1,8 do
        if params:string("send to "..i) == "yes" then
          params:set("hill "..i.." scale",params:get("multi scale"))
          params:set("hill "..i.." base note",params:get("multi base note"))
          params:set("hill "..i.." span",params:get("multi span"))
          params:set("hill "..i.." random offset style",params:get("multi random offset style"))
          params:set("hill "..i.." random offset probability",params:get("multi random offset probability"))
          params:set("hill "..i.." quant value",params:get("multi quant value"))
        end
      end
    end
  )
  params:add_separator("MIDI management")
  params:add_option("multi MIDI output", "MIDI output?",{"no","yes"},1)
  params:set_action("multi MIDI output",
    function(x)
      if x == 1 then
        params:hide("multi MIDI device")
        params:hide("multi MIDI note channel")
        params:hide("multi MIDI device")
        params:hide("multi velocity")
        _menu.rebuild_params()
      elseif x == 2 then
        params:show("multi MIDI device")
        params:show("multi MIDI note channel")
        params:show("multi MIDI device")
        params:show("multi velocity")
        _menu.rebuild_params()
      end
    end
  )
  params:add_option("multi MIDI device", "device",vports,1)
  params:add_number("multi MIDI note channel","note channel",1,16,1)
  params:add_number("multi velocity","velocity",0,127,60)
  params:add_trigger("send multi MIDI management","send to multiple (see below)")
  params:set_action("send multi MIDI management",
    function()
      for i = 1,8 do
        if params:string("send to "..i) == "yes" then
          params:set("hill "..i.." MIDI output",params:get("multi MIDI output"))
          params:set("hill "..i.." MIDI device",params:get("multi MIDI device"))
          params:set("hill "..i.." MIDI note channel",params:get("multi MIDI note channel"))
          params:set("hill "..i.." velocity",params:get("multi velocity"))
        end
      end
    end
  )
  params:add_separator("send to...")
  for i = 1,8 do
    params:add_option("send to "..i,hill_names[i],{"no","yes"},1)
  end
  _menu.rebuild_params()
  clock.run(function() clock.sleep(1) params:bang() end)
end

function parameters.reload_engine(id,silent)
  if id ~= 1 then
    for i = 1,8 do
      params:hide("hill "..i.." pp_amp")
      params:hide("hill "..i.." pp_pw")
      params:hide("hill "..i.." pp_release")
      params:hide("hill "..i.." pp_cut")
      params:show("hill "..i.." pp_state")
    end
  end
  if id == 1 then
    for i = 1,8 do
      params:show("hill "..i.." pp_amp")
      params:show("hill "..i.." pp_pw")
      params:show("hill "..i.." pp_release")
      params:show("hill "..i.." pp_cut")
      params:hide("hill "..i.." pp_state")
    end
  end
  if id ~= 2 then
    for i = 1,8 do
      params:hide("hill "..i.." mx_voice")
      params:hide("hill "..i.." mx_velocity")
      params:hide("hill "..i.." mx_amp")
      params:hide("hill "..i.." mx_pan")
      params:hide("hill "..i.." mx_attack")
      params:hide("hill "..i.." mx_release")
      params:show("hill "..i.." mx_state")
    end
  end
  if id == 2 then
    for i = 1,8 do
      params:show("hill "..i.." mx_voice")
      params:show("hill "..i.." mx_velocity")
      params:show("hill "..i.." mx_amp")
      params:show("hill "..i.." mx_pan")
      params:show("hill "..i.." mx_attack")
      params:show("hill "..i.." mx_release")
      params:hide("hill "..i.." mx_state")
    end
  end
  if id ~= 3 then
    for i = 1,8 do
      params:hide("hill "..i.." thebangs_algo")
      params:hide("hill "..i.." thebangs_pw")
      params:hide("hill "..i.." thebangs_attack")
      params:hide("hill "..i.." thebangs_release")
      params:hide("hill "..i.." thebangs_cut")
      params:hide("hill "..i.." thebangs_amp")
      params:hide("hill "..i.." thebangs_pan")
      params:show("hill "..i.." thebangs_state")
    end
  end
  if id == 3 then
    for i = 1,8 do
      params:show("hill "..i.." thebangs_algo")
      params:show("hill "..i.." thebangs_pw")
      params:show("hill "..i.." thebangs_attack")
      params:show("hill "..i.." thebangs_release")
      params:show("hill "..i.." thebangs_cut")
      params:show("hill "..i.." thebangs_amp")
      params:show("hill "..i.." thebangs_pan")
      params:hide("hill "..i.." thebangs_state")
    end
  end
  if not silent then
    local was_playing = {0,0,0,0,0,0,0,0}
    clock.run(
      function()
        for i = 1,8 do
          if hills[i].active then
            stop(i,true)
            was_playing[i] = hills[i].segment
          end
        end
        clock.sleep(0.25)
        engine.load(params:string("global engine"))
        clock.sleep(1)
        for i = 1,8 do
          if was_playing[i]~= 0 then
            _a.start(i,was_playing[i],true)
          end
        end
      end
    )
  end
end

return parameters