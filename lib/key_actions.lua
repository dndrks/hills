local key_actions = {}

function key_actions.parse(n,z)
  if ui.control_set == 'step parameters' then
    _fkprm.key(n,z)
  else
    if z == 1 then
      local s_c = ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]
      local i = ui.hill_focus
      local j = hills[i].screen_focus
      if n == 1 then
        key1_hold = true
      elseif n == 2 then
        if not key1_hold then
          if ui.control_set == "edit" or ui.control_set == 'play' then
            key2_hold_counter:start()
          end
        else
          if ui.control_set == "edit" then
            if ui.menu_focus == 1 then
              _t.reseed(i,j,0.1)
            elseif ui.menu_focus == 3 then
              _t.mute(i,j,s_c.notes.focus)
            elseif ui.menu_focus == 5 then
              _t.toggle_loop(i,j,s_c.samples.focus)
            end
          end
        end
      elseif n == 3 then
        if ui.control_set == "play" then
          if key2_hold and not key1_hold then
            if ui.menu_focus == 1 or ui.menu_focus == 3 then
              _fkprm.voice_focus = ui.hill_focus
              _fkprm.hill_focus = hills[ui.hill_focus].screen_focus
              _fkprm.step_focus = ui.screen_controls[_fkprm.voice_focus][_fkprm.hill_focus][ui.menu_focus == 1 and 'hills' or 'notes'].focus
            end
            pre_step_page = 'play'
            ui.control_set = 'step parameters'
          else
            ui.control_set = "edit"
          end
          if ui.menu_focus == 3 then
            if s_c["notes"]["focus"] < hills[i][j].low_bound.note then
              s_c["notes"]["focus"] = hills[i][j].low_bound.note
            elseif s_c["notes"]["focus"] > hills[i][j].high_bound.note then
              s_c["notes"]["focus"] = hills[i][j].high_bound.note
            end
          end
        elseif ui.control_set == "edit" then
          if not key1_hold and not key2_hold then
            if ui.menu_focus ~= 3 then
              _a.start(i,j,true)
            else
              ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus].notes.velocity = not ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus].notes.velocity
            end
          elseif key1_hold and not key2_hold then
            if ui.menu_focus == 1 then
              _t.quantize(i,j,params:string("hill "..i.." quant value"),hills[i][j].low_bound.note,hills[i][j].high_bound.note)
            elseif ui.menu_focus == 3 then
              _t[s_c["notes"]["transform"]](i,j,hills[i][j].low_bound.note,hills[i][j].high_bound.note,s_c.notes.focus)
            elseif ui.menu_focus == 5 then
              _t[s_c["samples"]["transform"]](i,j,hills[i][j].low_bound.note,hills[i][j].high_bound.note,s_c.samples.focus,true)
            end
          elseif key2_hold and not key1_hold then
            if ui.menu_focus == 1 or ui.menu_focus == 3 then
              _fkprm.voice_focus = ui.hill_focus
              _fkprm.hill_focus = hills[ui.hill_focus].screen_focus
              _fkprm.step_focus = ui.screen_controls[_fkprm.voice_focus][_fkprm.hill_focus][ui.menu_focus == 1 and 'hills' or 'notes'].focus
            end
            pre_step_page = 'edit'
            ui.control_set = 'step parameters'
          end
        elseif ui.control_set == 'step parameters' then
          ui.control_set = 'edit'
        elseif ui.control_set == "seq" then
          if ui.seq_menu_layer == "edit" then
            ui.seq_menu_layer = "deep_edit"
          elseif ui.seq_menu_layer == "nav" then
            ui.seq_menu_layer = "edit"
          end
        end
      end
    elseif z == 0 then
      if n == 1 then
        key1_hold = false
      elseif n == 2 and not ignore_key2_up then
        if key2_hold == false then
          key2_hold_counter:stop()
          ui.control_set = ui.control_set ~= 'play' and 'play' or 'song'
        else
          key2_hold = false
        end
      elseif n == 2 and ignore_key2_up then
        ignore_key2_up = false
        key2_hold = false
      end
    end
  end
end

return key_actions