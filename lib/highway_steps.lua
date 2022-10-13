local step_menu = {}

local _hway = step_menu
local _hway_;

local snake_styles;

function _hway.init()
  
  highway = {}
  highway.focus = "seq" -- "params" or "seq"
  highway.sel = 1
  highway.alt = false
  highway.param = 1
  highway.seq_focus = "pattern"
  highway.seq_position = {1,1,1,1,1,1,1,1,1,1}
  highway.seq_page = {1,1,1,1,1,1,1,1,1,1}
  highway.alt_view_sel = 1
  highway.alt_fill_sel = 1
  highway.fill = {}
  highway.fill.start_point = {1,1,1,1,1,1,1,1,1,1}
  highway.fill.end_point = {16,16,16,16,16,16,16,16,16,16}
  highway.fill.snake = 1
  _hway_ = highway

  snake_styles =
  {
      "horiz"
    , "h.snake"
    , "vert"
    , "v.snake"
    , "top-in"
    , "bottom-in"
    , "zig-zag"
    , "wrap"
    , "random"
    , "random @"
  }
end

function _hway.draw_menu()

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
    if ui.control_set ~= 'step parameters' then
      local focus = h.screen_focus
      local seg = h[focus]
      screen.level(1)
      screen.rect(40,15,80,40)
      screen.fill()
      local s_c = ui.screen_controls[hf][focus]
      local iter_index = seg.index-1 ~= 0 and seg.index-1 or hills[hf][focus].high_bound.note
      local menus = {"hill: "..focus,"bound","notes","loop","smpl"}
      screen.font_size(8)
      if ui.control_set == "edit" and ui.menu_focus ~= 1 then
        screen.move(0,22)
        screen.level(3)
        screen.text("hill: "..focus)
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
          screen.text("["..menus[i].."]")
        elseif ui.control_set ~= "edit" then
          screen.text(menus[i])
        end
      end

      -- new drawing stuff //
      local focus_arp = track[_hway_.sel]
      local focused_set = track[_hway_.sel].focus == "main" and track[_hway_.sel] or track[_hway_.sel].fill
      screen.move(0,10)
      screen.level(3)
      -- screen.text("hway"..(focus_arp.focus == "fill" and ": FILL" or ""))
      -- local header = {"bd","sd","tm","cp","rs","cb","hh",'s1','s2','s3'}
      -- for i = 1,#header do
      --   screen.level(_hway_.sel == i and 15 or 3)
      --   screen.move(20+(i*15),10)
      --   screen.text(header[i])
      -- end
      screen.level(_hway_.focus == "seq" and 8 or 0)
      local e_pos = _hway_.seq_position[_hway_.sel]
      -- screen.rect(2+(_hway.index_to_grid_pos(e_pos,8)[1]-1)*12,6+(10*_hway.index_to_grid_pos(e_pos,8)[2]),7,7)
      screen.rect(41+(_hway.index_to_grid_pos(e_pos,8)[1]-1)*10,6+(10*_hway.index_to_grid_pos(e_pos,8)[2]),7,7)
      screen.fill()
      local min_max = {{1,32},{33,64},{65,96},{97,128}}
      local lvl = 5
      for i = min_max[_hway_.seq_page[_hway_.sel]][1], min_max[_hway_.seq_page[_hway_.sel]][2] do
        if _hway_.seq_position[_hway_.sel] == i then
          if track[_hway_.sel].step == i and track[_hway_.sel].playing then
            lvl = _hway_.focus == "seq" and 5 or 4
          else
            lvl = _hway_.focus == "seq" and 0 or 2
          end
        else
          if i <= track[_hway_.sel].end_point and i >= track[_hway_.sel].start_point then
            if track[_hway_.sel].step == i then
              lvl = _hway_.focus == "seq" and 15 or 4
            else
              lvl = _hway_.focus == "seq" and 5 or 2
            end
          else
            lvl = 0
          end
        end
        screen.level(lvl)
        -- screen.move(5+(_hway.index_to_grid_pos(i,8)[1]-1)*12,12+(10*_hway.index_to_grid_pos(i,8)[2]))
        screen.move(44+(_hway.index_to_grid_pos(i,8)[1]-1)*10,12+(10*_hway.index_to_grid_pos(i,8)[2]))
        if highway.alt and _hway_.focus == "params" then
          local first;
          local second = focused_set.notes[i] ~= nil and focused_set.notes[i] or "-"
          local third;
          if _hway_.fill.start_point[_hway_.sel] == i then
            first = "["
          else
            first = ""
          end
          if _hway_.fill.end_point[_hway_.sel] == i then
            third = "]"
          else
            third = ""
          end
          screen.text_center(first..second..third)
        else
          screen.text_center(focused_set.notes[i] ~= nil and focused_set.notes[i] or "-")
        end
      end
      screen.move(0,62)
      screen.level(3)
      screen.text("p. ".._hway_.seq_page[_hway_.sel])
      -- if not highway.alt then
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
      --     screen.level(_hway_.focus == "params" and
      --     (_hway_.param == 1 and 15 or 3)
      --     or 3)
      --     local banks = {"a","b","c"}
      --     -- local pad = tostring(banks[_hway_.sel]..bank[_hway_.sel].id)
      --     local pad = 'nothing'
      --     screen.text_right((_hway_.alt and (pad..": ") or "")..deci_to_frac[tostring(util.round(track[_hway_.sel].time, 0.0001))])
      --     screen.move(125,32)
      --     screen.level(_hway_.focus == "params" and
      --     (_hway_.param == 2 and 15 or 3)
      --     or 3)
      --     screen.text_right(focus_arp.mode)
      --     screen.move(125,42)
      --     screen.level(_hway_.focus == "params" and
      --     (_hway_.param == 3 and 15 or 3)
      --     or 3)
      --     screen.text_right("s: "..focus_arp.start_point)
      --     screen.move(125,52)
      --     screen.level(_hway_.focus == "params" and
      --     (_hway_.param == 4 and 15 or 3)
      --     or 3)
      --     screen.text_right("e: "..(focus_arp.end_point > 0 and focus_arp.end_point or "1"))
      --     screen.move(125,62)
      --     screen.level(_hway_.focus == "params" and
      --     (_hway_.param == 5 and 15 or 3)
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
      --       -- screen.text(tab.count(focused_set.notes) > 0 and (track[_hway_.sel].playing and letters[2][i] or letters[1][i]) or letters[3][i])
      --     end
      --     screen.font_size(8)
      --     if arp_clipboard ~= nil then
      --       screen.move(20,62)
      --       if arp_paste_style == 1 then
      --         screen.text(
      --           "E3: paste "
      --           ..("["..header[arp_clipboard_bank_source].."]")
      --           .." to ["..header[_hway_.sel].."]"
      --         )
      --       elseif arp_paste_style == 2 then
      --         screen.text(
      --           "E3: paste "
      --           ..("["..header[arp_clipboard_bank_source]..arp_clipboard_pad_source.."] to ["..header[_hway_.sel].._hway_.seq_position[_hway_.sel].."]")
      --         )
      --       elseif arp_paste_style == 3 then
      --         local layer = arp_clipboard_layer_source == "main" and "" or ": F"
      --         screen.text(
      --           "E3: paste "
      --           ..("["..header[arp_clipboard_bank_source]..layer.."] to ["..header[_hway_.sel]..(track[_hway_.sel].focus == "main" and "" or ": F").."]")
      --         )
      --       end
      --     end
      --   end
      -- elseif highway.alt and _hway_.focus == "seq" then
      --   if not key2_hold then
      --     screen.level(10)
      --     screen.rect(98,15,128,9)
      --     screen.fill()
      --     screen.level(0)
      --     screen.move(113,22)
      --     screen.text_center("TRIG")
      --     screen.level(highway.alt_view_sel == 1 and 15 or 3)
      --     screen.move(99,32)
      --     screen.text("P: "..focused_set.prob[_hway_.seq_position[_hway_.sel]].."%")
      --     screen.level(highway.alt_view_sel == 2 and 15 or 3)
      --     screen.move(99,42)
      --     if focused_set.conditional.mode[_hway_.seq_position[_hway_.sel]] == "A:B" then
      --       screen.text("C: "..focused_set.conditional.A[_hway_.seq_position[_hway_.sel]]..
      --       ":"..
      --       focused_set.conditional.B[_hway_.seq_position[_hway_.sel]])
      --     else
      --       local base, line_above;
      --       if focused_set.conditional.mode[_hway_.seq_position[_hway_.sel]] == "NOT PRE" then
      --         base = "PRE"
      --         line_above = true
      --       elseif focused_set.conditional.mode[_hway_.seq_position[_hway_.sel]] == "NOT NEI" then
      --         base = "NEI"
      --         line_above = true
      --       else
      --         base = focused_set.conditional.mode[_hway_.seq_position[_hway_.sel]]
      --         line_above = false
      --       end
      --       screen.text("C: "..base)
      --       if line_above then
      --         screen.move(109,36)
      --         screen.line(base == "PRE" and 122 or 121,36)
      --         screen.stroke()
      --       end
      --     end
      --     screen.level(highway.alt_view_sel == 3 and 15 or 3)
      --     screen.move(99,52)
      --     screen.text("R: "..focused_set.conditional.retrig_count[_hway_.seq_position[_hway_.sel]].."x")
      --     screen.level(highway.alt_view_sel == 4 and 15 or 3)
      --     screen.move(99,62)
      --     if track[_hway_.sel].focus == "main" then
      --       screen.text("T: "..arp_paramset:string("arp_retrig_time_".._hway_.sel.."_".._hway_.seq_position[_hway_.sel]))
      --     else
      --       screen.text("T: "..arp_paramset:string("arp_fill_retrig_time_".._hway_.sel.."_".._hway_.seq_position[_hway_.sel]))
      --     end
      --     screen.level(15)
      --     screen.move(20,62)
      --     if highway.alt_view_sel == 1 then
      --       screen.text("K3: active -> "..focused_set.prob[_hway_.seq_position[_hway_.sel]].."%")
      --     elseif highway.alt_view_sel == 2 then
      --       if focused_set.conditional.mode[_hway_.seq_position[_hway_.sel]] == "A:B" then
      --         screen.text("K3: active -> "..focused_set.conditional.A[_hway_.seq_position[_hway_.sel]]..
      --         ":"..
      --         focused_set.conditional.B[_hway_.seq_position[_hway_.sel]])
      --       else
      --         local base, line_above;
      --         if focused_set.conditional.mode[_hway_.seq_position[_hway_.sel]] == "NOT PRE" then
      --           base = "PRE"
      --           line_above = true
      --         elseif focused_set.conditional.mode[_hway_.seq_position[_hway_.sel]] == "NOT NEI" then
      --           base = "NEI"
      --           line_above = true
      --         else
      --           base = focused_set.conditional.mode[_hway_.seq_position[_hway_.sel]]
      --           line_above = false
      --         end
      --         screen.text("K3: active -> "..base)
      --         if line_above then
      --           screen.move(77,56)
      --           screen.line(base == "PRE" and 90 or 89,56)
      --           screen.stroke()
      --         end
      --       end
      --     elseif highway.alt_view_sel == 3 then
      --       screen.text("K3: active -> "..focused_set.conditional.retrig_count[_hway_.seq_position[_hway_.sel]].."x")
      --     elseif highway.alt_view_sel == 4 then
      --       local focused_param = track[_hway_.sel].focus == "main" and "arp_retrig_time_" or "arp_fill_retrig_time_"
      --       screen.text("K3: active -> "..arp_paramset:string(focused_param.._hway_.sel.."_".._hway_.seq_position[_hway_.sel]))
      --     end
      --   end
      -- elseif highway.alt and _hway_.focus == "params" then
      --   if not key2_hold then
      --     screen.level(10)
      --     screen.rect(98,15,128,9)
      --     screen.fill()
      --     screen.level(0)
      --     screen.move(113,22)
      --     screen.text_center("FILL")
      --     screen.level(highway.alt_fill_sel == 1 and 15 or 3)
      --     screen.move(99,32)
      --     screen.text("s: ".._hway_.fill.start_point[_hway_.sel])
      --     screen.level(highway.alt_fill_sel == 2 and 15 or 3)
      --     screen.move(99,42)
      --     screen.text("e: ".._hway_.fill.end_point[_hway_.sel])
      --     screen.level(highway.alt_fill_sel == 3 and 15 or 3)
      --     screen.move(99,52)
      --     screen.text("style:")
      --     screen.move(128,62)
      --     screen.text_right(snake_styles[_hway_.fill.snake]..(snake_styles[_hway_.fill.snake] == "random @" and (" "..params:get("arp_"..highway.sel.."_rand_prob").."%") or ""))
      --   end
      -- end
      -- // new drawing stuff
    else
      _fkprm.redraw()
    end
  end
end

function _hway.process_key(n,z)
  local focused_set = track[_hway_.sel].focus == "main" and track[_hway_.sel] or track[_hway_.sel].fill
  if n == 1 then
    key1_hold = z == 1 and true or false
    highway.alt = z == 1
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
    _hway_.focus = _hway_.focus == "params" and "seq" or "params"
  elseif n == 3 and z == 1 and key2_hold and not key1_hold then
    -- if (params:string("arp_".._hway_.sel.."_hold_style") == "sequencer" and not track[_hway_.sel].playing)
    -- or (params:string("arp_".._hway_.sel.."_hold_style") ~= "sequencer" and not track[_hway_.sel].playing and tab.count(focused_set.notes) > 0)
    -- then
    --   step.toggle("start",_hway_.sel)
    -- elseif track[_hway_.sel].playing then
    --   step.toggle("stop",_hway_.sel)
    -- end
    if arp_clipboard == nil then
      step.copy(_hway_.sel)
    else
      step.paste(_hway_.sel,arp_paste_style)
    end
  elseif n == 3 and z == 1 and not key2_hold and key1_hold then
    if _hway_.focus == "params" then
      step.fill(_hway_.sel,_hway_.fill.start_point[_hway_.sel],_hway_.fill.end_point[_hway_.sel],highway.fill.snake)
    elseif _hway_.focus == "seq" then
      if _hway_.alt_view_sel == 1 then
        step.prob_fill(_hway_.sel,track[_hway_.sel].start_point,track[_hway_.sel].end_point,focused_set.prob[_hway_.seq_position[_hway_.sel]])
      elseif _hway_.alt_view_sel == 2 then
        if focused_set.conditional.mode[_hway_.seq_position[_hway_.sel]] == "A:B" then
          step.cond_fill(_hway_.sel,track[_hway_.sel].start_point,track[_hway_.sel].end_point,focused_set.conditional.A[_hway_.seq_position[_hway_.sel]],focused_set.conditional.B[_hway_.seq_position[_hway_.sel]])
        else
          step.cond_fill(_hway_.sel,track[_hway_.sel].start_point,track[_hway_.sel].end_point,focused_set.conditional.mode[_hway_.seq_position[_hway_.sel]],"meta")
        end
      elseif _hway_.alt_view_sel == 3 then
        step.retrig_fill(_hway_.sel,track[_hway_.sel].start_point,track[_hway_.sel].end_point,focused_set.conditional.retrig_count[_hway_.seq_position[_hway_.sel]],"retrig_count")
      elseif _hway_.alt_view_sel == 4 then
        if track[_hway_.sel].focus == "main" then
          step.retrig_fill(_hway_.sel,track[_hway_.sel].start_point,track[_hway_.sel].end_point,arp_paramset:get("arp_retrig_time_".._hway_.sel.."_".._hway_.seq_position[_hway_.sel]),"retrig_time")
        else
          step.retrig_fill(_hway_.sel,track[_hway_.sel].start_point,track[_hway_.sel].end_point,arp_paramset:get("arp_fill_retrig_time_".._hway_.sel.."_".._hway_.seq_position[_hway_.sel]),"retrig_time")
        end
      end
    end
  end
  screen_dirty = true
  grid_dirty = true
end

function _hway.process_encoder(n,d)
  local focused_set = track[_hway_.sel].focus == "main" and track[_hway_.sel] or track[_hway_.sel].fill
  if n == 1 then
    _hway_.sel = util.clamp(_hway_.sel+d,1,3)
  end
  if _hway_.focus == "params" and not highway.alt then
    if n == 2 then
      _hway_.param = util.clamp(_hway_.param + d,1,5)
    elseif n == 3 then
      local id = _hway_.sel
      local focus_arp = track[_hway_.sel]
      if _hway_.param == 1 then
        local deci_to_int =
        { ["0.125"] = 1 --1/32
        , ["0.1667"] = 2 --1/16T
        , ["0.25"] = 3 -- 1/16
        , ["0.3333"] = 4 -- 1/8T
        , ["0.5"] = 5 -- 1/8
        , ["0.6667"] = 6 -- 1/4T
        , ["1.0"] = 7 -- 1/4
        , ["1.3333"] = 8 -- 1/2T
        , ["2.0"] = 9 -- 1/2
        , ["2.6667"] = 10  -- 1T
        , ["4.0"] = 11 -- 1
        }
        local rounded = util.round(track[id].time,0.0001)
        local working = deci_to_int[tostring(rounded)]
        working = util.clamp(working+d,1,11)
        local int_to_deci = {0.125,1/6,0.25,1/3,0.5,2/3,1,4/3,2,8/3,4}
        for i = 1,16 do
          bank[id][i].arp_time = int_to_deci[working]
        end
        track[id].time = int_to_deci[working]
      elseif _hway_.param == 2 then
        local dir_to_int =
        { ["fwd"] = 1
        , ["bkwd"] = 2
        , ["pend"] = 3
        , ["rnd"] = 4
        }
        local dir = dir_to_int[focus_arp.mode]
        dir = util.clamp(dir+d,1,4)
        local int_to_dir = {"fwd","bkwd","pend","rnd"}
        focus_arp.mode = int_to_dir[dir]
      elseif _hway_.param == 3 then
        focus_arp.start_point = util.clamp(focus_arp.start_point+d,1,focus_arp.end_point)
        _hway_.fill.start_point[_hway_.sel] = focus_arp.start_point
      elseif _hway_.param == 4 then
        focus_arp.end_point = util.clamp(focus_arp.end_point+d,focus_arp.start_point,128)
        _hway_.fill.end_point[_hway_.sel] = focus_arp.end_point
      elseif _hway_.param == 5 then
        track[_hway_.sel].swing = util.clamp(track[_hway_.sel].swing+d,50,99)
      end
    end
  elseif _hway_.focus == "params" and highway.alt then
    if n == 2 then
      _hway_.alt_fill_sel = util.clamp(_hway_.alt_fill_sel+d,1,3)
    elseif n == 3 then
      if _hway_.alt_fill_sel == 1 then
        _hway_.fill.start_point[_hway_.sel] = util.clamp(_hway_.fill.start_point[_hway_.sel]+d,1,_hway_.fill.end_point[_hway_.sel])
      elseif _hway_.alt_fill_sel == 2 then
        _hway_.fill.end_point[_hway_.sel] = util.clamp(_hway_.fill.end_point[_hway_.sel]+d,_hway_.fill.start_point[_hway_.sel],128)
      elseif _hway_.alt_fill_sel == 3 then
       _hway_.fill.snake = util.clamp(_hway_.fill.snake+d,1,#snake_styles)
      end
    end
  elseif _hway_.focus == "seq" then
    if n == 2 then
      if not highway.alt then
        _hway_.seq_position[_hway_.sel] = util.clamp(_hway_.seq_position[_hway_.sel]+d,1,128)
        _hway_.seq_page[_hway_.sel] = math.ceil(_hway_.seq_position[_hway_.sel]/32)
      else
        _hway_.alt_view_sel = util.clamp(_hway_.alt_view_sel+d,1,4)
      end
    elseif n == 3 then
      if not highway.alt then
        if key2_hold then
          arp_paste_style = util.clamp(arp_paste_style+d,1,3)
        else
          local current = focused_set.notes[_hway_.seq_position[_hway_.sel]]
          if current == nil then current = 0 end
          current = util.clamp(current+d,0,16)
          if current == 0 then current = nil end
          focused_set.notes[_hway_.seq_position[_hway_.sel]] = current
          _hway.check_for_first_touch()
        end
      else
        local current = _hway_.seq_position[_hway_.sel]
        if _hway_.alt_view_sel == 1 then
          focused_set.prob[current] = util.clamp(focused_set.prob[current]+d,0,100)
        elseif _hway_.alt_view_sel == 2 then
          _hway.cycle_conditional(_hway_.sel,current,d)
        elseif _hway_.alt_view_sel == 3 then
          _hway.cycle_retrig_count(_hway_.sel,current,d)
        elseif _hway_.alt_view_sel == 4 then
          if track[_hway_.sel].focus == "main" then
            arp_paramset:delta("arp_retrig_time_".._hway_.sel.."_"..current,d)
          else
            arp_paramset:delta("arp_fill_retrig_time_".._hway_.sel.."_"..current,d)
          end
        end
      end
    end
  end
  grid_dirty = true
end

local conditional_modes = {"NOT NEI","NEI","NOT PRE","PRE","A:B"}

function _hway.cycle_conditional(target,step,d)
  local focused_set = track[target].focus == "main" and track[target] or track[target].fill
  if d > 0 then
    if focused_set.conditional.mode[step] == "A:B" then
      local current_B = focused_set.conditional.B[step]
      current_B = current_B+d
      if current_B > 8 then
        focused_set.conditional.A[step] = util.clamp(focused_set.conditional.A[step]+1,1,8)
        focused_set.conditional.B[step] = focused_set.conditional.A[step] ~= 8 and 1 or 8
      else
        focused_set.conditional.B[step] = current_B
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
      else
        local current_B = focused_set.conditional.B[step]
        current_B = current_B+d
        if current_B < 1 then
          focused_set.conditional.A[step] = util.clamp(focused_set.conditional.A[step]-1,1,8)
          -- focused_set.conditional.B[step] = focused_set.conditional.A[step] ~= 1 and 8 or 1
          focused_set.conditional.B[step] = 8
        else
          focused_set.conditional.B[step] = current_B
        end
      end
    else
      local which_mode = tab.key(conditional_modes,focused_set.conditional.mode[step])
      which_mode = util.clamp(which_mode + d,1,#conditional_modes)
      focused_set.conditional.mode[step] = conditional_modes[which_mode]
    end
  end
end

function _hway.cycle_retrig_count(target,step,d)
  local focused_set = track[target].focus == "main" and track[target] or track[target].fill
  focused_set.conditional.retrig_count[step] = util.clamp(focused_set.conditional.retrig_count[step]+d,0,128)
end

function _hway.check_for_first_touch()
  local focused_set = track[_hway_.sel].focus == "main" and track[_hway_.sel] or track[_hway_.sel].fill
  if tab.count(focused_set.notes) == 1
  and not track[_hway_.sel].playing
  and not track[_hway_.sel].pause
  and not track[_hway_.sel].enabled
  then
    step.enable(_hway_.sel,true)
    track[_hway_.sel].pause = true
    track[_hway_.sel].hold = true
    grid_dirty = true
  end
end

function _hway.index_to_grid_pos(val,columns)
  local x = math.fmod(val-1,columns)+1
  local y = math.modf((val-1)/columns)+1
  return {x,y-(4*(_hway_.seq_page[_hway_.sel]-1))}
end

-- function _hway.fill(style)
--   if style ~= "random" then
--     for i = track[_hway_.sel].start_point,track[_hway_.sel].end_point do
--       track[_hway_.sel].notes[i] = snakes[style][wrap(i,1,16)]
--     end
--   else
--     for i = track[_hway_.sel].start_point,track[_hway_.sel].end_point do
--       track[_hway_.sel].notes[i] = math.random(1,16)
--     end
--   end
--   if not track[_hway_.sel].playing
--   and not track[_hway_.sel].pause
--   and not track[_hway_.sel].enabled
--   then
--     step.enable(_hway_.sel,true)
--     track[_hway_.sel].pause = true
--     track[_hway_.sel].hold = true
--     grid_dirty = true
--   end
--   screen_dirty = true
-- end

return step_menu