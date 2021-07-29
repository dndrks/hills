local parameters = {}

_mx.dests ={"none","none","none"}

function parameters.init()
  table.insert(_mx.instrument_list,1,"none")
  for i = 1,8 do
    params:add_option("hill "..i.." scale","hill "..i.." scale",scale_names,1)
    params:set_action("hill "..i.." scale",
    function(x)
      for j = 1,8 do
        hills[i][j].note_ocean = mu.generate_scale_of_length(params:get("hill "..i.." base note"),x,127)
      end
    end)
    params:add_number("hill "..i.." base note","hill "..i.." base note",0,127,60)
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
    params:add_number("hill "..i.." span","hill "..i.." note degree span",1,127,14)
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

    params:add_option("hill "..i.." Mx voice", "hill "..i.." Mx voice",_mx.instrument_list,1)
    params:set_action("hill "..i.." Mx voice",function(x)
      _mx.dests[i] = _mx.instrument_list[x]
    end)
    params:add{type="number",id="hill "..i.." mx_velocity",name="Mx.velocity",min=0,max=127,default=80}
    params:add{type='control',id="hill "..i.." mx_amp",name="Mx.amp",controlspec=controlspec.new(0,2,'lin',0.01,0.5,'amp',0.01/2)}
    params:add{type="control",id="hill "..i.." mx_pan",name="Mx.pan",controlspec=controlspec.new(-1,1,'lin',0,0)}
    params:add{type='control',id="hill "..i.." mx_attack",name="Mx.attack",controlspec=controlspec.new(0,10,'lin',0,0,'s')}
    params:add{type='control',id="hill "..i.." mx_release",name="Mx.release",controlspec=controlspec.new(0,10,'lin',0,2,'s')}

    params:add_number("hill "..i.." MIDI note channel","hill "..i.." MIDI note channel",1,16,1)
    params:add_number("hill "..i.." MIDI device","hill "..i.." MIDI device",1,16,1)
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