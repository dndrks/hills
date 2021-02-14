local parameters = {}

function parameters.init()
  for i = 1,2 do
    params:add_option("hill "..i.." scale","hill "..i.." scale",scale_names,1)
    params:set_action("hill "..i.." scale",
    function(x)
      hills[i].notes = mu.generate_scale(60,x,2)
    end)
    params:add_number("hill "..i.." base note","hill "..i.." base note",0,127,60)
    params:set_action("hill "..i.." base note",
    function(x)
      hills[i].notes = mu.generate_scale(x,params:get("hill "..i.." scale"),2)
    end)
  end
end

return parameters