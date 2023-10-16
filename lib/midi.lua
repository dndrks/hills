local _midi = {}

function _midi.populate_midi_devices()
  local connected_midi_devices = {}
  for i = 1,#midi.vports do
    table.insert(connected_midi_devices,midi.vports[i].name)
  end
  return connected_midi_devices
end

_midi.hills = {}
for i = 1,number_of_hills do
  _midi.hills[i] = {trigger = {}}
end
_midi.iterator = {note = {}, event = {}, velocity_lo = {}, velocity_hi = {}}

function _midi.init()
  function midi.add()
    local all_midi = _midi.populate_midi_devices()
    for j = 1,#all_midi do
      all_midi[j] = j..': '..all_midi[j]
    end
    for i = 1,number_of_hills do
      params:lookup_param('hill_'..i..'_iterator_midi_device').options = all_midi
    end
  end
  
  function midi.remove()
    local all_midi = _midi.populate_midi_devices()
    for j = 1,#all_midi do
      all_midi[j] = j..': '..all_midi[j]
    end
    for i = 1,number_of_hills do
      params:lookup_param('hill_'..i..'_iterator_midi_device').options = all_midi
    end
  end

end

return _midi