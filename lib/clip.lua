local ca = {}

function ca.init()
  max_sample_duration = 90
  softcut_offsets = {0,100,200}
  -- it'll be easiest to just do 1,2,3 and 1+3,2+3,3+3
  clip = {}
  sample_track = {}
  clear = {}
  sample_speedlist = {
    {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4},
    {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4},
    {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4},
  }
  sample_offset = {1,1,1,1,1,1}
  for i = 1,3 do
    clip[i] = {}
    clip[i].length = 90
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

    -- softcut.enable(i, 1)
    -- softcut.rec(i, 0)
    -- softcut.rec_level(i,0)
    -- softcut.loop(i,0)
    -- softcut.level(i,1)
    -- softcut.loop_start(i,softcut_offsets[i])
    -- softcut.fade_time(i,clip[i].fade_time)

    for j = i,i+3,3 do
      softcut.enable(j, 1)
      softcut.rec(j, 0)
      softcut.rec_level(j,0)
      softcut.loop(j,0)
      -- softcut.level(j,0.5)
      softcut.level(j,1)
      -- okay, cool, if a sample has two channels then panning should just be stereo balance
      -- otherwise, it's panning
      softcut.pan(j,j == i and -1 or 1)
      softcut.loop_start(j,softcut_offsets[i])
      softcut.fade_time(j,clip[i].fade_time)
    end

    sample_track[i] = {}
    sample_track[i].reverse = false
  end
end

function ca.sample_callback(path,i,summed)
  if path ~= "cancel" and path ~= "" then
    ca.load_sample(path,i,summed)
    clip[i].collage = false
  end
end

function ca.load_sample(file,sample,summed)
  local old_min = clip[sample].min
  local old_max = clip[sample].max
  if file ~= "-" and file ~= "" then
    local ch, len, rate = audio.file_info(file)
    clip[sample].sample_rate = rate
    if clip[sample].sample_rate ~= 48000 then
      print("sample rate needs to be 48khz!")
      print(len/48000, len/rate)
    end
    if len/48000 < max_sample_duration then
      clip[sample].sample_length = len/48000
    else
      clip[sample].sample_length = max_sample_duration
    end
    clip[sample].original_length = len/48000
    clip[sample].original_bpm = ca.derive_bpm(clip[sample])
    clip[sample].original_samplerate = rate/1000
    -- local im_ch = ch == 2 and clip[sample].channel-1 or 1
    local scaled = {
      {1,softcut_offsets[1],clip[sample].sample_length + 0.05 + softcut_offsets[1]},
      {1,softcut_offsets[2],clip[sample].sample_length + 0.05 + softcut_offsets[2]},
      {1,softcut_offsets[3],clip[sample].sample_length + 0.05 + softcut_offsets[3]},
      {2,softcut_offsets[1],clip[sample].sample_length + 0.05 + softcut_offsets[1]},
      {2,softcut_offsets[2],clip[sample].sample_length + 0.05 + softcut_offsets[2]},
      {2,softcut_offsets[3],clip[sample].sample_length + 0.05 + softcut_offsets[3]},
    }
    if sample_track[sample].playing then
      -- softcut.play(sample,0)
      -- sample_track[sample].playing = false
      ca.stop_playback(sample)
    end
    -- softcut.buffer_clear_region(softcut_offsets[sample],clip[sample].sample_length + 0.05)
    -- softcut.buffer_read_stereo(file, 0, softcut_offsets[sample], clip[sample].sample_length + 0.05) -- TODO: verify if preserve could just be 0?
    softcut.buffer_read_stereo(file, 0, softcut_offsets[sample], clip[sample].sample_length + 0.05, 0) -- TODO: verify if preserve could just be 0?
    sample_track[sample].end_point = (clip[sample].sample_length-0.01) + softcut_offsets[sample]
    -- softcut.loop_end(sample,sample_track[sample].end_point) -- TODO: verify if i even need this cuz doesn't the hill just call it up?
    -- softcut.position(sample,softcut_offsets[sample])
    ca.set_position(sample,softcut_offsets[sample])
    -- softcut.rate(sample,ca.get_total_pitch_offset(sample))
    ca.set_rate(sample,ca.get_total_pitch_offset(sample))
    clear[sample] = 0
    sample_track[sample].rec_limit = 0
  end
  if params:get("clip "..sample.." sample") ~= file then
    params:set("clip "..sample.." sample", file, 1)
  end
end

function ca.stop_playback(sample)
  softcut.play(sample,0)
  softcut.play(sample+3,0)
  sample_track[sample].playing = false
end

function ca.start_playback(sample)
  softcut.play(sample,1)
  softcut.play(sample+3,1)
  sample_track[sample].playing = true
end

function ca.set_position(sample,pos)
  -- softcut.position(sample,pos)
  softcut.position(sample,ca.offset_loop_start(sample,pos,"L"))
  softcut.position(sample+3,ca.offset_loop_start(sample,pos,"R"))
end

function ca.set_loop_start(sample,pos)
  -- softcut.loop_start(sample,pos)
  softcut.loop_start(sample,ca.offset_loop_start(sample,pos,"L"))
  softcut.loop_start(sample+3,ca.offset_loop_start(sample,pos,"R"))
end

function ca.offset_loop_start(sample,pos,side)
  return (pos + (params:get("playhead_distance_"..side.."_"..sample)/1000))
end

function ca.set_loop_end(sample,pos)
  softcut.loop_end(sample,pos)
  softcut.loop_end(sample+3,pos)
end

function ca.set_rate(sample,r)
  softcut.rate(sample,r)
  softcut.rate(sample+3,r)
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

function ca.get_total_pitch_offset(_t,i,j)
  local total_offset;
  total_offset = params:get("semitone_offset_".._t)
  local sample_rate_compensation;
  if (48000/clip[_t].sample_rate) > 1 then
    sample_rate_compensation = ((1200 * math.log(48000/clip[_t].sample_rate,2))/-100)
  else
    sample_rate_compensation = ((1200 * math.log(clip[_t].sample_rate/48000,2))/100)
  end
  total_offset = total_offset + sample_rate_compensation
  total_offset = math.pow(0.5, -total_offset / 12) * sample_speedlist[_t][params:get("speed_clip_".._t)]
  -- if i ~= nil and j ~= nil then
  --   total_offset = math.pow(0.5, -total_offset / 12) * sample_speedlist[_t][hills[i][j].softcut_controls.rate[hills[i][j].index]]
  -- else
  --   total_offset = math.pow(0.5, -total_offset / 12) * sample_speedlist[_t][params:get("speed_clip_".._t)]
  -- end
  if params:get("pitch_control") ~= 0 then
    -- if total_offset < 0 then
    --   sample_track[_t].reverse = true
    -- end
    return (total_offset + (total_offset * (params:get("pitch_control")/100)))
  else
    -- print(total_offset)
    -- if total_offset < 0 then
    --   sample_track[_t].reverse = true
    -- else
    --   sample_track[_t].reverse = false
    -- end
    return (total_offset)
  end
end

function ca.calculate_sc_positions(i,j,played_note)
  -- print(i,j,played_note)
  local slice = util.wrap(played_note - params:get("hill "..i.." base note"),0,15) + 1
  local sample = params:get("hill "..i.." softcut slot")
  if params:get("clip "..sample.." sample") ~= "/home/we/dust/audio/" then
    if not sample_track[sample].playing then
      ca.start_playback(sample)
    end
    local duration = sample_track[sample].end_point - softcut_offsets[sample]
    local s_p = softcut_offsets[sample]
    local sc_start_point_base = (s_p+(duration/16) * (slice-1))
    local sc_end_point_base = (s_p+(duration/16) * (slice)) - clip[sample].fade_time
    -- softcut.rate(sample,ca.get_total_pitch_offset(sample,i,j))
    ca.set_rate(sample,ca.get_total_pitch_offset(sample,i,j))
    -- softcut.loop_start(sample,sc_start_point_base)
    ca.set_loop_start(sample,sc_start_point_base)
    -- softcut.loop_end(sample,sc_end_point_base)
    ca.set_loop_end(sample,sc_end_point_base)
    -- softcut.position(sample,sample_track[sample].reverse and sc_end_point_base or sc_start_point_base)
    ca.set_position(sample,sample_track[sample].reverse and sc_end_point_base or sc_start_point_base)
  end
end

return ca