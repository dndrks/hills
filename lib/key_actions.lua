local key_actions = {}

function key_actions.parse(n,z)
  if z == 1 then
    local s_c = ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]
    local i = ui.hill_focus
    local j = hills[i].screen_focus
    if n == 1 then
      key1_hold = true
    elseif n == 2 then
      if ui.control_set == "edit" then
        ui.control_set = "play"
      elseif ui.control_set == "play" then
        ui.control_set = "seq"
      elseif ui.control_set == "seq" then
        if ui.seq_menu_layer == "nav" then
          ui.control_set = "play"
        elseif ui.seq_menu_layer == "edit" then
          ui.seq_menu_layer = "nav"
        elseif ui.seq_menu_layer == "deep_edit" then
          ui.seq_menu_layer = "edit"
          ui.seq_controls[ui.hill_focus]["trig_detail"]["focus"] = 1
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
          _a.one_shot(ui.hill_focus,hills[ui.hill_focus].screen_focus)
        else
          if ui.menu_focus == 3 then
            _t[s_c["notes"]["transform"]](i,j,hills[i][j].low_bound.note,hills[i][j].high_bound.note)
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
  screen_dirty = true
end

return key_actions