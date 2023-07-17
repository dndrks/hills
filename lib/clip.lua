local ca = {}

function ca.init()
  sample_speedlist = {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4}

  sample_info = {}

  sample_loop_info = {}
  for i = 1,number_of_hills do
    sample_loop_info[i] = {clocks = {}, count = 0}
  end

  function kildare.folder_callback(voice,folder)
    sample_info[voice] = {}
    sample_info[voice].sample_rates = {}
    sample_info[voice].sample_lengths = {}
    sample_info[voice].sample_frames = {}
    sample_info[voice].sample_count = 0
    local wavs = util.scandir(folder)
    for index, data in ipairs(wavs) do
      local ch, len, rate = audio.file_info(folder..data)
      if rate ~= 0 then
        sample_info[voice].sample_count = sample_info[voice].sample_count + 1
        sample_info[voice].sample_rates[sample_info[voice].sample_count] = rate
        sample_info[voice].sample_lengths[sample_info[voice].sample_count] = len/rate
        sample_info[voice].sample_frames[sample_info[voice].sample_count] = len
      end
    end
    local num = string.gsub(voice,'sample','')
    for i = 1,number_of_hills do
      if params:get('hill '..i..' sample slot') == tonumber(num) and params:string('hill '..i..' sample output') == 'yes' then
        params:show('hill '..i..' sample distribution')
        params:hide('hill '..i..' sample slice count')
        menu_rebuild_queued = true
        -- _menu.rebuild_params()
      end
    end
  end

  function kildare.file_callback(voice,file)
    sample_info[voice] = {}
    sample_info[voice].sample_rates = {}
    sample_info[voice].sample_lengths = {}
    sample_info[voice].sample_frames = {}
    sample_info[voice].sample_count = 0
    local ch, len, rate = audio.file_info(file)
    if rate ~= 0 and len ~= 0 then
      sample_info[voice].sample_rates[1] = rate
      sample_info[voice].sample_lengths[1] = len/rate
      sample_info[voice].sample_frames[1] = len
      for i = 1,number_of_hills do
        if params:get('hill '..i..' sample slot') == voice and params:string('hill '..i..' sample output') == 'yes' then
          params:hide('hill '..i..' sample distribution')
          if params:string(voice..'_sample_sampleMode') == 'chop' then
            params:show('hill '..i..' sample slice count')
          else
            params:hide('hill '..i..' sample slice count')
          end
          menu_rebuild_queued = true
          -- _menu.rebuild_params()
        end
      end
    end
  end

  function kildare.clear_callback(voice)
    print(voice ..' getting a sample cleared')
    sample_info[voice] = {}
    sample_info[voice].sample_rates = {}
    sample_info[voice].sample_lengths = {}
    sample_info[voice].sample_frames = {}
    sample_info[voice].sample_count = 0
    for i = 1,sample_loop_info[voice].count do
      if clock.threads[sample_loop_info[voice].clocks[i]] then
        clock.cancel(sample_loop_info[voice].clocks[i])
      end
    end
    local num = string.gsub(voice,'sample','')
    for i = 1,number_of_hills do
      if params:get('hill '..i..' sample slot') == tonumber(num) then
        params:hide('hill '..i..' sample distribution')
        params:hide('hill '..i..' sample slice count')
        menu_rebuild_queued = true
        -- _menu.rebuild_params()
      end
    end
  end

end

-- function ca.sample_callback(path,i,summed)
--   if path ~= "cancel" and path ~= "" then
--     ca.load_sample(path,i,summed)
--     clip[i].collage = false
--   end
-- end
---
function ca.folder_callback(file,dest)
  
  local split_at = string.match(file, "^.*()/")
  local folder = string.sub(file, 1, split_at)
  file = string.sub(file, split_at + 1)
  
  ca.collage(folder,dest,1)

end

function getParentPath(_path)
  return string.match(_path, "^(.+)/")
end

function ca.stop_sample(sample)
  -- engine.stop_sample(sample)
  send_to_engine('stop_sample',{sample})
end

function ca.set_rate(sample,r)
  -- engine.set_voice_param(sample,'rate',r)
  send_to_engine('set_voice_param',{sample,'rate',r})
end

function ca.derive_bpm(source)
  local dur = 0
  local pattern_id;
  if source.original_length ~= nil then
    dur = source.original_length
  end
  if dur > 0 then
    local quarter = dur/4
    local derived_bpm = 60/quarter
    while derived_bpm < 70 do
      derived_bpm = derived_bpm * 2
      if derived_bpm > 160 then break end
    end
    while derived_bpm > 160 do
      derived_bpm = derived_bpm/2
      if derived_bpm <= 70 then break end
    end
    return util.round(derived_bpm,0.01)
  end
end

function ca.get_resampled_rate(voice, i, j, pitched)
  local total_offset;
  total_offset = params:get(voice..'_sample_playbackRateOffset')
  local step_rate = hills[i][j].sample_controls.rate[hills[i][hills[i].segment].index]
  total_offset = math.pow(0.5, -total_offset / 12) * sample_speedlist[step_rate]  
  if pitched then
    total_offset = total_offset * pitched
  end
  if util.round(params:get(voice..'_sample_playbackPitchControl'),0.01) ~= 0 then
    total_offset = total_offset + (total_offset * (util.round(params:get(voice..'_sample_playbackPitchControl'),0.01)/100))
  end
  return (total_offset * sample_speedlist[params:get(voice..'_sample_playbackRateBase')])
end

function ca.get_pitched_rate(target,i,j,played_note)
  local note_distance = (played_note - 60)
  local rates_from_notes = {
    1,
    1.05946,
    1.12246,
    1.18920,
    1.25992,
    1.33484,
    1.41421,
    1.49830,
    1.58740,
    1.68179,
    1.78179,
    1.88774,
  }
  local octave_distance = 0
  octave_distance = math.floor((played_note - 60)/12)
  if played_note == (60 + ((octave_distance+1)*11) + octave_distance) then
    return (ca.get_resampled_rate(target,i,j,rates_from_notes[12] * (2^octave_distance)))
  else
    return (ca.get_resampled_rate(target,i,j,rates_from_notes[util.wrap(note_distance+1,1,#rates_from_notes)] * (2^octave_distance)))
  end
end

function ca.play_slice(target,slice,velocity,i,j, played_note, retrig_index)
  if params:get(target..'_sample_sampleFile') ~= _path.audio then
    kildare.allocVoice[i] = util.wrap(kildare.allocVoice[i]+1, 1, params:get(i..'_poly_voice_count'))
    -- print(target,kildare.allocVoice[i],sample_loop_info[target].clocks[kildare.allocVoice[i]])
    -- if clock.threads[sample_loop_info[target].clocks[kildare.allocVoice[i]]] then
    --   clock.cancel(sample_loop_info[target].clocks[kildare.allocVoice[i]])
    -- end
    -- if params:get(i..'_poly_voice_count') > 1
    -- and _polyparams.adjusted_params[target][kildare.allocVoice[i]].params[target..'_sample_loop'] == 1
    -- then
    --   _polyparams.queued_loop[i][kildare.allocVoice[i]] = true
    -- end
    local slice_count = params:get('hill '..i..' sample slice count')
    local sampleEnd = (slice)/slice_count
    local sampleStart = (slice-1)/slice_count
    send_to_engine('set_sample_bounds',{target,'sampleStart',(slice-1)/slice_count, kildare.allocVoice[i]})
    send_to_engine('set_sample_bounds',{target,'sampleEnd',(slice)/slice_count, kildare.allocVoice[i]})
    print('sample points: '..(slice-1)/slice_count,(slice)/slice_count)
    if params:string(target..'_sample_loop') == 'off' then
      send_to_engine('set_voice_param',{target,'loop',hills[i][j].sample_controls.loop[hills[i][j].index] and 1 or 0})
    else
      send_to_engine('set_voice_param',{target,'loop',1})
    end
    local rate;
    if params:string('hill '..i..' sample repitch') == "yes" and played_note ~= nil then
      rate = ca.get_pitched_rate(target,i,j,played_note)
    else
      rate = ca.get_resampled_rate(target, i, j)
    end
    send_to_engine('set_voice_param',{target, 'rate', rate})
    if retrig_index == 0 then
      send_to_engine('trig',{target,velocity,'false',kildare.allocVoice[i]})
      -- print('no trig '..kildare.allocVoice[i])
    else
      send_to_engine('trig',{target,velocity,'true',kildare.allocVoice[i]})
      -- print('yes trig '..kildare.allocVoice[i])
    end
    -- TODO: confirm this is still useful...230312
    if params:get(i..'_poly_voice_count') ~= 1 then
      local check_rate_change = _polyparams.adjusted_params[i][kildare.allocVoice[i]].params[i..'_sample_playbackRateBase']
      if check_rate_change ~= nil then
        local rate = params:lookup_param(i..'_sample_playbackRateBase'):map_value(check_rate_change)
        rate = sample_speedlist[rate]
        send_to_engine('set_poly_voice_param',{i, kildare.allocVoice[i], 'rate', rate})
      end
    end
  end
end

function ca.play_index(target,index,velocity,i,j, played_note, retrig_index)
  kildare.allocVoice[i] = util.wrap(kildare.allocVoice[i]+1, 1, params:get(i..'_poly_voice_count'))
  send_to_engine('change_sample',{target,index})
  send_to_engine('set_voice_param',{target,'sampleStart',0})
  send_to_engine('set_voice_param',{target,'sampleEnd',1})
  if params:string(target..'_sample_loop') == 'off' then
    send_to_engine('set_voice_param',{target,'loop',hills[i][j].sample_controls.loop[hills[i][j].index] and 1 or 0})
  else
    send_to_engine('set_voice_param',{target,'loop',1})
  end
  local rate;
  if params:string('hill '..i..' sample repitch') == "yes" and played_note ~= nil then
    rate = ca.get_pitched_rate(target,i,j,played_note)
  else
    rate = ca.get_resampled_rate(target, i, j)
  end
  send_to_engine('set_voice_param',{target, 'rate', rate})
  if retrig_index == 0 then
    send_to_engine('trig',{target,velocity,'false',kildare.allocVoice[i]})
  else
    send_to_engine('trig',{target,velocity,'true',kildare.allocVoice[i]})
  end
end

function ca.play_transient(target,slice,velocity,i,j, played_note, retrig_index)
  if params:get(target..'_sample_sampleFile') ~= _path.audio then
    kildare.allocVoice[i] = util.wrap(kildare.allocVoice[i]+1, 1, params:get(i..'_poly_voice_count'))
    local slice_count = params:get('hill '..i..' sample slice count')
    local start_time_as_percent = cursors[slice]/sample_info[target].sample_lengths[1]
    local end_time_as_percent = slice ~= slice_count and ((cursors[slice+1]/sample_info[target].sample_lengths[1])-0.01) or 1
    
    -- engine.set_voice_param(target,'sampleStart',start_time_as_percent)
    send_to_engine('set_voice_param',{target,'sampleStart',start_time_as_percent})
    -- engine.set_voice_param(target,'sampleEnd',end_time_as_percent)
    send_to_engine('set_voice_param',{target,'sampleEnd',end_time_as_percent})
    if params:string(target..'_sample_loop') == 'off' then
      -- engine.set_voice_param(target,'loop',hills[i][j].sample_controls.loop[hills[i][j].index] and 1 or 0)
      send_to_engine('set_voice_param',{target,'loop',hills[i][j].sample_controls.loop[hills[i][j].index] and 1 or 0})
    else
      -- engine.set_voice_param(target,'loop',1)
      send_to_engine('set_voice_param',{target,'loop',1})
    end
    local rate;
    if params:string('hill '..i..' sample repitch') == "yes" and played_note ~= nil then
      rate = ca.get_pitched_rate(target,i,j,played_note)
    else
      rate = ca.get_resampled_rate(target, i, j)
    end
    -- engine.set_voice_param(target, 'rate', rate)
    send_to_engine('set_voice_param',{target, 'rate', rate})
    if retrig_index == 0 then
      -- engine.trig(target,velocity,'false',kildare.allocVoice[i])
      send_to_engine('trig',{target,velocity,'false',kildare.allocVoice[i]})
    else
      -- engine.trig(target,velocity,'true',kildare.allocVoice[i])
      send_to_engine('trig',{target,velocity,'true',kildare.allocVoice[i]})
    end
  end
end

function ca.play_through(target,velocity,i,j, played_note, retrig_index)
  kildare.allocVoice[i] = util.wrap(kildare.allocVoice[i]+1, 1, params:get(i..'_poly_voice_count'))
  -- send_to_engine('set_voice_param',{target,'sampleStart',params:get(target..'_sample_sampleStart')})
  -- send_to_engine('set_voice_param',{target,'sampleEnd',params:get(target..'_sample_sampleEnd')})
  if params:string(target..'_sample_loop') == 'off' then
    send_to_engine('set_voice_param',{target,'loop',hills[i][j].sample_controls.loop[hills[i][j].index] and 1 or 0})
  else
    send_to_engine('set_voice_param',{target,'loop',1})
  end
  local rate;
  if params:string('hill '..i..' sample repitch') == "yes" and played_note ~= nil then
    rate = ca.get_pitched_rate(target,i,j,played_note)
  else
    rate = ca.get_resampled_rate(target, i, j)
  end
  send_to_engine('set_voice_param',{target, 'rate', rate})
  if retrig_index == 0 then
    send_to_engine('trig',{target,velocity,'false',kildare.allocVoice[i]})
  else
    send_to_engine('trig',{target,velocity,'true',kildare.allocVoice[i]})
  end
end

return ca