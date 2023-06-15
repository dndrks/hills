local geodesy = {}

local UI = require('ui')

geodesy.focus_voice = 1
geodesy.focus_group = 1
geodesy.focus_param = 1

geodesy.separators = {}

function geodesy.init()
  -- need to do this for each drum in each voice...
  geodesy.separators[1] = {}
  geodesy.separators[1].bd = {}
  for i = 1,#kildare_drum_params.bd do
    if kildare_drum_params.bd[i].type == 'separator' then
      geodesy.separators[1].bd[1+#geodesy.separators[1].bd] = params.lookup['1_separator_bd_'..kildare_drum_params.bd[i].name]
    end
  end
end

return geodesy