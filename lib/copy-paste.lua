local copy_paste = {}

-- RULES
-- if we're on a trigger-only page,
-- then copying the pattern or page data will only
-- copy trigger data.
-- if we have the conditional page up (for example),
-- then copying the page data will copy the conditional data for that page...
-- yeah? feel useful?

-- SOURCES
-- pattern data (8 pages)
-- page data (all steps on the page)
-- step data

-- tab.print(track[1][1][1])
  -- base_note	table: 0x63abb0
  -- prob	table: 0x63ae48
  -- last_condition	false
  -- accented_trigs	table: 0x63add0
  -- chord_degrees	table: 0x63ac28
  -- end_point	16
  -- velocities	table: 0x63ac50
  -- chord_notes	table: 0x63ac00
  -- lock_trigs	table: 0x63ae20
  -- micro	table: 0x63ae70
  -- conditional	table: 0x63aec0
  -- fill	table: 0x63afd8
  -- er	table: 0x63ae98
  -- seed_default_note	table: 0x63abd8
  -- legato_trigs	table: 0x63adf8
  -- muted_trigs	table: 0x63ada8
  -- trigs	table: 0x63ad80
  -- start_point	1

  -- oh, fill has a data structure as well...LOL

local cp = copy_paste

copied_data = {}
original_data = {}
undo_data = {}
for i = 1,7 do
  undo_data[i] = {}
end

target_parameters = {
  ["page: trigs"] = {
    'start_point',
    'end_point',
    'base_note',
    'accented_trigs',
    'legato_trigs',
    'muted_trigs',
    'trigs',
  }
}

function cp.clipboard(i,j,page,modifier,action)
  if action == "copy" then
    copied_data[i] = {}
    for prm = 1,#target_parameters[modifier] do
      local id = target_parameters[modifier][prm]
      copied_data[i][id] = _t.deep_copy(track[i][j][page][id])
    end
    -- if modifier == "page: trigs" then
    --   copied_data[i][j][page].start_point = _t.deep_copy(track[i][j][page].start_point)
    --   copied_data[i][j][page].end_point = _t.deep_copy(track[i][j][page].end_point)
    --   copied_data[i][j][page].base_note = _t.deep_copy(track[i][j][page].base_note)
    --   copied_data[i][j][page].accented_trigs = _t.deep_copy(track[i][j][page].accented_trigs)
    --   copied_data[i][j][page].legato_trigs = _t.deep_copy(track[i][j][page].legato_trigs)
    --   copied_data[i][j][page].muted_trigs = _t.deep_copy(track[i][j][page].muted_trigs)
    --   copied_data[i][j][page].trigs = _t.deep_copy(track[i][j][page].trigs)
    -- end
  elseif action == "paste" then
    if modifier == "page: trigs" then
      if copied_data[i] ~= nil then
        original_data[i] = {[j] = {[page] = {}}}
        for prm = 1,#target_parameters[modifier] do
          local id = target_parameters[modifier][prm]
          original_data[i][j][page][id] = _t.deep_copy(track[i][j][page][id])
          track[i][j][page][id] = _t.deep_copy(copied_data[i][id])
        end
        undo_data[i] = _t.deep_copy(original_data[i])
        undo_data[i]["header"] = {
          ['j'] = j,
          ['page'] = page,
          ['modifier'] = modifier
        }
      end
      -- original_data[page].start_point = _t.deep_copy(track[i][j][page].start_point)
      -- original_data[page].end_point = _t.deep_copy(track[i][j][page].end_point)
      -- original_data[page].base_note = _t.deep_copy(track[i][j][page].base_note)
      -- original_data[page].accented_trigs = _t.deep_copy(track[i][j][page].accented_trigs)
      -- original_data[page].legato_trigs = _t.deep_copy(track[i][j][page].legato_trigs)
      -- original_data[page].muted_trigs = _t.deep_copy(track[i][j][page].muted_trigs)
      -- original_data[page].trigs = _t.deep_copy(track[i][j][page].trigs)
      -- track[i][j][page].start_point = _t.deep_copy(copied_data[i][j][page].start_point)
      -- track[i][j][page].end_point = _t.deep_copy(copied_data[i][j][page].end_point)
      -- track[i][j][page].base_note = _t.deep_copy(copied_data[i][j][page].base_note)
      -- track[i][j][page].accented_trigs = _t.deep_copy(copied_data[i][j][page].accented_trigs)
      -- track[i][j][page].legato_trigs = _t.deep_copy(copied_data[i][j][page].legato_trigs)
      -- track[i][j][page].muted_trigs = _t.deep_copy(copied_data[i][j][page].muted_trigs)
      -- track[i][j][page].trigs = _t.deep_copy(copied_data[i][j][page].trigs)
    end
  elseif action == "undo" then
    local _u = undo_data[i].header
    if _u ~= nil then
      local _j = _u.j
      local _page = _u.page
      local _modifier = _u.modifier
      for prm = 1,#target_parameters[_modifier] do
        local id = target_parameters[_modifier][prm]
        track[i][_j][_page][id] = _t.deep_copy(undo_data[i][_j][_page][id])
      end
    end
  end
end

return copy_paste