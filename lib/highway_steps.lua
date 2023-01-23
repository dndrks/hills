local hway_ui = {}

local _hui;

local snake_styles;

function hway_ui.init()
  
  highway_ui = {}
  highway_ui.focus = "seq" -- "params" or "seq"
  highway_ui.sel = 1
  highway_ui.hill_sel = 1
  highway_ui.alt = false
  highway_ui.param = 1
  highway_ui.seq_position = {1,1,1,1,1,1,1,1,1,1}
  highway_ui.seq_page = {1,1,1,1,1,1,1,1,1,1}
  highway_ui.alt_view_sel = 1
  highway_ui.alt_fill_sel = 1
  highway_ui.fill = {}
  -- highway_ui.fill.start_point = {1,1,1,1,1,1,1,1,1,1}
  -- highway_ui.fill.end_point = {16,16,16,16,16,16,16,16,16,16}
  -- highway_ui.fill.snake = 1
  _hui = highway_ui
end

local function check_for_menu_condition(i)
  if (key1_hold or (#conditional_entry_steps.focus[i] > 0)) and ui.control_set == 'edit' then
    return true
  else
    return false
  end
end

function hway_ui.draw_menu()

  local hf = ui.hill_focus
  local h = hills[hf]
  local _active = track[hf][h.screen_focus]
  screen.level(15)
  screen.move(0,10)
  screen.aa(1)
  screen.font_size(10)
  -- local hill_names = {"A","B","C","D","E","F","G","H"}
  screen.text(hill_names[ui.hill_focus])
  screen.fill()
  screen.aa(0)
  if ui.control_set ~= "seq" then
    if ui.control_set ~= 'step parameters' and ui.control_set ~= 'poly parameters' then
      local focus = h.screen_focus
      local seg = h[focus]
      screen.level(1)
      screen.rect(31,15,97,40)
      screen.fill()
      local s_c = ui.screen_controls[hf][focus]
      local iter_index = seg.index-1 ~= 0 and seg.index-1 or hills[hf][focus].high_bound.note
      local menus = {"hwy: "..focus,"bound","notes","loop","smpl"}
      screen.font_size(8)
      if ui.control_set == "edit" and ui.menu_focus ~= 1 then
        screen.move(0,22)
        screen.level(3)
        screen.text("hwy: "..focus)
      end
      local upper_bound;
      if ui.hill_focus <= 7 then
        if params:string("hill "..ui.hill_focus.." sample output") == "yes" then
          upper_bound = 5
        else
          upper_bound = 4
        end
      else
        upper_bound = 5
      end
      for i = 1,upper_bound do
        screen.level(ui.menu_focus == i and (key1_hold and ((ui.menu_focus > 2 and  ui.control_set == "edit") and 3 or 15) or 15) or 3)
        screen.move(0,12+(10*i))
        if ui.control_set == "edit" and ui.menu_focus == i then
          if h.highway == true then
            screen.text(menus[i])
          else
            screen.text("["..menus[i].."]")
          end
        elseif ui.control_set ~= "edit" then
          screen.text(menus[i])
        end
      end

      -- new drawing stuff //
      local focus_arp = _active
      local focused_set = _active.focus == "main" and _active or _active.fill
      screen.move(0,10)
      screen.level(3)
      screen.level(_hui.focus == "seq" and 8 or 0)
      local e_pos = track[hf][h.screen_focus].ui_position
      screen.rect(31+(hway_ui.index_to_grid_pos(e_pos,8)[1]-1)*12,6+(10*hway_ui.index_to_grid_pos(e_pos,8)[2]),13,8)
      screen.fill()
      local min_max = {{1,32},{33,64},{65,96},{97,128}}
      local lvl = 5
      screen.font_face(2)
      for i = min_max[_hui.seq_page[hf]][1], min_max[_hui.seq_page[hf]][2] do
        if e_pos == i then
          if _active.step == i and _active.playing then
            lvl = _hui.focus == "seq" and 5 or 4
          else
            lvl = _hui.focus == "seq" and 0 or 2
          end
        else
          if i <= _active.end_point and i >= _active.start_point then
            if _active.step == i then
              lvl = _hui.focus == "seq" and 15 or 4
            else
              lvl = _hui.focus == "seq" and 5 or 2
            end
          else
            lvl = 0
          end
        end
        screen.level(lvl)
        screen.move(37+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,13+(10*hway_ui.index_to_grid_pos(i,8)[2]))
        local display_step_data
        if ui.menu_focus ~= 3 then
          display_step_data = focused_set.trigs[i] == true and (focused_set.muted_trigs[i] and 'M' or '|') or '-'
        else
          local note_index = focused_set.base_note[i]
          if focused_set.trigs[i] == true then
            if focused_set.base_note[i] == -1 then
              local note_check = params:string('voice_model_'..hf) ~= 'sample' and params:get(hf..'_'..params:string('voice_model_'..hf)..'_carHz')
                or params:get('hill '..hf..' base note')
              display_step_data = note_check
            else
              display_step_data = note_index
            end
          else
            display_step_data = '-'
          end
        end

        if highway_ui.alt and _hui.focus == "params" then
          local first;
          local second = display_step_data
          local third;
          if _hui.fill.start_point[_hui.sel] == i then
            first = "["
          else
            first = ""
          end
          if _hui.fill.end_point[_hui.sel] == i then
            third = "]"
          else
            third = ""
          end
          screen.text_center(first..second..third)
        else
          screen.text_center(display_step_data)
          local note_check = params:string('voice_model_'..hf) ~= 'sample' and params:get(hf..'_'..params:string('voice_model_'..hf)..'_carHz')
            or params:get('hill '..hf..' base note')
          if focused_set.base_note[i] == note_check then
            if e_pos == i then
              screen.level(15)
            else
              screen.level(4)
            end
            screen.move(33+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,15+(10*hway_ui.index_to_grid_pos(i,8)[2]))
            screen.line_rel(9,0)
            screen.stroke()
          end
          if focused_set.prob[i] ~= 100 then
            if focused_set.prob[i] <= 20 then
              for pix = 33,34 do
                screen.pixel(pix+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,12+(10*hway_ui.index_to_grid_pos(i,8)[2]))
              end
            elseif focused_set.prob[i] <= 40 then
              for pix = 33,34 do
                screen.pixel(pix+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,11+(10*hway_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,12+(10*hway_ui.index_to_grid_pos(i,8)[2]))
              end
            elseif focused_set.prob[i] <= 60 then
              for pix = 33,34 do
                screen.pixel(pix+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,10+(10*hway_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,11+(10*hway_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,12+(10*hway_ui.index_to_grid_pos(i,8)[2]))
              end
            elseif focused_set.prob[i] <= 80 then
              for pix = 33,34 do
                screen.pixel(pix+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,9+(10*hway_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,10+(10*hway_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,11+(10*hway_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,12+(10*hway_ui.index_to_grid_pos(i,8)[2]))
              end
            elseif focused_set.prob[i] < 100 then
              for pix = 33,34 do
                screen.pixel(pix+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,8+(10*hway_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,9+(10*hway_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,10+(10*hway_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,11+(10*hway_ui.index_to_grid_pos(i,8)[2]))
                screen.pixel(pix+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,12+(10*hway_ui.index_to_grid_pos(i,8)[2]))
              end
            end
            screen.fill()
          end
          if focused_set.conditional.A[i] ~= 1 or focused_set.conditional.B[i] ~= 1 then
            screen.pixel(40+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,7+(10*hway_ui.index_to_grid_pos(i,8)[2]))
            screen.pixel(42+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,7+(10*hway_ui.index_to_grid_pos(i,8)[2]))
            screen.fill()
          end
          if focused_set.conditional.retrig_count[i] > 0 then
            screen.pixel(41+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,10+(10*hway_ui.index_to_grid_pos(i,8)[2]))
            screen.pixel(42+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,11+(10*hway_ui.index_to_grid_pos(i,8)[2]))
            screen.pixel(41+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,11+(10*hway_ui.index_to_grid_pos(i,8)[2]))
            screen.pixel(40+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,11+(10*hway_ui.index_to_grid_pos(i,8)[2]))
            screen.pixel(41+(hway_ui.index_to_grid_pos(i,8)[1]-1)*12,12+(10*hway_ui.index_to_grid_pos(i,8)[2]))
            screen.fill()
          end
        end
      end
      screen.font_face(1)

      if key2_hold then
        screen.font_size(8)
        screen.level(15)
        screen.move(128,64)
        screen.text_right("K3: PER-STEP PARAMS")
      else
        screen.move(128,64)
        screen.level(3)
        screen.text_right(track[hf][h.screen_focus].ui_position..' / '..min_max[_hui.seq_page[hf]][1]..'-'..min_max[_hui.seq_page[hf]][2])
      end

      if ui.menu_focus == 1 then
        screen.level(15)
        screen.move(31,10)
        if grid_mute then
          screen.text("STEP MUTE")
        elseif grid_accent then
          screen.text("STEP ACCENT")
        elseif grid_loop_modifier then
          if get_loop_modifier_stage() == 'define start' then
            screen.text('SET LOOP START')
          elseif get_loop_modifier_stage() == 'define end' then
            screen.text('SET LOOP END')
          end
        end
        screen.move(128,10)
        screen.text_right(track[hf][h.screen_focus].focus == "fill" and "[FILL]" or "")
      elseif ui.menu_focus == 2 then
        local s_c = ui.screen_controls[hf][h.screen_focus]
        if ui.control_set == 'play' then
          screen.level(3)
        else
          screen.level(s_c["bounds"]["focus"] == 1 and 15 or 3)
        end
        screen.move(32,10)
        screen.text("min: "..track[hf][h.screen_focus].start_point)
        if ui.control_set == 'play' then
          screen.level(3)
        else
          screen.level(s_c["bounds"]["focus"] == 1 and 3 or 15)
        end
        screen.move(128,10)
        screen.text_right("max: "..track[hf][h.screen_focus].end_point)
      elseif ui.menu_focus == 3 then
        if ui.control_set == 'edit' then
          local _active = track[hf][h.screen_focus]
          local pos = _active.ui_position
          local display_text = ''
          local focused_set = _active.focus == "main" and _active or _active.fill
          screen.level(3)
          if focused_set.trigs[pos] == false then
            display_text = 'set note adds trig'
          else
            local note_check = params:string('voice_model_'..hf) ~= 'sample' and params:get(hf..'_'..params:string('voice_model_'..hf)..'_carHz')
              or params:get('hill '..hf..' base note')
            if focused_set.base_note[pos] == note_check then
              display_text = 'K3: clear to default'
            end
          end
          screen.move(40,10)
          screen.text(display_text)
          -- if ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus].notes.velocity then
          --   screen.text(
          --     note_number.."/"..mu.note_num_to_name(note_number)..
          --     (hills[hf][focus].note_num.active[ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]["notes"]["focus"]] and "" or " (m)")
          --     .." | velocity: "..(hills[hf][focus].note_velocity[ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]["notes"]["focus"]])
          --   )
          -- else
          --   local target_sample_voice;
          --   local target_sample_string = "";
          --   if params:string('hill '..hf..' sample output') == "yes" then
          --     target_sample_voice = params:get('hill '..hf..' sample slot')
          --     if params:string('sample'..target_sample_voice..'_sampleMode') == 'distribute' then
          --       if sample_info['sample'..target_sample_voice].sample_count == nil then
          --         target_sample_string = ""
          --       else
          --         local scaled_idx = util.round(sample_info['sample'..target_sample_voice].sample_count * (params:get('hill '..hf..' sample distribution')/100))
          --         target_sample_string = ' | sample: '..(util.wrap(note_number - params:get("hill "..hf.." base note"),0,scaled_idx-1) + 1)
          --       end
          --     elseif params:string('sample'..target_sample_voice..'_sampleMode') == 'chop' then
          --       target_sample_string = ' | slice: '..(util.wrap(note_number - params:get("hill "..hf.." base note"),0,params:get('hill '..hf..' sample slice count') - 1) + 1)
          --     end
          --   end
          --   screen.text(
          --     note_number.."/"..mu.note_num_to_name(note_number)..
          --     (hills[hf][focus].note_num.active[ui.screen_controls[ui.hill_focus][hills[ui.hill_focus].screen_focus]["notes"]["focus"]] and "" or " (m)")
          --     ..target_sample_string
          --   )
          -- end
        end
      end
      
      -- if not highway_ui.alt then
      --   if not key2_hold then
          
      --     local deci_to_frac =
      --     { ["0.125"] = "1/32"
      --     , ["0.1667"] = "1/16t"
      --     , ["0.25"] = "1/16"
      --     , ["0.3333"] = "1/8t"
      --     , ["0.5"] = "1/8"
      --     , ["0.6667"] = "1/4t"
      --     , ["1.0"] = "1/4"
      --     , ["1.3333"] = "1/2t"
      --     , ["2.0"] = "1/2"
      --     , ["2.6667"] = "1t"
      --     , ["4.0"] = "1"
      --     }
      --     screen.move(125,22)
      --     screen.level(_hui.focus == "params" and
      --     (_hui.param == 1 and 15 or 3)
      --     or 3)
      --     local banks = {"a","b","c"}
      --     -- local pad = tostring(banks[_hui.sel]..bank[_hui.sel].id)
      --     local pad = 'nothing'
      --     screen.text_right((_hui.alt and (pad..": ") or "")..deci_to_frac[tostring(util.round(_active.time, 0.0001))])
      --     screen.move(125,32)
      --     screen.level(_hui.focus == "params" and
      --     (_hui.param == 2 and 15 or 3)
      --     or 3)
      --     screen.text_right(focus_arp.mode)
      --     screen.move(125,42)
      --     screen.level(_hui.focus == "params" and
      --     (_hui.param == 3 and 15 or 3)
      --     or 3)
      --     screen.text_right("s: "..focus_arp.start_point)
      --     screen.move(125,52)
      --     screen.level(_hui.focus == "params" and
      --     (_hui.param == 4 and 15 or 3)
      --     or 3)
      --     screen.text_right("e: "..(focus_arp.end_point > 0 and focus_arp.end_point or "1"))
      --     screen.move(125,62)
      --     screen.level(_hui.focus == "params" and
      --     (_hui.param == 5 and 15 or 3)
      --     or 3)
      --     screen.text_right("swing: "..focus_arp.swing.."%")
    
      --   elseif key2_hold then
      --     screen.move(100,22)
      --     screen.level(15)
      --     screen.text("K3:")
      --     screen.font_size(15)
      --     local letters = {{"C","O","P","Y"},{"P","S","T","E"},{"N","O","N","E"}}
      --     for i = 1,4 do
      --       screen.move(114,16+(i*10))
      --       screen.text(arp_clipboard ~= nil and letters[2][i] or letters[1][i])
      --       -- screen.text(tab.count(focused_set.notes) > 0 and (_active.playing and letters[2][i] or letters[1][i]) or letters[3][i])
      --     end
      --     screen.font_size(8)
      --     if arp_clipboard ~= nil then
      --       screen.move(20,62)
      --       if arp_paste_style == 1 then
      --         screen.text(
      --           "E3: paste "
      --           ..("["..header[arp_clipboard_bank_source].."]")
      --           .." to ["..header[_hui.sel].."]"
      --         )
      --       elseif arp_paste_style == 2 then
      --         screen.text(
      --           "E3: paste "
      --           ..("["..header[arp_clipboard_bank_source]..arp_clipboard_pad_source.."] to ["..header[_hui.sel]..track[_hui.sel][_hui.hill_sel].ui_position.."]")
      --         )
      --       elseif arp_paste_style == 3 then
      --         local layer = arp_clipboard_layer_source == "main" and "" or ": F"
      --         screen.text(
      --           "E3: paste "
      --           ..("["..header[arp_clipboard_bank_source]..layer.."] to ["..header[_hui.sel]..(_active.focus == "main" and "" or ": F").."]")
      --         )
      --       end
      --     end
      --   end
      -- elseif highway_ui.alt and _hui.focus == "seq" then
      --   if not key2_hold then
      --     screen.level(10)
      --     screen.rect(98,15,128,9)
      --     screen.fill()
      --     screen.level(0)
      --     screen.move(113,22)
      --     screen.text_center("TRIG")
      --     screen.level(highway_ui.alt_view_sel == 1 and 15 or 3)
      --     screen.move(99,32)
      --     screen.text("P: "..focused_set.prob[track[_hui.sel][_hui.hill_sel].ui_position].."%")
      --     screen.level(highway_ui.alt_view_sel == 2 and 15 or 3)
      --     screen.move(99,42)
      --     if focused_set.conditional.mode[track[_hui.sel][_hui.hill_sel].ui_position] == "A:B" then
      --       screen.text("C: "..focused_set.conditional.A[track[_hui.sel][_hui.hill_sel].ui_position]..
      --       ":"..
      --       focused_set.conditional.B[track[_hui.sel][_hui.hill_sel].ui_position])
      --     else
      --       local base, line_above;
      --       if focused_set.conditional.mode[track[_hui.sel][_hui.hill_sel].ui_position] == "NOT PRE" then
      --         base = "PRE"
      --         line_above = true
      --       elseif focused_set.conditional.mode[track[_hui.sel][_hui.hill_sel].ui_position] == "NOT NEI" then
      --         base = "NEI"
      --         line_above = true
      --       else
      --         base = focused_set.conditional.mode[track[_hui.sel][_hui.hill_sel].ui_position]
      --         line_above = false
      --       end
      --       screen.text("C: "..base)
      --       if line_above then
      --         screen.move(109,36)
      --         screen.line(base == "PRE" and 122 or 121,36)
      --         screen.stroke()
      --       end
      --     end
      --     screen.level(highway_ui.alt_view_sel == 3 and 15 or 3)
      --     screen.move(99,52)
      --     screen.text("R: "..focused_set.conditional.retrig_count[track[_hui.sel][_hui.hill_sel].ui_position].."x")
      --     screen.level(highway_ui.alt_view_sel == 4 and 15 or 3)
      --     screen.move(99,62)
      --     if _active.focus == "main" then
      --       screen.text("T: "..arp_paramset:string("arp_retrig_time_".._hui.sel.."_"..track[_hui.sel][_hui.hill_sel].ui_position))
      --     else
      --       screen.text("T: "..arp_paramset:string("arp_fill_retrig_time_".._hui.sel.."_"..track[_hui.sel][_hui.hill_sel].ui_position))
      --     end
      --     screen.level(15)
      --     screen.move(20,62)
      --     if highway_ui.alt_view_sel == 1 then
      --       screen.text("K3: active -> "..focused_set.prob[track[_hui.sel][_hui.hill_sel].ui_position].."%")
      --     elseif highway_ui.alt_view_sel == 2 then
      --       if focused_set.conditional.mode[track[_hui.sel][_hui.hill_sel].ui_position] == "A:B" then
      --         screen.text("K3: active -> "..focused_set.conditional.A[track[_hui.sel][_hui.hill_sel].ui_position]..
      --         ":"..
      --         focused_set.conditional.B[track[_hui.sel][_hui.hill_sel].ui_position])
      --       else
      --         local base, line_above;
      --         if focused_set.conditional.mode[track[_hui.sel][_hui.hill_sel].ui_position] == "NOT PRE" then
      --           base = "PRE"
      --           line_above = true
      --         elseif focused_set.conditional.mode[track[_hui.sel][_hui.hill_sel].ui_position] == "NOT NEI" then
      --           base = "NEI"
      --           line_above = true
      --         else
      --           base = focused_set.conditional.mode[track[_hui.sel][_hui.hill_sel].ui_position]
      --           line_above = false
      --         end
      --         screen.text("K3: active -> "..base)
      --         if line_above then
      --           screen.move(77,56)
      --           screen.line(base == "PRE" and 90 or 89,56)
      --           screen.stroke()
      --         end
      --       end
      --     elseif highway_ui.alt_view_sel == 3 then
      --       screen.text("K3: active -> "..focused_set.conditional.retrig_count[track[_hui.sel][_hui.hill_sel].ui_position].."x")
      --     elseif highway_ui.alt_view_sel == 4 then
      --       local focused_param = _active.focus == "main" and "arp_retrig_time_" or "arp_fill_retrig_time_"
      --       screen.text("K3: active -> "..arp_paramset:string(focused_param.._hui.sel.."_"..track[_hui.sel][_hui.hill_sel].ui_position))
      --     end
      --   end
      -- elseif highway_ui.alt and _hui.focus == "params" then
      --   if not key2_hold then
      --     screen.level(10)
      --     screen.rect(98,15,128,9)
      --     screen.fill()
      --     screen.level(0)
      --     screen.move(113,22)
      --     screen.text_center("FILL")
      --     screen.level(highway_ui.alt_fill_sel == 1 and 15 or 3)
      --     screen.move(99,32)
      --     screen.text("s: ".._hui.fill.start_point[_hui.sel])
      --     screen.level(highway_ui.alt_fill_sel == 2 and 15 or 3)
      --     screen.move(99,42)
      --     screen.text("e: ".._hui.fill.end_point[_hui.sel])
      --     screen.level(highway_ui.alt_fill_sel == 3 and 15 or 3)
      --     screen.move(99,52)
      --     screen.text("style:")
      --     screen.move(128,62)
      --     screen.text_right(snake_styles[_hui.fill.snake]..(snake_styles[_hui.fill.snake] == "random @" and (" "..params:get("arp_"..highway_ui.sel.."_rand_prob").."%") or ""))
      --   end
      -- end
      -- // new drawing stuff

      if (key1_hold or (#conditional_entry_steps.focus[hf] > 0)) and ui.control_set == 'edit' then
        local current_step = track[hf][h.screen_focus].ui_position
        if ui.menu_focus == 1 then
          draw_popup("->")
          screen.move(40,20)
          screen.level(_s.popup_focus.tracks[hf][1] == 1 and 15 or 4)
          local base, line_above;
          if focused_set.conditional.mode[current_step] == "NOT PRE" then
            base = "PRE"
            line_above = true
          elseif focused_set.conditional.mode[current_step] == "NOT NEI" then
            base = "NEI"
            line_above = true
          elseif focused_set.conditional.mode[current_step] == "A:B" then
            base = focused_set.conditional.A[current_step]..':'..focused_set.conditional.B[current_step]
            line_above = false
          else
            base = focused_set.conditional.mode[current_step]
            line_above = false
          end
          screen.text('CONDITION: '..base)
          if line_above then
            screen.move(87,14)
            screen.line(base == "PRE" and 100 or 99,14)
            screen.stroke()
          end
          screen.move(40,30)
          screen.level(_s.popup_focus.tracks[hf][1] == 2 and 15 or 4)
          screen.text('PROB: '..focused_set.prob[current_step]..'%')
          screen.move(40,40)
          screen.level(_s.popup_focus.tracks[hf][1] == 3 and 15 or 4)
          screen.text('RETRIG: '..focused_set.conditional.retrig_count[current_step]..'x')
          screen.level(_s.popup_focus.tracks[hf][1] == 4 and 15 or 4)
          local get_string = _active.focus == 'main' and ('track_retrig_time_'..hf..'_'..h.screen_focus..'_'..current_step) or ('track_fill_retrig_time_'..hf..'_'..h.screen_focus..'_'..current_step)
          screen.move(20,50)
          screen.text('RATE: '..track_paramset:string(get_string))
          screen.level(_s.popup_focus.tracks[hf][1] == 5 and 15 or 4)
          screen.move(70,50)
          local show_sign = focused_set.conditional.retrig_slope[current_step] > 0 and '+' or ''
          screen.text('SLOPE: '..show_sign..focused_set.conditional.retrig_slope[current_step])
        elseif ui.menu_focus == 2 then
          draw_popup(norns.state.path..'img/bolt.png',6,17)
          screen.move(15,20)
          screen.level(15)
          screen.text('[EUCLID]')
          screen.move(55,20)
          screen.level(_s.popup_focus.tracks[hf][2] == 1 and 15 or 4)
          screen.text('PULSES: '..focused_set.er.pulses)
          screen.move(55,30)
          screen.level(_s.popup_focus.tracks[hf][2] == 2 and 15 or 4)
          screen.text('STEPS: '..focused_set.er.steps)
          screen.move(55,40)
          screen.level(_s.popup_focus.tracks[hf][2] == 3 and 15 or 4)
          screen.text('SHIFT: '..focused_set.er.shift)
          screen.move(55,50)
          screen.level(_s.popup_focus.tracks[hf][2] == 4 and 15 or 4)
          screen.text('GENERATE (K3)')
        elseif ui.menu_focus == 3 then
          draw_popup(norns.state.path..'img/keys.png',9,17)
          screen.move(55,20)
          screen.level(_s.popup_focus.tracks[hf][3] == 1 and 15 or 4)
          screen.text('VELOCITY: '..focused_set.velocities[current_step])
          screen.move(55,30)
          screen.level(_s.popup_focus.tracks[hf][3] == 2 and 15 or 4)
          screen.text('CHORD DEG: '..focused_set.chord_degrees[current_step])
          -- screen.move(55,40)
          -- screen.level(_s.popup_focus.tracks[hf][2] == 3 and 15 or 4)
          -- screen.text('SHIFT: '..focused_set.er.shift)
          -- screen.move(55,50)
          -- screen.level(_s.popup_focus.tracks[hf][2] == 4 and 15 or 4)
          -- screen.text('GENERATE (K3)')
        end
      elseif grid_conditional_entry and #conditional_entry_steps.focus[hf] == 0 and ui.control_set == 'edit' then
        if ui.menu_focus == 1 then
          draw_prepop('STEP CONDITIONS')
        end
      elseif grid_data_entry and #data_entry_steps.focus[hf] == 0 and ui.control_set == 'edit' then
        if ui.menu_focus == 1 then
          draw_prepop('PARAMETER LOCKS')
        end
      end

    elseif ui.control_set == 'step parameters' then
      _fkprm.redraw()
    elseif ui.control_set == 'poly parameters' then
      _polyparams.redraw()
    end
  end
end

function hway_ui.process_key(n,z)
  -- local _active = track[_hui.sel][track[track[_hui.sel]].active_hill]
  local hf = ui.hill_focus
  local h = hills[hf]
  local _active = track[hf][h.screen_focus]
  local focused_set = _active.focus == "main" and track[_hui.sel] or _active.fill
  if n == 1 then
    key1_hold = z == 1 and true or false
    highway_ui.alt = z == 1
    if z == 1 then
    end
  elseif n == 2 and z == 1 and not key1_hold then
    key2_hold_counter:start()
    key2_hold_and_modify = false
  elseif n == 2 and z == 0 and not key1_hold then
    if key2_hold == false and not key1_hold then
      key2_hold_counter:stop()
      menu = 1
    elseif key2_hold_and_modify then
      key2_hold = false
      key2_hold_and_modify = false
    elseif not key2_hold_and_modify then
      key2_hold = false
      key2_hold_and_modify = false
    end
  elseif n == 3 and z == 1 and not key1_hold and not key2_hold then
    _hui.focus = _hui.focus == "params" and "seq" or "params"
  elseif n == 3 and z == 1 and key2_hold and not key1_hold then
    -- if (params:string("arp_".._hui.sel.."_hold_style") == "sequencer" and not _active.playing)
    -- or (params:string("arp_".._hui.sel.."_hold_style") ~= "sequencer" and not _active.playing and tab.count(focused_set.notes) > 0)
    -- then
    --   step.toggle("start",_hui.sel)
    -- elseif _active.playing then
    --   step.toggle("stop",_hui.sel)
    -- end
    if arp_clipboard == nil then
      step.copy(_hui.sel)
    else
      step.paste(_hui.sel,arp_paste_style)
    end
  elseif n == 3 and z == 1 and not key2_hold and key1_hold then
    if _hui.focus == "params" then
      step.fill(_hui.sel,_hui.fill.start_point[_hui.sel],_hui.fill.end_point[_hui.sel],highway_ui.fill.snake)
    elseif _hui.focus == "seq" then
      if _hui.alt_view_sel == 1 then
        step.prob_fill(_hui.sel,_active.start_point,_active.end_point,focused_set.prob[track[_hui.sel][_hui.hill_sel].ui_position])
      elseif _hui.alt_view_sel == 2 then
        if focused_set.conditional.mode[track[_hui.sel][_hui.hill_sel].ui_position] == "A:B" then
          step.cond_fill(_hui.sel,_active.start_point,_active.end_point,focused_set.conditional.A[track[_hui.sel][_hui.hill_sel].ui_position],focused_set.conditional.B[track[_hui.sel][_hui.hill_sel].ui_position])
        else
          step.cond_fill(_hui.sel,_active.start_point,_active.end_point,focused_set.conditional.mode[track[_hui.sel][_hui.hill_sel].ui_position],"meta")
        end
      elseif _hui.alt_view_sel == 3 then
        step.retrig_fill(_hui.sel,_active.start_point,_active.end_point,focused_set.conditional.retrig_count[track[_hui.sel][_hui.hill_sel].ui_position],"retrig_count")
      elseif _hui.alt_view_sel == 4 then
        if _active.focus == "main" then
          step.retrig_fill(_hui.sel,_active.start_point,_active.end_point,arp_paramset:get("arp_retrig_time_".._hui.sel.."_"..track[_hui.sel][_hui.hill_sel].ui_position),"retrig_time")
        else
          step.retrig_fill(_hui.sel,_active.start_point,_active.end_point,arp_paramset:get("arp_fill_retrig_time_".._hui.sel.."_"..track[_hui.sel][_hui.hill_sel].ui_position),"retrig_time")
        end
      end
    end
  end
  screen_dirty = true
  grid_dirty = true
end

-- function hway_ui.process_encoder(n,d) -- NONE OF THIS GETS CALLED!!!
--   -- local _active = track[_hui.sel][track[_hui.sel].active_hill]
--   local hf = ui.hill_focus
--   local h = hills[hf]
--   local _active = track[hf][h.screen_focus]
--   local focused_set = _active.focus == "main" and track[_hui.sel] or _active.fill
--   if n == 1 then
--     _hui.sel = util.clamp(_hui.sel+d,1,3)
--   end
--   if _hui.focus == "params" and not highway_ui.alt then
--     if n == 2 then
--       _hui.param = util.clamp(_hui.param + d,1,5)
--     elseif n == 3 then
--       local id = _hui.sel
--       local focus_arp = track[_hui.sel]
--       if _hui.param == 1 then
--         local deci_to_int =
--         { ["0.125"] = 1 --1/32
--         , ["0.1667"] = 2 --1/16T
--         , ["0.25"] = 3 -- 1/16
--         , ["0.3333"] = 4 -- 1/8T
--         , ["0.5"] = 5 -- 1/8
--         , ["0.6667"] = 6 -- 1/4T
--         , ["1.0"] = 7 -- 1/4
--         , ["1.3333"] = 8 -- 1/2T
--         , ["2.0"] = 9 -- 1/2
--         , ["2.6667"] = 10  -- 1T
--         , ["4.0"] = 11 -- 1
--         }
--         local rounded = util.round(track[id].time,0.0001)
--         local working = deci_to_int[tostring(rounded)]
--         working = util.clamp(working+d,1,11)
--         local int_to_deci = {0.125,1/6,0.25,1/3,0.5,2/3,1,4/3,2,8/3,4}
--         for i = 1,16 do
--           bank[id][i].arp_time = int_to_deci[working]
--         end
--         track[id].time = int_to_deci[working]
--       elseif _hui.param == 2 then
--         local dir_to_int =
--         { ["fwd"] = 1
--         , ["bkwd"] = 2
--         , ["pend"] = 3
--         , ["rnd"] = 4
--         }
--         local dir = dir_to_int[focus_arp.mode]
--         dir = util.clamp(dir+d,1,4)
--         local int_to_dir = {"fwd","bkwd","pend","rnd"}
--         focus_arp.mode = int_to_dir[dir]
--       elseif _hui.param == 3 then
--         focus_arp.start_point = util.clamp(focus_arp.start_point+d,1,focus_arp.end_point)
--         _hui.fill.start_point[_hui.sel] = focus_arp.start_point
--       elseif _hui.param == 4 then
--         focus_arp.end_point = util.clamp(focus_arp.end_point+d,focus_arp.start_point,128)
--         _hui.fill.end_point[_hui.sel] = focus_arp.end_point
--       elseif _hui.param == 5 then
--         _active.swing = util.clamp(_active.swing+d,50,99)
--       end
--     end
--   elseif _hui.focus == "params" and highway_ui.alt then
--     if n == 2 then
--       _hui.alt_fill_sel = util.clamp(_hui.alt_fill_sel+d,1,3)
--     elseif n == 3 then
--       if _hui.alt_fill_sel == 1 then
--         _hui.fill.start_point[_hui.sel] = util.clamp(_hui.fill.start_point[_hui.sel]+d,1,_hui.fill.end_point[_hui.sel])
--       elseif _hui.alt_fill_sel == 2 then
--         _hui.fill.end_point[_hui.sel] = util.clamp(_hui.fill.end_point[_hui.sel]+d,_hui.fill.start_point[_hui.sel],128)
--       elseif _hui.alt_fill_sel == 3 then
--        _hui.fill.snake = util.clamp(_hui.fill.snake+d,1,#snake_styles)
--       end
--     end
--   elseif _hui.focus == "seq" then
--     if n == 2 then
--       if not highway_ui.alt then
--         print(_hui.sel)
--         track[_hui.sel][_hui.hill_sel].ui_position = util.clamp(track[_hui.sel][_hui.hill_sel].ui_position+d,1,128)
--         _hui.seq_page[_hui.sel] = math.ceil(track[_hui.sel][_hui.hill_sel].ui_position/32)
--       else
--         _hui.alt_view_sel = util.clamp(_hui.alt_view_sel+d,1,4)
--       end
--     elseif n == 3 then
--       if not highway_ui.alt then
--         if key2_hold then
--           arp_paste_style = util.clamp(arp_paste_style+d,1,3)
--         else
--           local current = focused_set.notes[track[_hui.sel][_hui.hill_sel].ui_position]
--           if current == nil then current = 0 end
--           current = util.clamp(current+d,0,16)
--           if current == 0 then current = nil end
--           focused_set.notes[track[_hui.sel][_hui.hill_sel].ui_position] = current
--           hway_ui.check_for_first_touch()
--         end
--       else
--         local current = track[_hui.sel][_hui.hill_sel].ui_position
--         if _hui.alt_view_sel == 1 then
--           focused_set.prob[current] = util.clamp(focused_set.prob[current]+d,0,100)
--         elseif _hui.alt_view_sel == 2 then
--           hway_ui.cycle_conditional(_hui.sel,current,d)
--         elseif _hui.alt_view_sel == 3 then
--           hway_ui.cycle_retrig_count(_hui.sel,current,d)
--         elseif _hui.alt_view_sel == 4 then
--           if _active.focus == "main" then
--             arp_paramset:delta("arp_retrig_time_".._hui.sel.."_"..current,d)
--           else
--             arp_paramset:delta("arp_fill_retrig_time_".._hui.sel.."_"..current,d)
--           end
--         end
--       end
--     end
--   end
--   grid_dirty = true
-- end

local conditional_modes = {"NOT NEI","NEI","NOT PRE","PRE","A:B"}

function hway_ui.cycle_conditional(i,j,step,d)
  local _active = track[i][j]
  local send_to_many = false
  if grid_conditional_entry and #conditional_entry_steps.focus[i] > 1 then
    step = conditional_entry_steps.focus[i][#conditional_entry_steps.focus[i]]
  end
  local focused_set = _active.focus == 'main' and _active or _active.fill
  if d > 0 then
    if focused_set.conditional.mode[step] == "A:B" then
      local current_B = focused_set.conditional.B[step]
      current_B = current_B+d
      if current_B > 8 then
        focused_set.conditional.A[step] = util.clamp(focused_set.conditional.A[step]+1,1,8)
        focused_set.conditional.B[step] = focused_set.conditional.A[step] ~= 8 and 1 or 8
        for s = 2,#conditional_entry_steps.focus[i] do
          focused_set.conditional.A[conditional_entry_steps.focus[i][s]] = focused_set.conditional.A[step]
          focused_set.conditional.B[conditional_entry_steps.focus[i][s]] = focused_set.conditional.B[step]
        end
      else
        focused_set.conditional.B[step] = current_B
        for s = 2,#conditional_entry_steps.focus[i] do
          focused_set.conditional.B[conditional_entry_steps.focus[i][s]] = focused_set.conditional.B[step]
        end
      end
    else
      local which_mode = tab.key(conditional_modes,focused_set.conditional.mode[step])
      which_mode = util.clamp(which_mode + d,1,#conditional_modes)
      focused_set.conditional.mode[step] = conditional_modes[which_mode]
    end
  elseif d < 0 then
    if focused_set.conditional.mode[step] == "A:B" then
      if focused_set.conditional.A[step] == 1 and focused_set.conditional.B[step] == 1 then
        focused_set.conditional.mode[step] = "PRE"
        for s = 1,#conditional_entry_steps.focus[i] do
          focused_set.conditional.mode[conditional_entry_steps.focus[i][s]] = focused_set.conditional.mode[step]
        end
      else
        local current_B = focused_set.conditional.B[step]
        current_B = current_B+d
        if current_B < 1 then
          focused_set.conditional.A[step] = util.clamp(focused_set.conditional.A[step]-1,1,8)
          -- focused_set.conditional.B[step] = focused_set.conditional.A[step] ~= 1 and 8 or 1
          focused_set.conditional.B[step] = 8
          for s = 1,#conditional_entry_steps.focus[i] do
            focused_set.conditional.A[conditional_entry_steps.focus[i][s]] = focused_set.conditional.A[step]
            focused_set.conditional.B[conditional_entry_steps.focus[i][s]] = focused_set.conditional.B[step]
          end
        else
          focused_set.conditional.B[step] = current_B
          for s = 1,#conditional_entry_steps.focus[i] do
            focused_set.conditional.B[conditional_entry_steps.focus[i][s]] = focused_set.conditional.B[step]
          end
        end
      end
    else
      local which_mode = tab.key(conditional_modes,focused_set.conditional.mode[step])
      which_mode = util.clamp(which_mode + d,1,#conditional_modes)
      focused_set.conditional.mode[step] = conditional_modes[which_mode]
      for s = 1,#conditional_entry_steps.focus[i] do
        focused_set.conditional.mode[conditional_entry_steps.focus[i][s]] = focused_set.conditional.mode[step]
      end
    end
  end
end

function hway_ui.cycle_prob(i,j,step,d)
  local _active = track[i][j]
  local focused_set = _active.focus == 'main' and _active or _active.fill
  if grid_conditional_entry and #conditional_entry_steps.focus[i] > 1 then
    step = conditional_entry_steps.focus[i][#conditional_entry_steps.focus[i]]
  end
  focused_set.prob[step] = util.clamp(focused_set.prob[step] + d, 0, 100)
  for s = 1,#conditional_entry_steps.focus[i] do
    focused_set.prob[conditional_entry_steps.focus[i][s]] = focused_set.prob[step]
  end
end

function hway_ui.cycle_retrig_count(i,j,step,d)
  local _active = track[i][j]
  local focused_set = _active.focus == 'main' and _active or _active.fill
  focused_set.conditional.retrig_count[step] = util.clamp(focused_set.conditional.retrig_count[step]+d, 0, 128)
end

function hway_ui.cycle_retrig_time(i,j,step,d)
  local _active = track[i][j]
  local focused_set = _active.focus == 'main' and ('track_retrig_time_'..i..'_'..j..'_'..step) or ('track_fill_retrig_time_'..i..'_'..j..'_'..step)
  track_paramset:delta(focused_set,d)
end

function hway_ui.cycle_retrig_vel(i,j,step,d)
  local _active = track[i][j]
  local focused_set = _active.focus == 'main' and _active or _active.fill
  focused_set.conditional.retrig_slope[step] = util.clamp(focused_set.conditional.retrig_slope[step]+d, -128, 128)
end

function hway_ui.cycle_er_param(prm,i,j,d)
  local _active = track[i][j]
  local focused_set = _active.focus == 'main' and _active or _active.fill
  if prm == 'pulses' then
    focused_set.er[prm] = util.clamp(focused_set.er[prm] + d, 0, focused_set.er.steps)
  elseif prm == 'steps' then
    focused_set.er[prm] = util.clamp(focused_set.er[prm] + d, 0, 128)
  elseif prm == 'shift' then
    focused_set.er[prm] = util.clamp(focused_set.er[prm] + d, -128, 128)
  end
end

function hway_ui.cycle_chord_degrees(i,j,step,d)
  local _active = track[i][j]
  local focused_set = _active.focus == 'main' and _active or _active.fill
  focused_set.chord_degrees[step] = util.clamp(focused_set.chord_degrees[step] + d, 1, 7)
end

function hway_ui.check_for_first_touch()
  -- local _active = track[_hui.sel][track[_hui.sel].active_hill]
  local hf = ui.hill_focus
  local h = hills[hf]
  local _active = track[hf][h.screen_focus]
  local focused_set = _active.focus == "main" and track[_hui.sel] or _active.fill
  if tab.count(focused_set.base_note) == 1
  and not _active.playing
  and not _active.pause
  and not _active.enabled
  then
    step.enable(_hui.sel,true)
    _active.pause = true
    _active.hold = true
    grid_dirty = true
  end
end

function hway_ui.index_to_grid_pos(val,columns)
  local x = math.fmod(val-1,columns)+1
  local y = math.modf((val-1)/columns)+1
  return {x,y-(4*(_hui.seq_page[ui.hill_focus]-1))}
end

-- function hway_ui.fill(style)
-- local _active = track[_hui.sel][track[_hui.sel].active_hill]
--   if style ~= "random" then
--     for i = _active.start_point,_active.end_point do
--       _active.notes[i] = snakes[style][wrap(i,1,16)]
--     end
--   else
--     for i = _active.start_point,_active.end_point do
--       _active.notes[i] = math.random(1,16)
--     end
--   end
--   if not _active.playing
--   and not _active.pause
--   and not _active.enabled
--   then
--     step.enable(_hui.sel,true)
--     _active.pause = true
--     _active.hold = true
--     grid_dirty = true
--   end
--   screen_dirty = true
-- end

return hway_ui