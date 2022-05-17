local screen_actions = {}

function screen_actions.draw()
  local hf = ui.hill_focus
  local h = hills[hf]
  screen.level(15)
  screen.move(0,10)
  screen.aa(1)
  screen.font_size(10)
  -- local hill_names = {"A","B","C","D","E","F","G","H"}
  screen.text(hill_names[ui.hill_focus])
  screen.fill()
  screen.aa(0)
  if ui.control_set ~= "seq" then
    local focus = h.screen_focus
    local seg = h[focus]
    local sorted = _t.deep_copy(hills[hf][focus].note_num.pool)
    table.sort(sorted)
    -- local peak_pitch = sorted[#sorted]
    local peak_pitch = util.clamp(seg.note_num.max,1,#seg.note_ocean)
    screen.level(1)
    screen.rect(40,15,80,40)
    screen.fill()
    local s_c = ui.screen_controls[hf][focus]
    for i = hills[hf][focus].low_bound.note,hills[hf][focus].high_bound.note do
      local horizontal = util.linlin(hills[hf][focus].note_timestamp[hills[hf][focus].low_bound.note], hills[hf][focus].note_timestamp[hills[hf][focus].high_bound.note],40,120,hills[hf][focus].note_timestamp[i])
      local vertical = util.linlin(hills[hf][focus].note_ocean[1],hills[hf][focus].note_ocean[peak_pitch],55,15,hills[hf][focus].note_ocean[hills[hf][focus].note_num.pool[i]])
      if ui.control_set == "edit" and (ui.menu_focus == 1 or ui.menu_focus == 3) then
        if ui.menu_focus == 1 then
          screen.level(s_c["hills"]["focus"] == i and 15 or (seg.index-1 == i and (hills[hf][focus].note_num.active[i] and 10 or 2) or (hills[hf][focus].note_num.active[i] and 3 or 0)))
        elseif ui.menu_focus == 3 then
          screen.level(s_c["notes"]["focus"] == i and 15 or (seg.index-1 == i and (hills[hf][focus].note_num.active[i] and 10 or 2) or (hills[hf][focus].note_num.active[i] and 3 or 0)))
        end
      else
        screen.level(seg.index-1 == i and (hills[hf][focus].note_num.active[i] and 10 or 2) or (hills[hf][focus].note_num.active[i] and 3 or 0))
      end
      if hills[hf][focus].note_timedelta[i] > hills[hf][focus].duration/#hills[hf][focus].note_num.pool then
        screen.circle(horizontal+util.round_up(hills[hf][focus].note_timedelta[i]*2),vertical,util.round_up(hills[hf][focus].note_timedelta[i]*2))
      elseif hills[hf][focus].note_timedelta[i] < (hills[hf][focus].duration/#hills[hf][focus].note_num.pool)/2 then
        screen.pixel(horizontal,vertical)
      else
        screen.rect(horizontal,vertical,util.round_up(hills[hf][focus].note_timedelta[i]*2),8)
      end
      screen.stroke()
    end
    if ui.control_set == "edit" then
      screen.font_size(8)
      if ui.menu_focus == 1 then
        screen.level(s_c["loop"]["focus"] == 1 and (key1_hold and 3 or 15) or 3)
        screen.move(120,10)
        local duration_marker;
        local current_focus = s_c.hills.focus
        if current_focus < tab.count(seg.note_timestamp) then
          duration_marker = seg.note_timestamp[current_focus+1] - seg.note_timestamp[current_focus]
          screen.text_right("step duration: "..string.format("%0.6g",duration_marker))
        else
          screen.text_right("total duration: "..string.format("%0.6g",seg.note_timestamp[current_focus] - seg.note_timestamp[1]))
        end
        if key1_hold then
          screen.level(15)
          screen.move(0,64)
          screen.text("K2: SEED ("..util.round(seg.population*100).."%)")
          screen.move(128,64)
          screen.text_right("K3: QUANT "..params:string("hill "..hf.." quant value"))
        end
      elseif ui.menu_focus == 2 then
        screen.level(s_c["bounds"]["focus"] == 1 and 15 or 3)
        screen.move(40,10)
        screen.text("min: "..seg.low_bound.note)
        screen.level(s_c["bounds"]["focus"] == 1 and 3 or 15)
        screen.move(120,10)
        screen.text_right("max: "..seg.high_bound.note)
      elseif ui.menu_focus == 3 then
        screen.level(key1_hold == true and 3 or 15)
        screen.move(40,10)
        local note_number = seg.note_ocean[seg.note_num.pool[s_c["notes"]["focus"]]]
        screen.text(
          note_number.."/"..mu.note_num_to_name(note_number)..
          (hills[hf][focus].note_num.active[ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]["notes"]["focus"]] and "" or " (m)")
          .." | slice: "..(util.wrap(note_number - params:get("hill "..hf.." base note"),0,15) + 1)
        )
        if key1_hold then
          screen.level(key1_hold == true and 15 or 3)
          screen.move(0,64)
          screen.text("K2: "..(hills[hf][focus].note_num.active[ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]["notes"]["focus"]] and "mute" or "un-mute"))
          screen.move(128,64)
          screen.text_right("K3: "..ui.screen_controls[hf][focus]["notes"]["transform"])
        end
      elseif ui.menu_focus == 4 then
        screen.level(s_c["loop"]["focus"] == 1 and (key1_hold and 3 or 15) or 3)
        screen.move(40,10)
        screen.text("rate: "..util.round(seg.counter_div,0.01).."x")
        screen.level(s_c["loop"]["focus"] == 1 and 3 or (key1_hold and 3 or 15))
        screen.move(120,10)
        screen.text_right("∞: "..(tostring(seg.loop) == "true" and "on" or "off"))
        if key1_hold then
          screen.level(15)
          screen.move(128,64)
          screen.text_right("RESET: "..(seg.looper.mode == "phase" and "PHASE" or "CLOCK ("..seg.looper.clock_time.." beats)"))
        end
      end
    end
    local menus = {"hill: "..focus,"bound","notes","loop"}
    screen.font_size(8)
    if ui.control_set == "edit" and ui.menu_focus ~= 1 then
      screen.move(0,25)
      screen.level(3)
      screen.text("hill: "..focus)
    end
    for i = 1,4 do
      screen.level(ui.menu_focus == i and 15 or 3)
      screen.move(0,15+(10*i))
      if ui.control_set == "edit" and ui.menu_focus == i then
        screen.text("["..menus[i].."]")
      elseif ui.control_set ~= "edit" then
        screen.text(menus[i])
      end
    end
  else
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
      local mods = _p.get_mod(hf,current_focus)
      if #mods ~= 0 then
        for i = 1,#mods do
          screen.move(128,0+(i*8))
          screen.text_right(mods[i])
        end
      end
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
        screen.text(step_seq[hf].steps.event[i] ~= 0 and step_seq[hf].steps.event[i] or "-")
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