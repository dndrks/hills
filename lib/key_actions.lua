local key_actions = {}

local function share_aliases()
  local s_c = ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]
  local i = ui.hill_focus
  local j = hills[i].screen_focus
  local s_q = ui.seq_controls[i]
  return {s_c,i,j,s_q}
end

function key_actions.lr_nav(d, modifiers)
  local s_c,i,j,s_q = table.unpack(share_aliases())
  
  if ui.control_set == "play" then
    if hills[i].highway then
      hills[i].screen_focus = util.clamp(j+d,1,#track[i])
    else
      hills[i].screen_focus = util.clamp(j+d,1,8)
    end
    if mods["hill"] then
      grid_dirty = true
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
        -- if key1_hold then
        if check_for_menu_condition(i) then
          _s.popup_focus.tracks[i][1] = util.clamp(_s.popup_focus.tracks[i][1] + d, 1, 5)
        else
          local mod_active
          if #modifiers == 1 and modifiers[1] == "alt" then
            mod_active = true
          end
          _e.delta_track_pos(i,j,d,mod_active)
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
          _e.delta_track_pos(i,j,d)
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
end

function key_actions.ud_nav(d)
  local s_c,i,j,s_q = table.unpack(share_aliases())

  if ui.control_set == "play" then
    if params:string("hill "..i.." sample output") == "yes" then
      ui.menu_focus = util.clamp(ui.menu_focus+d,1,5)
    else
      ui.menu_focus = util.clamp(ui.menu_focus+d,1,ui.hill_focus <= 7 and 4 or 5)
    end
  elseif ui.control_set == "edit" and hills[i].highway == false then
    if ui.menu_focus == 1 then
      if not key1_hold then
        _t.nudge(i,j,ui.screen_controls[i][j].hills.focus,d)
      else
        if _s.popup_focus[1] == 1 then
          hills[i][j].population = util.clamp((hills[i][j].population*100)+d,10,100)/100
        elseif _s.popup_focus[1] == 2 then
          params:delta("hill "..i.." quant value",d)
        end
      end
    elseif ui.menu_focus == 2 then
      if s_c["bounds"]["focus"] == 1 then
        _t.adjust_hill_start(i,j,-d)
      elseif s_c["bounds"]["focus"] == 2 then
        if not key1_hold then
          _t.adjust_hill_end(i,j,-d)
        else
          _t.snap_bound(i,j)
        end
      end
    elseif ui.menu_focus == 3 then
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
    elseif ui.menu_focus == 4 then
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
    elseif ui.menu_focus == 5 then
      if not key1_hold then
        _t.sample_transpose(i,j,s_c["samples"]["focus"],d)
      else
        local rate_adjustments = {"shuffle","reverse","rotate","rand rate","static rate","rand loop","static loop"}
        local current_adjustment = tab.key(rate_adjustments,s_c["samples"]["transform"])
        s_c["samples"]["transform"] = rate_adjustments[util.clamp(current_adjustment+d,1,#rate_adjustments)]
      end
    end
  elseif ui.control_set == "edit" and hills[i].highway then
		d = d * -1
    local _pos = track[i][j].ui_position
    if ui.menu_focus == 1 then
      if ui.control_set == 'edit' then
        -- if key1_hold then
        if check_for_menu_condition(i) then
          if _s.popup_focus.tracks[i][1] == 1 then
            _hsteps.cycle_conditional(i,j,_pos,d)
          elseif _s.popup_focus.tracks[i][1] == 2 then
            _hsteps.cycle_prob(i,j,_pos,d)
          elseif _s.popup_focus.tracks[i][1] == 3 then
            _hsteps.cycle_retrig_count(i,j,_pos,d)
          elseif _s.popup_focus.tracks[i][1] == 4 then
            _hsteps.cycle_retrig_time(i,j,_pos,d)
          elseif _s.popup_focus.tracks[i][1] == 5 then
            _hsteps.cycle_retrig_vel(i,j,_pos,d)
          end
        else
          local _active = track[i][j]
          local _a = _active[highway_ui.seq_page[i]]
          local focused_set = _active.focus == 'main' and _a or _a.fill
          if d > 0 then
            if focused_set.trigs[_pos] == false then
              _htracks.change_trig_state(focused_set,_pos,true,i,j,highway_ui.seq_page[i])
            end
          else
            if focused_set.trigs[_pos] == true then
              _htracks.change_trig_state(focused_set,_pos,false,i,j,highway_ui.seq_page[i])
            end
          end
        end
      elseif ui.control_set == 'play' then
        hills[i].screen_focus = util.clamp(j+d,1,#track[i])
        -- highway_ui.seq_page[i] = math.ceil(track[i][hills[i].screen_focus].ui_position/16)
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
        local _page = track[i][j].page
        if s_c["bounds"]["focus"] == 1 then
          track[i][j][_page].start_point = util.clamp(track[i][j][_page].start_point + d, 1, track[i][j][_page].end_point)
        elseif s_c["bounds"]["focus"] == 2 then
          track[i][j][_page].end_point = util.clamp(track[i][j][_page].end_point + d, track[i][j][_page].start_point, 16)
        end
      end
    elseif ui.menu_focus == 3 and ui.control_set == 'edit' then
      if key1_hold then
        if _s.popup_focus.tracks[i][3] == 1 then
        elseif _s.popup_focus.tracks[i][3] == 2 then
          _hsteps.cycle_chord_degrees(i,j,_pos,d)
        end
      else
        _t.track_transpose(i,j,highway_ui.seq_page[i],track[i][j].ui_position,d)
      end
    end
  end
    
end

function key_actions.parse(char, modifiers, is_repeat, state)
  local s_c,i,j,s_q = table.unpack(share_aliases())
  if ui.control_set == 'step parameters' then
		if (char.name == "up" or char.name == "down") and state == 1 then
			_fkprm.ud_nav(char.name == "up" and -1 or 1, modifiers)
		elseif (char.name == 'right' or char.name == 'left') and state == 1 then
      _fkprm.lr_nav(char.name == 'left' and -1 or 1, modifiers)
    elseif char.name == 'return' then
      _fkprm.key(3,state)
    elseif char.name == 'backspace' then
			_fkprm.key(2, state)
    end
  elseif ui.control_set == 'poly parameters' then
    _polyparams.key(char, modifiers, is_repeat, state)
  else
    if char.name == 'return' and state == 1 then
      if ui.control_set == 'play' then
        ui.control_set = 'edit'
      elseif ui.control_set == 'edit' then
        grid_conditional_entry = not grid_conditional_entry
        if grid_conditional_entry == true then
          print(track[i][j].ui_position)
          -- conditional_entry_steps.focus[i] = {track[i][j].ui_position}
					_g.process_modifier(conditional_entry_steps, track[i][j].ui_position, i, j)
        else
          conditional_entry_steps.focus[i] = {}
        end
      end
    elseif char.name == 'backspace' and state == 1 then
      if ui.control_set == 'edit' then
        ui.control_set = 'play'
      end
    elseif (char.name == 'right' or char.name == 'left') and state == 1 then
      key_actions.lr_nav(char.name == 'left' and -1 or 1, modifiers)
    elseif (char.name == 'up' or char.name == 'down') and state == 1 then
      key_actions.ud_nav(char.name == 'up' and -1 or 1, modifiers)
    end
    -- if z == 1 then
    --   local s_c = ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]
    --   local i = ui.hill_focus
    --   local j = hills[i].screen_focus
    --   if n == 1 then
    --     if ui.control_set == 'edit' then
    --       key1_hold = not key1_hold
    --     else
    --       key1_hold = true
    --     end
    --   elseif n == 2 then
    --     if not key1_hold then
    --       if ui.control_set == "edit" or ui.control_set == 'play' then
    --         key2_hold_counter:start()
    --       end
    --     else
    --       if ui.control_set == "edit" then
    --         if ui.menu_focus == 1 then
    --         elseif ui.menu_focus == 3 then
    --           -- _t.mute(i,j,s_c.notes.focus)
    --         elseif ui.menu_focus == 5 then
    --           _t.toggle_loop(i,j,s_c.samples.focus)
    --         end
    --       end
    --     end
    --   elseif n == 3 then
    --     if ui.control_set == "play" then
    --       if key2_hold and not key1_hold then
    --         _fkprm.flip_to_fkprm('play')
    --       else
    --         ui.control_set = "edit"
    --         if hills[i].highway == false then
    --           if ui.menu_focus == 3 then
    --             if s_c["notes"]["focus"] < hills[i][j].low_bound.note then
    --               s_c["notes"]["focus"] = hills[i][j].low_bound.note
    --             elseif s_c["notes"]["focus"] > hills[i][j].high_bound.note then
    --               s_c["notes"]["focus"] = hills[i][j].high_bound.note
    --             end
    --           end
    --         end
    --       end
    --     elseif ui.control_set == 'edit' then
    --       if key2_hold and not key1_hold then
    --         _fkprm.flip_to_fkprm('edit')
    --       else
    --         if hills[i].highway == false then
    --           if not key1_hold and not key2_hold then
    --             _a.start(i,j,true)
    --           elseif key1_hold and not key2_hold then
    --             if ui.menu_focus == 1 then
    --               if _s.popup_focus[1] == 1 then
    --                 _t.reseed(i,j)
    --               elseif _s.popup_focus[1] == 2 then
    --                 _t.quantize(i,j,params:string("hill "..i.." quant value"),hills[i][j].low_bound.note,hills[i][j].high_bound.note)
    --               end
    --             elseif ui.menu_focus == 3 then
    --               -- if _s.popup_focus[3] == 3 then
    --               --   _t[s_c["notes"]["transform"]](i,j,hills[i][j].low_bound.note,hills[i][j].high_bound.note,s_c.notes.focus)
    --               -- end
    --               _t[s_c["notes"]["transform"]](i,j,hills[i][j].low_bound.note,hills[i][j].high_bound.note,s_c.notes.focus)
    --             elseif ui.menu_focus == 5 then
    --               _t[s_c["samples"]["transform"]](i,j,hills[i][j].low_bound.note,hills[i][j].high_bound.note,s_c.samples.focus,true)
    --             end
    --           end
    --         else
    --           if ui.menu_focus == 1 then
    --             -- print('k3 pressed')
    --             if not grid_conditional_entry then
    --               grid_conditional_entry = true
    --               conditional_entry_steps.focus[i] = {track[i][j].ui_position}
    --             else
    --               grid_conditional_entry = false
    --               conditional_entry_steps.focus[i] = {}
    --             end
    --           elseif ui.menu_focus == 2 then
    --             if key1_hold and _s.popup_focus.tracks[i][2] == 4 then
    --               _htracks.generate_er(i,j,highway_ui.seq_page[i])
    --             end
    --           elseif ui.menu_focus == 3 then
    --             _htracks.reset_note_to_default(i,j)
    --           end
    --         end
    --       end
    --     elseif ui.control_set == 'step parameters' and hills[i].highway == false then
    --       ui.control_set = 'edit'
    --     elseif ui.control_set == "seq" and hills[i].highway == false then
    --       if ui.seq_menu_layer == "edit" then
    --         ui.seq_menu_layer = "deep_edit"
    --       elseif ui.seq_menu_layer == "nav" then
    --         ui.seq_menu_layer = "edit"
    --       end
    --     end
    --   end
    -- elseif z == 0 then
    --   local i = ui.hill_focus
    --   if n == 1 and ui.control_set ~= 'edit' then
    --     key1_hold = false
    --   elseif n == 2 and not ignore_key2_up then
    --     if key2_hold == false then
    --       key2_hold_counter:stop()
    --       if key1_hold then
    --         key1_hold = false
    --       else
    --         ui.control_set = ui.control_set ~= 'play' and 'play' or 'song'
    --         grid_conditional_entry = false
    --         conditional_entry_steps.focus[i] = {}
    --       end
    --       if key1_hold and ui.control_set ~= 'edit' then
    --         key1_hold = false
    --       end
    --     else
    --       key2_hold = false
    --     end
    --   elseif n == 2 and ignore_key2_up then
    --     ignore_key2_up = false
    --     key2_hold = false
    --   end
    -- end
  end
end

return key_actions