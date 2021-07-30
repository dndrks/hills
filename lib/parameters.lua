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
    params:add_group(hill_names[i],33)

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
      end
    end)

    params:add_separator("PolyPerc management ["..hill_names[i].."]")
    params:add_text("hill "..i.." pp_state","not selected, no params")
    params:hide("hill "..i.." pp_state")
    params:add{type="control",id="hill "..i.." pp_amp",name="amp",controlspec=controlspec.new(0,1,'lin',0,0.25,'')}
    params:add{type="control",id="hill "..i.." pp_pw",name="pw",controlspec=controlspec.new(0,100,'lin',0,50,'%')}
    params:add{type="control",id="hill "..i.." pp_release",name="release",controlspec=controlspec.new(0.1,3.2,'lin',0,1.2,'s')}
    params:add{type="control",id="hill "..i.." pp_cut",name="cutoff",controlspec=controlspec.new(50,5000,'exp',0,800,'hz')}

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
          for j = 1,5 do
            params:show("hill "..i.." cc_"..j)
            params:show("hill "..i.." cc_"..j.."_ch")
          end
          _menu.rebuild_params()
        end
      end
    )
    params:add_option("hill "..i.." MIDI device", "MIDI output device",vports,1)
    params:add_number("hill "..i.." MIDI note channel","MIDI note channel",1,16,1)
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
  end
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
  if not silent then
    engine.load(params:string("global engine"))
  end
end

return parameters