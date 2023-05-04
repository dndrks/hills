local key_actions = {}

function key_actions.parse(n,z)
  if ui.control_set == 'step parameters' then
    _fkprm.key(n,z)
  elseif ui.control_set == 'poly parameters' then
    _polyparams.key(n,z)
  else
    if z == 1 then
      local s_c = ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]
      local i = ui.hill_focus
      local j = hills[i].screen_focus
      if n == 1 then
        if ui.control_set == 'edit' then
          key1_hold = not key1_hold
        else
          key1_hold = true
        end
      elseif n == 2 then
        if not key1_hold then
          if ui.control_set == "edit" or ui.control_set == 'play' then
            key2_hold_counter:start()
          end
        else
          if ui.control_set == "edit" then
            if ui.menu_focus == 1 then
            elseif ui.menu_focus == 3 then
              -- _t.mute(i,j,s_c.notes.focus)
            elseif ui.menu_focus == 5 then
              _t.toggle_loop(i,j,s_c.samples.focus)
            end
          end
        end
      elseif n == 3 then
        if ui.control_set == "play" then
          if key2_hold and not key1_hold then
            _fkprm.flip_to_fkprm('play')
          else
            ui.control_set = "edit"
            if hills[i].highway == false then
              if ui.menu_focus == 3 then
                if s_c["notes"]["focus"] < hills[i][j].low_bound.note then
                  s_c["notes"]["focus"] = hills[i][j].low_bound.note
                elseif s_c["notes"]["focus"] > hills[i][j].high_bound.note then
                  s_c["notes"]["focus"] = hills[i][j].high_bound.note
                end
              end
            end
          end
        elseif ui.control_set == 'edit' then
          if key2_hold and not key1_hold then
            _fkprm.flip_to_fkprm('edit')
          else
            if hills[i].highway == false then
              if not key1_hold and not key2_hold then
                _a.start(i,j,true)
              elseif key1_hold and not key2_hold then
                if ui.menu_focus == 1 then
                  if _s.popup_focus[1] == 1 then
                    _t.reseed(i,j,0.1)
                  elseif _s.popup_focus[1] == 2 then
                    _t.quantize(i,j,params:string("hill "..i.." quant value"),hills[i][j].low_bound.note,hills[i][j].high_bound.note)
                  end
                elseif ui.menu_focus == 3 then
                  -- if _s.popup_focus[3] == 3 then
                  --   _t[s_c["notes"]["transform"]](i,j,hills[i][j].low_bound.note,hills[i][j].high_bound.note,s_c.notes.focus)
                  -- end
                  _t[s_c["notes"]["transform"]](i,j,hills[i][j].low_bound.note,hills[i][j].high_bound.note,s_c.notes.focus)
                elseif ui.menu_focus == 5 then
                  _t[s_c["samples"]["transform"]](i,j,hills[i][j].low_bound.note,hills[i][j].high_bound.note,s_c.samples.focus,true)
                end
              end
            else
              if ui.menu_focus == 2 then
                if key1_hold and _s.popup_focus.tracks[i][2] == 4 then
                  _htracks.generate_er(i,j)
                end
              elseif ui.menu_focus == 3 then
                _htracks.reset_note_to_default(i,j)
              end
            end
          end
        elseif ui.control_set == 'step parameters' and hills[i].highway == false then
          ui.control_set = 'edit'
        elseif ui.control_set == "seq" and hills[i].highway == false then
          if ui.seq_menu_layer == "edit" then
            ui.seq_menu_layer = "deep_edit"
          elseif ui.seq_menu_layer == "nav" then
            ui.seq_menu_layer = "edit"
          end
        end
      end
    elseif z == 0 then
      if n == 1 and ui.control_set ~= 'edit' then
        key1_hold = false
      elseif n == 2 and not ignore_key2_up then
        if key2_hold == false then
          key2_hold_counter:stop()
          if key1_hold then
            key1_hold = false
          else
            ui.control_set = ui.control_set ~= 'play' and 'play' or 'song'
          end
          if key1_hold and ui.control_set ~= 'edit' then
            key1_hold = false
          end
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