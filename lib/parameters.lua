local parameters = {}

function parameters.init()
  for i = 1,8 do
    params:add_option("hill "..i.." scale","hill "..i.." scale",scale_names,1)
    params:set_action("hill "..i.." scale",
    function(x)
      hills[i].notes = mu.generate_scale_of_length(params:get("hill "..i.." base note"),x,127)
    end)
    params:add_option("hill "..i.." note style","hill "..i.." note style",{"range","fixed"},1)
    params:set_action("hill "..i.." note style",
    function(x)
      hills[i].notes = mu.generate_scale_of_length(params:get("hill "..i.." base note"),params:get("hill "..i.." scale"),127)
    end)
    params:add_number("hill "..i.." base note","hill "..i.." base note",0,127,60)
    params:set_action("hill "..i.." base note",
    function(x)
      hills[i].notes = mu.generate_scale_of_length(x,params:get("hill "..i.." scale"),127)
    end)
    local fixed_midi_notes = {}
    fixed_midi_notes[1] = "none"
    for j = 0,127 do
      fixed_midi_notes[j+2] = j
    end
    params:add_number("hill "..i.." MIDI note channel","hill "..i.." MIDI note channel",1,16,1) -- no longer relevant, cuz 'note style'
    params:add_number("hill "..i.." MIDI device","hill "..i.." MIDI device",1,16,4) -- no longer relevant, cuz 'note style'
    params:add_number("hill "..i.." velocity","hill "..i.." velocity",0,127,60)
    params:add_number("hill "..i.." cc_val","hill "..i.." cc value",0,127,60)
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
      params:add_number("hill ["..i.."]["..j.."] population","hill ["..i.."]["..j.."] population",10,100,50)
      params:set_action("hill ["..i.."]["..j.."] population",
      function(x)
        hills[i][j].population = x/100
      end)
    end
  end
end

return parameters