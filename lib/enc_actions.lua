local enc_actions = {}

function enc_actions.delta_track_pos(i,j,d)
  track[i][j].ui_position = util.clamp(track[i][j].ui_position + d, 1, 128)
  highway_ui.seq_page[i] = math.ceil(track[i][j].ui_position/32)
end

function enc_actions.parse(n,d)
  if ui.control_set == 'step parameters' then
    _fkprm.enc(n,d)
  else
    local s_c = ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]
    local i = ui.hill_focus
    local j = hills[i].screen_focus
    local s_q = ui.seq_controls[i]
    if n == 1 then
      if ui.control_set == 'play' then
        ui.hill_focus = util.clamp(ui.hill_focus+d,1,number_of_hills)
        if ui.hill_focus < 8 then
          if ui.menu_focus == 5 then
            ui.menu_focus = 4
          end
        end
        highway_ui.seq_page[i] = math.ceil(track[i][j].ui_position/32)
      elseif ui.control_set == 'edit' then
        if hills[i].highway and key1_hold then
          enc_actions.delta_track_pos(i,j,d)
        else
          hills[i].screen_focus = util.clamp(j+d,1,8)
          if mods["hill"] then
            grid_dirty = true
          end
          highway_ui.seq_page[i] = math.ceil(track[i][hills[i].screen_focus].ui_position/32)
        end
      end
    elseif n == 2 then
      if ui.control_set == "play" then
        if params:string("hill "..i.." sample output") == "yes" then
          ui.menu_focus = util.clamp(ui.menu_focus+d,1,5)
        else
          ui.menu_focus = util.clamp(ui.menu_focus+d,1,ui.hill_focus <= 7 and 4 or 5)
        end
      elseif ui.control_set == "edit" then
        if hills[i].highway == false then
          if ui.menu_focus == 1 then
            if not key1_hold then
              s_c["hills"]["focus"] = util.clamp(s_c["hills"]["focus"]+d,hills[i][j].low_bound.note,hills[i][j].high_bound.note)
            else
              _s.popup_focus[1] = util.clamp(_s.popup_focus[1]+d,1,2)
            end
          elseif ui.menu_focus == 2 then
            s_c["bounds"]["focus"] = util.clamp(s_c["bounds"]["focus"]+d,1,s_c["bounds"]["max"])
            for _hills = 1,8 do
              ui.screen_controls[ui.hill_focus][_hills]["bounds"]["focus"] = s_c["bounds"]["focus"]
            end
          elseif ui.menu_focus == 3 then
            if not key1_hold then
              s_c["notes"]["focus"] = util.clamp(s_c["notes"]["focus"]+d,hills[i][j].low_bound.note,hills[i][j].high_bound.note)
            else
              _s.popup_focus[3] = util.clamp(_s.popup_focus[3]+d,1,3)
            end
          elseif ui.menu_focus == 4 then
            s_c["loop"]["focus"] = util.clamp(s_c["loop"]["focus"]+d,1,s_c["loop"]["max"])
            for _hills = 1,8 do
              ui.screen_controls[ui.hill_focus][_hills]["loop"]["focus"] = s_c["loop"]["focus"]
            end
          elseif ui.menu_focus == 5 then
            s_c["samples"]["focus"] = util.clamp(s_c["samples"]["focus"]+d,hills[i][j].low_bound.note,hills[i][j].high_bound.note)
            for _hills = 1,8 do
              ui.screen_controls[ui.hill_focus][_hills]["samples"]["focus"] = s_c["samples"]["focus"]
            end
          end
        elseif hills[i].highway then
          if ui.menu_focus == 1 then
            if key1_hold then
              _s.popup_focus.tracks[i][1] = util.clamp(_s.popup_focus.tracks[i][1] + d, 1, 4)
            else
              enc_actions.delta_track_pos(i,j,d)
            end
          elseif ui.menu_focus == 2 then
            if key1_hold then
              _s.popup_focus.tracks[i][2] = util.clamp(_s.popup_focus.tracks[i][2] + d, 1, 4)
            else
              s_c["bounds"]["focus"] = util.clamp(s_c["bounds"]["focus"]+d,1,s_c["bounds"]["max"])
              for _hills = 1,8 do
                ui.screen_controls[ui.hill_focus][_hills]["bounds"]["focus"] = s_c["bounds"]["focus"]
              end
            end
          elseif ui.menu_focus == 3 then
            if key1_hold then
              _s.popup_focus.tracks[i][3] = util.clamp(_s.popup_focus.tracks[i][3] + d, 1, 2)
            else
              enc_actions.delta_track_pos(i,j,d)
            end
          end
        end
      elseif ui.control_set == "seq" then
        if ui.seq_menu_layer == "nav" then
          ui.seq_menu_focus = util.clamp(ui.seq_menu_focus+d,1,4)
        elseif ui.seq_menu_layer == "edit" then
          s_q["seq"]["focus"] = util.clamp(s_q["seq"]["focus"]+d,1,64)
        elseif ui.seq_menu_layer == "deep_edit" then
          s_q["trig_detail"]["focus"] = util.clamp(s_q["trig_detail"]["focus"]+d,1,s_q["trig_detail"]["max"])
        end
      end
    elseif n == 3 then
      if ui.control_set ~= "seq" then
        if hills[i].highway == false then
          if ui.menu_focus == 1 then
            if ui.control_set == "play" then
              hills[i].screen_focus = util.clamp(j+d,1,8)
              if mods["hill"] then
                grid_dirty = true
              end
            elseif ui.control_set == "edit" then
              if not key1_hold then
                _t.nudge(i,j,ui.screen_controls[i][j].hills.focus,d)
              else
                if _s.popup_focus[1] == 1 then
                  hills[i][j].population = util.clamp((hills[i][j].population*100)+d,10,100)/100
                elseif _s.popup_focus[1] == 2 then
                  params:delta("hill "..i.." quant value",d)
                end
              end
            end
          elseif ui.menu_focus == 2 then
            if ui.control_set == "edit" then
              if s_c["bounds"]["focus"] == 1 then
                _t.adjust_hill_start(i,j,d)
              elseif s_c["bounds"]["focus"] == 2 then
                if not key1_hold then
                  _t.adjust_hill_end(i,j,d)
                else
                  _t.snap_bound(i,j)
                end
              end
            end
          elseif ui.menu_focus == 3 then
            if ui.control_set == "edit" then
              if not key1_hold then
                -- if ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus].notes.velocity then
                --   _t.adjust_velocity(i,j,s_c["notes"]["focus"],d)
                -- else
                --   _t.transpose(i,j,s_c["notes"]["focus"],d)
                -- end
                _t.transpose(i,j,s_c["notes"]["focus"],d)
              else
                if _s.popup_focus[3] == 1 then
                  _t.adjust_velocity(i,j,s_c["notes"]["focus"],d)
                elseif _s.popup_focus[3] == 2 then
                  hills[i][j].note_num.chord_degree[s_c["notes"]["focus"]] = util.clamp(hills[i][j].note_num.chord_degree[s_c["notes"]["focus"]]+d, 1, 7)
                elseif _s.popup_focus[3] == 3 then
                  local note_adjustments = {"mute step", "shuffle notes","reverse notes","rotate notes","rand fill notes","static notes","shuffle vel","reverse vel","rotate vel","rand vel","static vel"}
                  local current_adjustment = tab.key(note_adjustments,s_c["notes"]["transform"])
                  s_c["notes"]["transform"] = note_adjustments[util.clamp(current_adjustment+d,1,#note_adjustments)]
                end
              end
            end
          elseif ui.menu_focus == 4 then
            if ui.control_set == "edit" then
              if not key1_hold then
                if s_c["loop"]["focus"] == 1 then
                  hills[i][j].counter_div = util.clamp(hills[i][j].counter_div+d/128,1/128,4)
                elseif s_c["loop"]["focus"] == 2 then
                  hills[i][j].loop = d > 0 and true or false
                end
              else
                hills[i][j].looper.clock_time = util.round(util.clamp(hills[i][j].looper.clock_time + d,0,128))
                if hills[i][j].looper.clock_time == 0 then
                  hills[i][j].looper.mode = "phase"
                else
                  hills[i][j].looper.mode = "clock"
                end
              end
            end
          elseif ui.menu_focus == 5 then
            if ui.control_set == "edit" then
              if not key1_hold then
                _t.sample_transpose(i,j,s_c["samples"]["focus"],d)
              else
                local rate_adjustments = {"shuffle","reverse","rotate","rand rate","static rate","rand loop","static loop"}
                local current_adjustment = tab.key(rate_adjustments,s_c["samples"]["transform"])
                s_c["samples"]["transform"] = rate_adjustments[util.clamp(current_adjustment+d,1,#rate_adjustments)]
              end
            end
          end
        elseif hills[i].highway then
          local _pos = track[i][j].ui_position
          if ui.menu_focus == 1 then
            if ui.control_set == 'edit' then
              if key1_hold then
                if _s.popup_focus.tracks[i][1] == 1 then
                  _hsteps.cycle_conditional(i,j,_pos,d)
                elseif _s.popup_focus.tracks[i][1] == 2 then
                  _hsteps.cycle_prob(i,j,_pos,d)
                elseif _s.popup_focus.tracks[i][1] == 3 then
                  _hsteps.cycle_retrig_count(i,j,_pos,d)
                elseif _s.popup_focus.tracks[i][1] == 4 then
                  _hsteps.cycle_retrig_time(i,j,_pos,d)
                end
              else
                if d > 0 then
                  if track[i][j].trigs[_pos] == false then
                    track[i][j].trigs[_pos] = true
                  end
                else
                  if track[i][j].trigs[_pos] == true then
                    track[i][j].trigs[_pos] = false
                  end
                end
              end
            elseif ui.control_set == 'play' then
              hills[i].screen_focus = util.clamp(j+d,1,8)
              highway_ui.seq_page[i] = math.ceil(track[i][hills[i].screen_focus].ui_position/32)
              if mods["hill"] then
                grid_dirty = true
              end
            end
          elseif ui.menu_focus == 2 and ui.control_set == 'edit' then
            if key1_hold then
              if _s.popup_focus.tracks[i][2] == 1 then
                _hsteps.cycle_er_param('pulses',i,j,d)
              elseif _s.popup_focus.tracks[i][2] == 2 then
                _hsteps.cycle_er_param('steps',i,j,d)
              elseif _s.popup_focus.tracks[i][2] == 3 then
                _hsteps.cycle_er_param('shift',i,j,d)
              end
            else
              if s_c["bounds"]["focus"] == 1 then
                track[i][j].start_point = util.clamp(track[i][j].start_point + d, 1, track[i][j].end_point)
              elseif s_c["bounds"]["focus"] == 2 then
                track[i][j].end_point = util.clamp(track[i][j].end_point + d, track[i][j].start_point, 128)
              end
            end
          elseif ui.menu_focus == 3 and ui.control_set == 'edit' then
            if key1_hold then
              if _s.popup_focus.tracks[i][3] == 1 then
              elseif _s.popup_focus.tracks[i][3] == 2 then
                _hsteps.cycle_chord_degrees(i,j,_pos,d)
              end
            else
              _t.track_transpose(i,j,track[i][j].ui_position,d)
            end
          end
        end
      elseif ui.control_set == "seq" then
        if ui.seq_menu_focus == 1 then
          if ui.seq_menu_layer == "edit" then
            local current_focus = s_q["seq"]["focus"]
            local current_val = _p.get_note(i,current_focus)
            _p.delta_note(i,current_focus,true,d)
          elseif ui.seq_menu_layer == "deep_edit" then
            if ui.seq_controls[i]["trig_detail"]["focus"] == 1 then
              _p.delta_probability(i,s_q["seq"]["focus"],d,key1_hold)
            elseif ui.seq_controls[i]["trig_detail"]["focus"] == 2 then
              _p.delta_conditional(i,s_q["seq"]["focus"],"A",d,key1_hold)
            elseif ui.seq_controls[i]["trig_detail"]["focus"] == 3 then
              _p.delta_conditional(i,s_q["seq"]["focus"],"B",d,key1_hold)
            end
          end
        end
      end
    end
  end
end

function enc_actions.parse_highway(n,d)
  -- _hsteps.process_encoder(n,d)
end

return enc_actions