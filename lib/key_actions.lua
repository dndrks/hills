local key_actions = {}

function key_actions.parse(n,z)
  if z == 1 then
    local s_c = ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]
    local i = ui.hill_focus
    local j = hills[i].screen_focus
    if n == 1 then
      key1_hold = true
    elseif n == 2 then
      if not key1_hold then
        if ui.control_set == "edit" then
          ui.control_set = "play"
        end
      else
        if ui.control_set == "edit" then
          if ui.menu_focus == 1 then
            _t.reseed(i,j,0.1)
          elseif ui.menu_focus == 3 then
            _t.mute(i,j,s_c.notes.focus)
          end
        end
      end
    elseif n == 3 then
      if ui.control_set == "play" then
        ui.control_set = "edit"
        if ui.menu_focus == 3 then
          if s_c["notes"]["focus"] < hills[i][j].low_bound.note then
            s_c["notes"]["focus"] = hills[i][j].low_bound.note
          elseif s_c["notes"]["focus"] > hills[i][j].high_bound.note then
            s_c["notes"]["focus"] = hills[i][j].high_bound.note
          end
        end
      elseif ui.control_set == "edit" then
        if not key1_hold then
          _a.start(i,j,true)
        else
          if ui.menu_focus == 1 then
            _t.quantize(i,j,params:string("hill "..i.." quant value"),hills[i][j].low_bound.note,hills[i][j].high_bound.note)
          elseif ui.menu_focus == 3 then
            _t[s_c["notes"]["transform"]](i,j,hills[i][j].low_bound.note,hills[i][j].high_bound.note,s_c.notes.focus)
          end
        end
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
    end
  end
end

return key_actions