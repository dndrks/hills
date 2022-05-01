local ca = {}

function ca.init()
  max_sample_duration = 60
  softcut_offsets = {0,0,100,100,200,200}
  clip = {}
  sample_track = {}
  clear = {}
  sample_speedlist = {
    {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4},
    {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4},
    {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4},
    {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4},
    {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4},
    {-4, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2, 4}
  }
  sample_offset = {1,1,1,1,1,1}
  for i = 1,6 do
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

    softcut.enable(i, 1)
    softcut.rec(i, 0)
    softcut.rec_level(i,0)
    softcut.loop(i,0)
    softcut.level(i,1)
    softcut.loop_start(i,softcut_offsets[i])
    softcut.fade_time(i,clip[i].fade_time)

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
    local im_ch = ch == 2 and clip[sample].channel-1 or 1
    local scaled = {
      -- {buffer, start, end}
      {1,0,clip[sample].sample_length + 0.05},
      {2,0,clip[sample].sample_length + 0.05},
      {1,softcut_offsets[3],clip[sample].sample_length + 0.05 + softcut_offsets[3]},
      {2,softcut_offsets[4],clip[sample].sample_length + 0.05 + softcut_offsets[4]},
      {1,softcut_offsets[5],clip[sample].sample_length + 0.05 + softcut_offsets[5]},
      {2,softcut_offsets[6],clip[sample].sample_length + 0.05 + softcut_offsets[6]},
    }
    if sample_track[sample].playing then
      softcut.play(sample,0)
      sample_track[sample].playing = false
    end
    softcut.buffer_clear_region_channel(scaled[sample][1],scaled[sample][2],max_sample_duration)
    softcut.buffer_read_mono(file, 0, scaled[sample][2], clip[sample].sample_length + 0.05, im_ch, scaled[sample][1])
    sample_track[sample].end_point = (clip[sample].sample_length-0.01) + softcut_offsets[sample]
    softcut.loop_end(sample,sample_track[sample].end_point)
    softcut.position(sample,softcut_offsets[sample])
    softcut.rate(sample,ca.get_total_pitch_offset(sample))
    clear[sample] = 0
    sample_track[sample].rec_limit = 0
  end
  if params:get("clip "..sample.." sample") ~= file then
    params:set("clip "..sample.." sample", file, 1)
  end
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

function ca.get_total_pitch_offset(_t)
  local total_offset;
  total_offset = params:get("semitone_offset_".._t)
  local sample_rate_compensation;
  if (48000/clip[_t].sample_rate) > 1 then
    sample_rate_compensation = ((1200 * math.log(48000/clip[_t].sample_rate,2))/-100)
  else
    sample_rate_compensation = ((1200 * math.log(clip[_t].sample_rate/48000,2))/100)
  end
  total_offset = total_offset + sample_rate_compensation
  total_offset = math.pow(0.5, -total_offset / 12) * sample_speedlist[_t][params:get("speed_voice_".._t)]
  if params:get("pitch_control") ~= 0 then
    return (total_offset + (total_offset * (params:get("pitch_control")/100)))
  else
    return (total_offset)
  end
end

function ca.calculate_sc_positions(i,played_note)
  local slice = util.wrap(played_note - params:get("hill "..i.." base note"),0,15) + 1
  local sample = params:get("hill "..i.." softcut slot")
  if params:get("clip "..sample.." sample") ~= "/home/we/dust/audio/" then
    if not sample_track[sample].playing then
      softcut.play(sample,1)
      sample_track[sample].playing = true
    end
    local duration = sample_track[sample].end_point - softcut_offsets[sample]
    local s_p = softcut_offsets[sample]
    local sc_start_point_base = (s_p+(duration/16) * (slice-1))
    local sc_end_point_base = (s_p+(duration/16) * (slice)) - clip[sample].fade_time
    softcut.loop_start(sample,sc_start_point_base)
    softcut.loop_end(sample,sc_end_point_base)
    softcut.position(sample,sample_track[sample].reverse and sc_end_point_base or sc_start_point_base)
  end
end

return ca