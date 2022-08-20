local ca = {}

function ca.init()
  max_sample_duration = 96
  softcut_offsets = {1,100,200}
  -- it'll be easiest to just do 1,2,3 and 1+3,2+3,3+3
  clip = {}
  sample_track = {}
  clear = {}
  sample_speedlist = {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4}
  sample_offset = {1,1,1,1,1,1}
  for i = 1,3 do
    clip[i] = {}
    clip[i].sample_length = max_sample_duration
    clip[i].sample_rate = 48000
    clip[i].start_point = nil
    clip[i].end_point = nil
    clip[i].mode = 1
    clip[i].waveform_samples = {}
    clip[i].waveform_rendered = false
    clip[i].channel = 1
    clip[i].collage = false
    clip[i].fade_time = 0.01
    clip[i].collaged_rates = {}
    clip[i].slice = {}
    for j = 1,16 do
      clip[i].slice[j] = {start_point = 0, end_point = 0}
    end

    for j = i,i+3,3 do
      softcut.enable(j, 1)
      softcut.rec(j, 0)
      softcut.rec_level(j,0)
      softcut.loop(j,0)
      -- softcut.level(j,0.5)
      softcut.level(j,1)
      softcut.level_slew_time(j,0.005) -- TODO: CONFIRM GOOD
      -- okay, cool, if a sample has two channels then panning should just be stereo balance
      -- otherwise, it's panning
      softcut.pan(j,j == i and -1 or 1)
      softcut.loop_start(j,softcut_offsets[i])
      softcut.fade_time(j,clip[i].fade_time)
      softcut.position(j,-1)
      softcut.rate_slew_time(j,0.005)
    end

    softcut.play(i,1)
    softcut.play(i+3,1)

    sample_track[i] = {}
    sample_track[i].reverse = false
    sample_track[i].changed_direction = false
  end

  sample_info = {sample1 = {sample_rates = {}}, sample2 = {sample_rates = {}}, sample3 = {sample_rates = {}}}

  function kildare.folder_callback(voice,folder)
    sample_info[voice] = {}
    sample_info[voice].sample_rates = {}
    local wavs = util.scandir(folder)
    local sample_id = 0
    for index, data in ipairs(wavs) do
      local ch, len, rate = audio.file_info(folder..data)
      if rate ~= 0 then
        sample_id = sample_id + 1
        sample_info[voice].sample_rates[sample_id] = rate
      end
    end
  end

  function kildare.file_callback(voice,file)
    sample_info[voice] = {}
    sample_info[voice].sample_rates = {}
    local ch, len, rate = audio.file_info(file)
    if rate ~= 0 then
      sample_info[voice].sample_rates[1] = rate
    end
  end

  function kildare.clear_callback(voice)
    sample_info[voice] = {}
    sample_info[voice].sample_rates = {}
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

function ca.collage(folder,dest)
  local wavs = util.scandir(folder)
  local clean_wavs = {}
  local sample_id = 0
  for index, data in ipairs(wavs) do
    if string.match(data, ".wav") then
      table.insert(clean_wavs, data)
      sample_id = sample_id + 1
    end
  end
  print(sample_id)
  tab.print(clean_wavs)
  
  if sample_track[dest].playing then
    ca.stop_playback(dest)
  end

  softcut.buffer_clear_region(softcut_offsets[dest], max_sample_duration, 0, 0)

  -- ok what are the desireable behaviors??
  -- STYLE 1, load whole folder sequentially

  local import_length = {}
  sample_track[dest].end_point = 0 + softcut_offsets[dest]
  for i = 1,(sample_id <=16 and sample_id or 16) do
    local samp = folder .. clean_wavs[i]
    local ch, len, rate = audio.file_info(samp)
    import_length[i] = len/rate >= 6 and 6 or len/rate -- FIXME: does this need to be len/48000??

    --okay, each time one is imported in:
    clip[dest].collaged_rates[i] = rate
    clip[dest].slice[i].start_point = i == 1 and softcut_offsets[dest] or clip[dest].slice[i-1].end_point
    clip[dest].slice[i].end_point = clip[dest].slice[i].start_point + import_length[i]

    if ch == 2 then
      softcut.buffer_read_stereo(samp, 0, clip[dest].slice[i].start_point, import_length[i], 0)
    elseif ch == 1 then
      softcut.buffer_read_mono(samp, 0, clip[dest].slice[i].start_point, import_length[i], 1, 1, 0, 0.5)
      softcut.buffer_read_mono(samp, 0, clip[dest].slice[i].start_point, import_length[i], 1, 2, 0, 0.5)
    else
      print("samples can't be multichannel, need to either be mono or stereo")
    end
    print(samp,i,clip[dest].slice[i].start_point, import_length[i])
    
    sample_track[dest].end_point = sample_track[dest].end_point + import_length[i]
  end
  
  sample_track[dest].end_point = sample_track[dest].end_point - 0.01
  ca.set_position(dest,softcut_offsets[dest])
  ca.set_rate(dest,ca.get_total_pitch_offset(dest))
  clear[dest] = 0
  sample_track[dest].rec_limit = 0

  if params:get("clip "..dest.." sample") ~= "distributed" then
    params:set("clip "..dest.." sample", "distributed", 1)
  end

  clip[dest].sample_length = sample_track[dest].end_point
  clip[dest].original_length = 96
  clip[dest].original_bpm = 120
  clip[dest].original_samplerate = 48000
  clip[dest].collage = true
  clip[dest].slice_count = sample_id
  
  -- local filepath_name = string.sub(getParentPath(folder), 21)
  -- params:set("clip "..dest.." sample folder", filepath_name, 1)
end
---
function ca.stop_playback(sample)
  softcut.play(sample,0)
  softcut.play(sample+3,0)
  sample_track[sample].playing = false
end

function ca.zero_rate(sample)
  softcut.rate(sample,0)
  softcut.rate(sample+3,0)
  -- sample_track[sample].playing = false
end

function ca.start_playback(sample)
  softcut.play(sample,1)
  softcut.play(sample+3,1)
  sample_track[sample].playing = true
end

function ca.set_position(sample,pos)
  -- softcut.position(sample,pos)
  if sample_track[sample].reverse then
    softcut.loop_end(sample,ca.offset_loop_start(sample,pos,"L"))
    softcut.loop_end(sample+3,ca.offset_loop_start(sample,pos,"R"))
    softcut.position(sample,ca.offset_loop_start(sample,pos,"L")-0.001)
    softcut.position(sample+3,ca.offset_loop_start(sample,pos,"R")-0.001)
    -- softcut.voice_sync(sample+3,sample,(ca.offset_loop_start(sample,pos,"L")-0.001) - (ca.offset_loop_start(sample,pos,"R")-0.001))
  else
    softcut.position(sample,ca.offset_loop_start(sample,pos,"L"))
    softcut.position(sample+3,ca.offset_loop_start(sample,pos,"R"))
    -- softcut.voice_sync(sample+3,sample,ca.offset_loop_start(sample,pos,"L") - ca.offset_loop_start(sample,pos,"R"))
  end
end

function ca.set_loop_start(sample,pos)
  -- softcut.loop_start(sample,pos)
  softcut.loop_start(sample,ca.offset_loop_start(sample,pos,"L"))
  softcut.loop_start(sample+3,ca.offset_loop_start(sample,pos,"R"))
end

function ca.offset_loop_start(sample,pos,side)
  return (pos + (params:get("playhead_distance_"..side.."_"..sample)/100))
end

function ca.set_loop_state(sample,state)
  local set_to;
  if state then
    set_to = 1
  else
    set_to = 0
  end
  softcut.loop(sample,set_to)
  softcut.loop(sample+3,set_to)
end

function ca.set_loop_end(sample,pos)
  softcut.loop_end(sample,pos)
  softcut.loop_end(sample+3,pos)
end

function ca.set_rate(sample,r)
  engine.set_voice_param(sample,'rate',r)
end

function ca.set_level(sample,l)
  local R_distributed = util.linlin(-1,1,0,l,params:get("pan_clip_"..sample))
  local L_distributed = util.linlin(0,l,l,0,R_distributed)
  softcut.level(sample, L_distributed)
  softcut.level(sample+3, R_distributed)
end

function ca.set_pan(sample,p)
  local R_distributed = util.linlin(-1,1,0,params:get("vol_clip_"..sample),p)
  local L_distributed = util.linlin(0,params:get("vol_clip_"..sample),params:get("vol_clip_"..sample),0,R_distributed)
  softcut.level(sample, L_distributed)
  softcut.level(sample+3, R_distributed)
end

function ca.set_filter(param,sample,val)
  softcut[param](sample,val)
  softcut[param](sample+3,val)
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

function ca.get_total_pitch_offset(_t,i,j,pitched)
  local total_offset;
  total_offset = params:get("semitone_offset_".._t)
  local sample_rate_compensation;
  -- if clip[_t].collage then
  if (48000/clip[_t].sample_rate) > 1 then
    sample_rate_compensation = ((1200 * math.log(48000/clip[_t].sample_rate,2))/-100)
  else
    sample_rate_compensation = ((1200 * math.log(clip[_t].sample_rate/48000,2))/100)
  end
  total_offset = total_offset + sample_rate_compensation
  local step_rate;
  if i and j then
    step_rate = hills[i][j].sample_controls.rate[hills[i][hills[i].segment].index]
    -- print(i,j,step_rate)
  end
  if not pitched then
    if step_rate and step_rate ~= params:get("speed_clip_".._t) then
      total_offset = math.pow(0.5, -total_offset / 12) * sample_speedlist[step_rate]  
    else
      total_offset = math.pow(0.5, -total_offset / 12) * sample_speedlist[params:get("speed_clip_".._t)]
    end
  else
    if step_rate and step_rate ~= params:get("speed_clip_".._t) then
      total_offset = math.pow(0.5, -total_offset / 12) * pitched * sample_speedlist[_t][step_rate]
    else
      total_offset = math.pow(0.5, -total_offset / 12) * pitched * sample_speedlist[_t][params:get("speed_clip_".._t)]
    end
  end
  if params:get("pitch_control") ~= 0 then
    total_offset = total_offset + (total_offset * (params:get("pitch_control")/100))
    if total_offset < 0 then
      if not sample_track[_t].reverse then
        sample_track[_t].changed_direction = true
      else
        sample_track[_t].changed_direction = false
      end
      sample_track[_t].reverse = true
    end
    return (total_offset)
  else
    -- print(total_offset)
    if total_offset < 0 then
      if not sample_track[_t].reverse then
        sample_track[_t].changed_direction = true
      else
        sample_track[_t].changed_direction = false
      end
      sample_track[_t].reverse = true
    else
      if sample_track[_t].reverse then
        sample_track[_t].changed_direction = true
      else
        sample_track[_t].changed_direction = false
      end
      sample_track[_t].reverse = false
    end
    return (total_offset)
  end
end

function ca.get_resampled_rate(voice, sample_id, i, j, pitched)
  local total_offset;
  total_offset = params:get(voice..'_playbackRateOffset')
  local step_rate;
  if i and j then
    step_rate = hills[i][j].sample_controls.rate[hills[i][hills[i].segment].index]
  end
  if not pitched then
    if step_rate and step_rate ~= params:get(voice..'_playbackRateBase') then
      total_offset = math.pow(0.5, -total_offset / 12) * sample_speedlist[step_rate]  
    else
      total_offset = math.pow(0.5, -total_offset / 12) * sample_speedlist[params:get(voice..'_playbackRateBase')]
    end
  else
    if step_rate and step_rate ~= params:get(voice..'_playbackRateBase') then
      total_offset = math.pow(0.5, -total_offset / 12) * pitched * sample_speedlist[step_rate]
    else
      total_offset = math.pow(0.5, -total_offset / 12) * pitched * sample_speedlist[params:get(voice..'_playbackRateBase')]
    end
  end
  if util.round(params:get(voice..'_playbackPitchControl'),0.01) ~= 0 then
    total_offset = total_offset + (total_offset * (util.round(params:get(voice..'_playbackPitchControl'),0.01)/100))
    return (total_offset)
  else
    return (total_offset)
  end
end

function ca.set_true_rate(i,j,played_note)
  if params:string("hill "..i.." softcut repitch") == "yes" then
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
      ca.set_rate(sample,ca.get_total_pitch_offset(sample,i,j,rates_from_notes[12] * (2^octave_distance)))
    else
      ca.set_rate(sample,ca.get_total_pitch_offset(sample,i,j,rates_from_notes[util.wrap(note_distance+1,1,#rates_from_notes)] * (2^octave_distance)))
    end
  else
    ca.set_rate(sample,ca.get_total_pitch_offset(sample,i,j))
  end
end

function ca.play_slice(target,slice,velocity,i,j)
  engine.set_voice_param(target,'sampleStart',slice/16)
  engine.set_voice_param(target,'sampleEnd',(slice+1)/16)
  local rate = ca.get_resampled_rate(target, 1, i, j)
  print(rate)
  engine.set_voice_param(target, 'rate', rate)
  engine.trig(target,velocity)
end

function ca.play_through(target,velocity)
  engine.set_voice_param(target,'sampleStart',0)
  engine.set_voice_param(target,'sampleEnd',1)
  engine.trig(target,velocity)
end

function ca.play_index(target,index,velocity)
  engine.change_sample(target,index)
  engine.set_voice_param(target,'sampleStart',0)
  engine.set_voice_param(target,'sampleEnd',1)
  engine.trig(target,velocity)
end

function ca.calculate_sc_positions(i,j,played_note)
  -- print(i,j,played_note)
  local sample = params:get("hill "..i.." softcut slot")
  local slice_count;
  if clip[sample].collage then
    slice_count = clip[sample].slice_count <= 16 and clip[sample].slice_count or 16
  else
    slice_count = 16
  end
  local slice = util.wrap(played_note - params:get("hill "..i.." base note"),0,slice_count-1) + 1
  if params:get("clip "..sample.." sample") ~= "/home/we/dust/audio/" then
    if not sample_track[sample].playing then
      ca.start_playback(sample)
    end
    local duration = sample_track[sample].end_point - softcut_offsets[sample]
    local s_p = softcut_offsets[sample]
    local sc_start_point_base, sc_end_point_base;
    if clip[sample].collage then
      sc_start_point_base = clip[sample].slice[slice].start_point
      sc_end_point_base = clip[sample].slice[slice].end_point - clip[sample].fade_time
    else
      sc_start_point_base = (s_p+(duration/slice_count) * (slice-1))
      sc_end_point_base = (s_p+(duration/slice_count) * (slice)) - clip[sample].fade_time
    end
    if params:string("hill "..i.." softcut repitch") == "yes" then
      -- local note_distance = (played_note - params:get("hill "..i.." base note"))
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
      -- octave_distance = math.floor((played_note - params:get("hill "..i.." base note"))/12)
      octave_distance = math.floor((played_note - 60)/12)
      -- if played_note == (params:get("hill "..i.." base note") + ((octave_distance+1)*11) + octave_distance) then
      if played_note == (60 + ((octave_distance+1)*11) + octave_distance) then
        -- print("weird:", params:get("hill "..i.." base note"), played_note, note_distance, octave_distance, rates_from_notes[12] * (2^octave_distance))
        -- ca.set_rate(sample,rates_from_notes[12] * (2^octave_distance))
        ca.set_rate(sample,ca.get_total_pitch_offset(sample,i,j,rates_from_notes[12] * (2^octave_distance)))
      else
        -- print(params:get("hill "..i.." base note"), played_note, note_distance, octave_distance, rates_from_notes[util.wrap(note_distance+1,1,#rates_from_notes)] * (2^octave_distance))
        -- ca.set_rate(sample,rates_from_notes[util.wrap(note_distance+1,1,#rates_from_notes)] * (2^octave_distance))
        ca.set_rate(sample,ca.get_total_pitch_offset(sample,i,j,rates_from_notes[util.wrap(note_distance+1,1,#rates_from_notes)] * (2^octave_distance)))
      end
    else
      ca.set_rate(sample,ca.get_total_pitch_offset(sample,i,j))
    end
    local changed_direction = sample_track[sample].changed_direction
    if params:get("clip "..sample.." sample") ~= "playthrough" then
      ca.set_loop_start(sample,sc_start_point_base)
      ca.set_loop_end(sample,sc_end_point_base)
      -- ca.set_position(sample,sample_track[sample].reverse and sc_end_point_base-0.001 or sc_start_point_base)
      if changed_direction then
        -- TODO: account for offset_loop_start...
        -- ca.set_position(sample,sample_track[sample].reverse and sample_track[sample].end_point-0.001 or softcut_offsets[sample]+0.001)
        ca.set_position(sample,sample_track[sample].reverse and sc_end_point_base-0.001 or sc_start_point_base + 0.001)
      else
        ca.set_position(sample,sample_track[sample].reverse and sc_end_point_base or sc_start_point_base)
      end
    elseif params:get("clip "..sample.." sample") == "playthrough" then
      ca.set_loop_start(sample,softcut_offsets[sample])
      ca.set_loop_end(sample,sample_track[sample].end_point)
      -- print("reverse: "..tostring(sample_track[sample].reverse), "was reversed: "..tostring(changed_direction))
      if changed_direction then
        -- TODO: account for offset_loop_start...
        ca.set_position(sample,sample_track[sample].reverse and sample_track[sample].end_point-0.001 or softcut_offsets[sample]+0.001)
      else
        ca.set_position(sample,sample_track[sample].reverse and sample_track[sample].end_point or softcut_offsets[sample])
      end
    end
    ca.set_loop_state(sample,hills[i][j].sample_controls.loop[hills[i][j].index])
    -- softcut.loop_start(sample,sc_start_point_base)
    
  end
end

return ca