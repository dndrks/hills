local screen_actions = {}

function draw_popup(text,x,y)
  screen.rect(7,11,113,44)
  screen.level(15)
  screen.fill()
  screen.rect(8,12,111,42)
  screen.level(0)
  screen.fill()
  if util.string_starts(text, '/home') then
    screen.display_png(text,x,y)
    screen.fill()
  else
    screen.font_size(15)
    screen.level(15)
    screen.move(14,34)
    screen.text(text)
    screen.font_size(8)
  end
end

function draw_small_popup()
  screen.rect(1,34,125,27)
  screen.level(15)
  screen.fill()
  screen.rect(2,35,123,25)
  screen.level(0)
  screen.fill()
end

function draw_prepop(text)
  -- screen.rect(7,11,113,44)
  screen.rect(31,2,94,9)
  screen.level(15)
  screen.fill()
  -- screen.rect(8,12,111,42)
  screen.rect(32,3,92,7)
  screen.level(0)
  screen.fill()
  screen.level(15)
  -- screen.move(64,30)
  screen.move(33,9)
  screen.text(text)
end

screen_actions.popup_focus = {1,1,1,1,1,1,1,1,1,1}
screen_actions.popup_focus.tracks = {}
for i = 1,number_of_hills do
  screen_actions.popup_focus.tracks[i] = {}
  for j = 1,5 do
    screen_actions.popup_focus.tracks[i][j] = 1
  end
end

function screen_actions.draw()
  local hf = ui.hill_focus
  local h = hills[hf]
  -- screen.level(15)
  screen.move(0,10)
  -- screen.aa(1)
  -- screen.font_size(10)
  -- local hill_names = {"A","B","C","D","E","F","G","H"}
  screen.color(192,util.linlin(1,7,108,255,ui.hill_focus),128,255)
  screen.text(hill_names[ui.hill_focus])
  -- screen.fill()
  -- screen.aa(0)
  if ui.control_set ~= "seq" then
    if ui.control_set ~= 'step parameters' and ui.control_set ~= 'poly parameters' then
      local focus = h.screen_focus
      local seg = h[focus]
      local peak_pitch = util.clamp(seg.note_num.max,1,#h.note_ocean)
      screen.level(1)
      -- backdrop //
      screen.move(40,15)
      screen.color(92, 71, 47,120)
      screen.rect_fill(80,40)
      -- //
      -- screen.fill()
      local s_c = ui.screen_controls[hf][focus]
      local iter_index = seg.index-1 ~= 0 and seg.index-1 or nil
      for i = hills[hf][focus].low_bound.note,hills[hf][focus].high_bound.note do
        local horizontal = util.linlin(hills[hf][focus].note_timestamp[hills[hf][focus].low_bound.note], hills[hf][focus].note_timestamp[hills[hf][focus].high_bound.note],40,120,hills[hf][focus].note_timestamp[i])
        local vertical = util.linlin(hills[hf].note_ocean[1],hills[hf].note_ocean[peak_pitch],55,15,hills[hf].note_ocean[hills[hf][focus].note_num.pool[i]])
        local screen_level
        if ui.control_set == "edit" and (ui.menu_focus == 1 or ui.menu_focus == 3 or ui.menu_focus == 5) then
          if ui.menu_focus == 1 then
            screen_level = s_c["hills"]["focus"] == i and 15 or (iter_index == i and (hills[hf][focus].note_num.active[i] and 10 or 2) or (hills[hf][focus].note_num.active[i] and 3 or 0))
          elseif ui.menu_focus == 3 then
            screen_level = s_c["notes"]["focus"] == i and 15 or (iter_index == i and (hills[hf][focus].note_num.active[i] and 10 or 2) or (hills[hf][focus].note_num.active[i] and 3 or 0))
          elseif ui.menu_focus == 5 then
            screen_level = s_c["samples"]["focus"] == i and 15 or (iter_index == i and (hills[hf][focus].note_num.active[i] and 10 or 2) or (hills[hf][focus].note_num.active[i] and 3 or 0))
          end
        else
          -- print(seg.index, iter_index)
          screen_level = iter_index == i and (hills[hf][focus].note_num.active[i] and 10 or 2) or (hills[hf][focus].note_num.active[i] and 3 or 0)
        end
        if ui.control_set == "edit" and ui.menu_focus == 1 and ui.screen_controls[hf][focus].hills.focus == i then
          screen_level = 15
        elseif ui.control_set == "edit" and ui.menu_focus == 3 and ui.screen_controls[hf][focus].notes.focus == i then
          screen_level = 15
        end
        if hills[hf][focus].note_timedelta[i] > hills[hf][focus].duration/#hills[hf][focus].note_num.pool then
          if screen_level == 15 then
            screen.color(255,255,255)
          elseif screen_level == 10 then
            screen.color(156, 196, 193)
          else
            screen.color(196, 156, 159)
          end
          -- print(".>>>"..horizontal+util.round_up(hills[hf][focus].note_timedelta[i]*2),vertical,util.round_up(hills[hf][focus].note_timedelta[i]*2))
          draw_circle(horizontal+util.round_up(hills[hf][focus].note_timedelta[i]*2),vertical,util.round_up(hills[hf][focus].note_timedelta[i]*2))
        elseif hills[hf][focus].note_timedelta[i] < (hills[hf][focus].duration/#hills[hf][focus].note_num.pool)/2 then
          if screen_level == 15 then
            screen.color(255,255,255)
          elseif screen_level == 10 then
            screen.color(156, 196, 193)
          else
            screen.color(206, 166, 112)
          end
          screen.pixel(horizontal,vertical)
        else
          if screen_level == 15 then
            screen.color(255,255,255)
          elseif screen_level == 10 then
            screen.color(156, 196, 193)
          else
            screen.color(64, 108, 184)
          end
          screen.rect(horizontal,vertical,util.round_up(hills[hf][focus].note_timedelta[i]*2),8)
					screen.color(110, 103, 219, 30)
					for j = -2, 1 do
						for k = 1, 8, 2 do
							screen.move(horizontal + j, vertical + k)
							screen.line_rel(1, 0)
						end
					end
        end
      end
      local menus = {"hill: "..focus,"bound","notes","loop","smpl"}
      screen.font_size(8)
      if ui.control_set == "edit" and ui.menu_focus ~= 1 then
        screen.move(0,22)
        screen.level(3)
        screen.text("hill: "..focus)
      end
      local upper_bound
      if ui.hill_focus <= 7 then
				upper_bound = 4
      else
        upper_bound = 5
      end
      for i = 1,upper_bound do
        screen.level(ui.menu_focus == i and (key1_hold and ((ui.menu_focus > 2 and  ui.control_set == "edit") and 3 or 15) or 15) or 3)
        screen.move(0,12+(10*i))
        if ui.control_set == "edit" and ui.menu_focus == i then
          screen.text("["..menus[i].."]")
        elseif ui.control_set ~= "edit" then
          screen.text(menus[i])
        end
      end
      if ui.control_set == 'play' then
        if key2_hold then
          screen.font_size(8)
          screen.level(15)
          screen.move(128,64)
          screen.text_right("K3: PER-STEP PARAMS")
        end
      elseif ui.control_set == "edit" then
        screen.font_size(8)
        if ui.menu_focus == 1 then
          screen.level(s_c["loop"]["focus"] == 1 and (key1_hold and 3 or 15) or 3)
          screen.move(120,5)
          local duration_marker
          local current_focus = s_c.hills.focus
          if current_focus < tab.count(seg.note_timestamp) then
            duration_marker = seg.note_timestamp[current_focus+1] - seg.note_timestamp[current_focus]
            duration_marker = (duration_marker /(32*seg.counter_div)) * clock.get_beat_sec()
            duration_marker = util.round(duration_marker*100,0.001)
            -- screen.text_right("step duration: "..string.format("%0.4g",duration_marker))
            -- screen.text_right("step "..current_focus.." duration: "..string.format("%.0f",duration_marker*100))
            screen.text_right("step "..current_focus.." duration: "..duration_marker.."s")
          else
            -- screen.text_right("total duration: "..string.format("%0.4g",seg.note_timestamp[current_focus] - seg.note_timestamp[1]))
            duration_marker = seg.note_timestamp[current_focus] - seg.note_timestamp[1]
						duration_marker = (duration_marker / (32 * seg.counter_div)) * clock.get_beat_sec()
						duration_marker = util.round(duration_marker * 100, 0.001)
            screen.text_right("total duration: "..duration_marker.."s")
          end
          screen.move(128,36)
          screen.level(key1_hold and 15 or 3)
          screen.text("-> REBUILD")
        elseif ui.menu_focus == 2 then
          screen.level(s_c["bounds"]["focus"] == 1 and 15 or 3)
          screen.move(40,5)
          screen.text("min: "..seg.low_bound.note)
          screen.level(s_c["bounds"]["focus"] == 1 and 3 or 15)
          screen.move(120,5)
          screen.text_right("max: "..seg.high_bound.note)
          screen.move(128, 36)
          screen.level(key1_hold and 15 or 3)
          screen.text("-> SNAP " .. (s_c["bounds"]["focus"] == 1 and "MIN" or "MAX"))
          screen.move(128, 43)
          screen.text("   TO CURRENT POSITON")
          screen.move(128, 50)
          screen.text("   ("..(seg.index-1 ~= 0 and seg.index-1 or 1)..")")
        elseif ui.menu_focus == 3 then
          screen.level(key1_hold == true and 3 or 15)
          screen.move(40,5)
          local note_number = h.note_ocean[seg.note_num.pool[s_c["notes"]["focus"]]] + (seg.note_num.octave_offset[s_c["notes"]["focus"]] * 12)
          if ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus].notes.velocity then
            screen.text(
              note_number.."/"..mu.note_num_to_name(note_number)..
              (hills[hf][focus].note_num.active[ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]["notes"]["focus"]] and "" or " (m)")
              .." | velocity: "..(hills[hf][focus].note_velocity[ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]["notes"]["focus"]])
            )
          else
            local target_sample_voice
            local target_sample_string = ""
            screen.text(
              note_number.."/"..mu.note_num_to_name(note_number)..
              (hills[hf][focus].note_num.active[ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]["notes"]["focus"]] and "" or " (m)")
              ..target_sample_string
            )
          end
          screen.move(128,24)
          screen.level(screen_actions.popup_focus[3] == 1 and (key1_hold and 15) or 4)
          screen.text('velocity: '..(hills[hf][focus].note_velocity[ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]["notes"]["focus"]]))
          screen.move(128,34)
          screen.level(screen_actions.popup_focus[3] == 2 and (key1_hold and 15) or 4)
          screen.text("-> "..ui.screen_controls[hf][focus]["notes"]["transform"])
        elseif ui.menu_focus == 4 then
          screen.level(s_c["loop"]["focus"] == 1 and (key1_hold and 3 or 15) or 3)
          screen.move(40,5)
          screen.text("rate: "..util.round(seg.counter_div,0.01).."x")
          screen.level(s_c["loop"]["focus"] == 1 and 3 or (key1_hold and 3 or 15))
          screen.move(120,5)
          screen.text_right("∞: "..(tostring(seg.loop) == "true" and "on" or "off"))
          screen.level(key1_hold and 15 or 3)
          screen.move(128,64)
          screen.text_right("RESET: "..(seg.looper.mode == "phase" and "PHASE" or "CLOCK ("..seg.looper.clock_time.." beats)"))
        elseif ui.menu_focus == 5 then
          screen.level(key1_hold == true and 3 or 15)
          screen.move(40,5)
          local note_number = seg.sample_controls.rate[s_c["samples"]["focus"]]
          local slice_number = h.note_ocean[seg.note_num.pool[s_c["notes"]["focus"]]]
          screen.text(
            sample_speedlist[note_number].."x"..
            " | "..(hills[hf][focus].sample_controls.loop[ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]["samples"]["focus"]] and "LOOP" or "ONCE")
          )
          if key1_hold then
            screen.level(key1_hold == true and 15 or 3)
            screen.move(20,64)
            screen.text("K2: "..((seg.sample_controls.loop[s_c["samples"]["focus"]]) and "ONCE" or "LOOP"))
            screen.move(128,64)
            if ui.screen_controls[hf][focus]["samples"]["transform"] ~= "rand rate" and
            ui.screen_controls[hf][focus]["samples"]["transform"] ~= "rand loop" and
            ui.screen_controls[hf][focus]["samples"]["transform"] ~= "static rate" and
            ui.screen_controls[hf][focus]["samples"]["transform"] ~= "static loop" then
              screen.text_right("K3: "..ui.screen_controls[hf][focus]["samples"]["transform"].." rate")
            else
              screen.text_right("K3: "..ui.screen_controls[hf][focus]["samples"]["transform"])
            end
          end
        end

        if key2_hold then
          screen.font_size(8)
          screen.level(15)
          screen.move(128,64)
          screen.text_right("K3: PER-STEP PARAMS")
        end
      end
    elseif ui.control_set == 'step parameters' then
      _fkprm.redraw()
    end
  elseif ui.control_set == 'seq' then
    local menus = {"step","rec","tport"}
    local current_focus = ui.seq_controls[hf]["seq"]["focus"]
    screen.font_size(8)
    for i = 1,#menus do
      screen.level(ui.seq_menu_focus == i and 15 or 3)
      screen.move(0,15+(10*i))
      if (ui.seq_menu_layer == "edit" or ui.seq_menu_layer == "deep_edit") and ui.seq_menu_focus == i then
        screen.text("["..menus[i].."]")
      elseif ui.seq_menu_layer ~= "edit" and ui.seq_menu_layer ~= "deep_edit" then
        screen.text(menus[i])
      end
    end
    if ui.seq_menu_layer ~= "deep_edit" then
      -- local mods = _p.get_mod(hf,current_focus)
      -- if #mods ~= 0 then
      --   for i = 1,#mods do
      --     screen.move(128,0+(i*8))
      --     screen.text_right(mods[i])
      --   end
      -- end
    end
    if ui.seq_menu_focus == 1 then
      local chunk = step_seq[hf].active_chunk
      local s_p = step_seq[hf].chunks[chunk][1]
      local e_p = step_seq[hf].chunks[chunk][2]
      for i = s_p,e_p do
        screen.move(40+(index_to_grid_pos(i,8)[1]-1)*8,15+(8*index_to_grid_pos(i,8)[2]))
        if ui.seq_menu_layer == "edit" or ui.seq_menu_layer == "deep_edit" then
          screen.level(current_focus == i and 15 or (step_seq[hf].steps.current == i and 6 or 2))
        elseif ui.seq_menu_layer == "nav" then
          screen.level(step_seq[hf].steps.current == i and 6 or 2)
        end
        screen.text_center(step_seq[hf].steps.event[i] ~= 0 and step_seq[hf].steps.event[i] or "-")
      end
      if ui.seq_menu_layer == "deep_edit" then
        local deep_edits = {"PROB", "A", "B"}
        local deep_positions = {{128,8},{104,16},{128,16}}
        local deep_displays = {step_seq[hf].steps.probability[current_focus],step_seq[hf].steps.A[current_focus],step_seq[hf].steps.B[current_focus]}
        for i = 1,#deep_edits do
          screen.move(deep_positions[i][1],deep_positions[i][2])
          screen.level(ui.seq_controls[hf]["trig_detail"]["focus"] == i and 15 or 3)
          screen.text_right(deep_edits[i]..": "..deep_displays[i])
        end
        screen.move(70,12)
        screen.level(15)
        local k1 = tostring(key1_hold) == "true" and "(all)" or ""
        screen.text(k1)
      end
    end
  end
end

return screen_actions