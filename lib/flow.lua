local flow_menu = {}

local f_m = flow_menu
local groups = {"1","2","3","4"}
local pattern_names = {1,2,3,4}
local pattern_banks = {"A","B","C","D","E","F","G","H"}
local _fm_;

function f_m.init()
  page = {}
  page.flow = {}
  page.flow.pages = {"PATTERN","SCENES","SONG"}
  page.flow.main_sel = 3
  page.flow.menu_layer = 3
  page.flow.group = 1
  page.flow.pads_page_sel = 1
  page.flow.song_line = {1,1,1,1}
  page.flow.song_col = {1,1,1,1}
  page.flow.scene_selected = {1,1,1,1}
  page.flow.scene_line_sel = 1
  page.flow.alt = false
  _fm_ = page.flow
end

local snapshot_restore_params = {"rate","start_point","end_point","level","filter","lfo"}

function f_m.index_to_grid_pos(val,columns,i)
  local x = math.fmod(val-1,columns)+1
  local y = math.modf((val-1)/columns)+1
  return {x,y}
end

function f_m.draw_square(x,y)
  for i = 1,16 do
    screen.pixel(x+f_m.index_to_grid_pos(i,4)[1],y+f_m.index_to_grid_pos(i,4)[2])
  end
end

function f_m.draw_song_menu()
  screen.move(0,10)
  screen.font_size(12)
  screen.level(15)
  screen.text("SONG")
  screen.font_size(8)
  if _fm_.alt then
    screen.level(3)
    screen.move(0,25)
    screen.text("K1 + K2:")
    screen.move(0,35)
    screen.text("DELETE")
    screen.move(0,50)
    screen.text("K1 + K3:")
    screen.move(0,60)
    screen.text("DUPL.")
  else
    screen.move(0,20)
    screen.level(2)
    screen.text("E1:")
    for i = 1,4 do
      -- screen.move(8,12+(11*i))
      screen.move(0,20+(10*i))
      screen.level(_fm_.group == i and 15 or 1)
      screen.text("GROUP "..groups[i])
    end
  end
  screen.level(15)
  screen.move(37,0)
  screen.line(37,64)
  screen.stroke()
  local col_starts = {40}
  if _fm_.main_sel == 3 then
    screen.level(15)
    screen.move(col_starts[1],6)
    screen.text("#")
    screen.move(57,6)
    screen.circle(57,5,2)
    screen.fill()
    screen.move(59,6)
    screen.line(59,0)
    screen.stroke()
    for i = 1,4 do
      screen.move(72+((i-1)*14),6)
      screen.text_center(i)
    end
    screen.level(3)
    local sel_x = 52+(f_m.index_to_grid_pos(_fm_.song_col[_fm_.group],5)[1]-1)*14
    local sel_y = 3+(10*util.wrap(_fm_.song_line[_fm_.group],1,5))
    screen.rect(sel_x,sel_y,13,8)
    screen.fill()
    screen.move(37,10)
    screen.line(128,10)
    screen.stroke()
    local _v = _fm_.group
    local page = f_m.index_to_grid_pos(_fm_.song_line[_fm_.group],5)[2] - 1 -- only minus 1 cuz of reasons...
    screen.font_face(2)
    for i = 1+(25*page), 25+(25*page) do
      screen.move(58+(f_m.index_to_grid_pos(util.wrap(i,1,25),5)[1]-1)*14,10+(10*f_m.index_to_grid_pos(util.wrap(i,1,25),5)[2]))
      screen.level((_fm_.song_col[_fm_.group] == f_m.index_to_grid_pos(i,5)[1] and _fm_.song_line[_fm_.group] == f_m.index_to_grid_pos(i,5)[2]) and 0 or 15)
      if f_m.index_to_grid_pos(util.wrap(i,1,25),5)[1] == 1 and f_m.index_to_grid_pos(i,5)[2] <= song_atoms[_v].end_point then
        screen.text_center(song_atoms[_v].lane[f_m.index_to_grid_pos(i,5)[2]].beats)
        screen.level(15)
        screen.move(col_starts[1]+(f_m.index_to_grid_pos(util.wrap(i,1,25),5)[1]-1)*18,10+(10*f_m.index_to_grid_pos(util.wrap(i,1,25),5)[2]))
        screen.text(string.format("%02d",f_m.index_to_grid_pos(i,5)[2]))
      elseif (f_m.index_to_grid_pos(util.wrap(i,1,25),5)[1] == 2
        or f_m.index_to_grid_pos(util.wrap(i,1,25),5)[1] == 3
        or f_m.index_to_grid_pos(util.wrap(i,1,25),5)[1] == 4
        or f_m.index_to_grid_pos(util.wrap(i,1,25),5)[1] == 5)
        and f_m.index_to_grid_pos(i,5)[2] <= song_atoms[_v].end_point then
        local target = song_atoms[_v].lane[f_m.index_to_grid_pos(i,5)[2]][pattern_names[f_m.index_to_grid_pos(i,5)[1]-1]].target
        if target > 0 then
          if target <= 16 then
            target = 'P'..target
          elseif target <= 24 then
            target = 'H'..(target-16)
          end
        else
          target = target == 0 and "-" or "XX"
        end
        screen.text_center(target)
      end
    end
    screen.font_face(1)
    screen.level(15)
    if song_atoms[_fm_.group].current > 5*page and song_atoms[_fm_.group].current <= 5*(page+1) then
      screen.move(128,10+(10*(song_atoms[_fm_.group].current - 5*page)))
      screen.text_right("<")
    end
    if page < f_m.index_to_grid_pos(song_atoms[_v].end_point,5)[2]-1 then
      screen.move(128,8)
      screen.text_right("▼")
    end
    if page > f_m.index_to_grid_pos(song_atoms[_v].start_point,5)[2]-1 then
      screen.move(128,4)
      screen.text_right("▲")
    end
  end
end

function f_m.draw_transport_menu()
  screen.move(0,10)
  screen.font_size(12)
  screen.level(15)
  screen.text("TRANSPORT")
  screen.font_size(8)
  screen.move(0,35)
  local show_me_frac = math.fmod(clock.get_beats(),1)
  if show_me_frac <= 0.25 then
    show_me_frac = 1
  else
    show_me_frac = 4
  end
  if show_me_frac == 1 then
    screen.level(15)
  else
    screen.level(3)
  end
  screen.font_size(18)
  screen.text(params:get("clock_tempo").." bpm")
  screen.move(0,58)
  screen.level(15)
  screen.font_size(14)
  screen.text("K3: "..(song_atoms.transport_active and "STOP" or "START"))
end

function f_m.process_encoder(n,d)
  if not key2_hold then
    if n == 1 then
      page.flow.group = util.clamp(page.flow.group + d,1,4)
    elseif n == 2 then
      if _fm_.song_col[_fm_.group] == 5 then
        if d > 0 then
          local current_line = _fm_.song_line[_fm_.group]
          _fm_.song_line[_fm_.group] = util.clamp(_fm_.song_line[_fm_.group] + d,1,song_atoms[_fm_.group].end_point)
          if (_fm_.song_line[_fm_.group] ~= song_atoms[_fm_.group].start_point) and (_fm_.song_line[_fm_.group] ~= song_atoms[_fm_.group].end_point) then
            _fm_.song_col[_fm_.group] = 1
          elseif current_line ~= _fm_.song_line[_fm_.group] then
            _fm_.song_col[_fm_.group] = 1
          end
        else
          _fm_.song_col[_fm_.group] = util.clamp(_fm_.song_col[_fm_.group] + d,1,5)
        end
      elseif _fm_.song_col[_fm_.group] == 2 or _fm_.song_col[_fm_.group] == 3 or _fm_.song_col[_fm_.group] == 4 then
        _fm_.song_col[_fm_.group] = util.clamp(_fm_.song_col[_fm_.group] + d,1,5)
      elseif _fm_.song_col[_fm_.group] == 1 then
        if d < 0 then
          local current_line = _fm_.song_line[_fm_.group]
          _fm_.song_line[_fm_.group] = util.clamp(_fm_.song_line[_fm_.group] + d,1,song_atoms[_fm_.group].end_point)
          if (_fm_.song_line[_fm_.group] ~= song_atoms[_fm_.group].start_point) and (_fm_.song_line[_fm_.group] ~= song_atoms[_fm_.group].end_point) then
            _fm_.song_col[_fm_.group] = 5
          elseif current_line ~= _fm_.song_line[_fm_.group] then
            _fm_.song_col[_fm_.group] = 5
          end
        else
          _fm_.song_col[_fm_.group] = util.clamp(_fm_.song_col[_fm_.group] + d,1,5)
        end
      end
    elseif n == 3 then
      local group = _fm_.group
      local line = _fm_.song_line[group]
      local col = _fm_.song_col[group]
      if col == 1 then
        song_atoms[group].lane[line].beats = util.clamp(song_atoms[group].lane[line].beats + d,1,128)
      elseif col >= 2 and col <= 5 then
        song_atoms[group].lane[line][pattern_names[col-1]].target = util.clamp(song_atoms[group].lane[line][pattern_names[col-1]].target + d,-1,25)
      -- elseif col == 3 then
      --   if _fm_.alt then
      --     song_atoms[_fm_.group].lane[line].snapshot_restore_mod_index = util.clamp(song_atoms[_fm_.group].lane[line].snapshot_restore_mod_index + d, 0,8)
      --   else
      --     song_atoms[_fm_.group].lane[line].snapshot.target = util.clamp(song_atoms[_fm_.group].lane[line].snapshot.target + d,-1,16)
      --   end
      end
    end
  else
    if n == 2 then
      params:delta("clock_tempo",d)
    elseif n == 3 then
      params:delta("clock_tempo",d/10)
    end
  end
end

function f_m.process_key(n,z)
  if n == 3 and z == 1 then
    if not key2_hold then
      if _fm_.menu_layer == 1 then
        _fm_.menu_layer = 3
      elseif _fm_.menu_layer == 3 then
        if _fm_.main_sel == 3 then
          if not _fm_.alt then
            _song.add_line(_fm_.group,_fm_.song_line[_fm_.group])
          else
            _song.duplicate_line(_fm_.group,_fm_.song_line[_fm_.group])
          end
        elseif _fm_.main_sel == 2 then
          if _fm_.alt then
            if _fm_.scene_line_sel > 1 then
              snapshot.seed_restore_state_to_all(_fm_.group,track[_fm_.group].snapshot.focus,snapshot_restore_params[_fm_.scene_line_sel-1])
            end
          end
        end
      end
    else
      if song_atoms.transport_active then
        clock.transport.stop()
      else
        if params:string("clock_source") == "internal" then
          clock.internal.start(-0.1)
        end
        clock.transport.start()
        for i = 1,number_of_hills do
          if clock.threads[track_clock[i]] then
            clock.cancel(track_clock[i])
          end
          if params:string('hill_'..i..'_iterator') == 'norns' then
            _htracks.start_playback(i, track[i].active_hill)
            track_clock[i] = clock.run(_htracks.iterate,i)
          end
        end
      end
    end
  elseif n == 2 and z == 1 then
    if _fm_.alt then
      _song.remove_line(_fm_.group,_fm_.song_line[_fm_.group])
    else
      key2_hold_counter:start()
    end
  elseif n == 2 and z == 0 and not ignore_key2_up and not _fm_.alt then
    if key2_hold == false then
      key2_hold_counter:stop()
      ui.control_set = "play"
    else
      key2_hold = false
    end
  elseif n == 2 and z == 0 and ignore_key2_up and not _fm_.alt then
    ignore_key2_up = false
  elseif n == 1 then
    _fm_.alt = z == 1
  end
end

return flow_menu