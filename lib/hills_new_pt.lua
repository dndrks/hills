--- timed pattern event recorder/player
-- @module lib.pattern

local pattern = {}
pattern.__index = pattern

--- constructor
function pattern.new(id)
  local i = {}
  setmetatable(i, pattern)
  i.rec = 0
  i.play = 0
  i.overdub = 0
  i.event = {}
  i.count = 0
  i.end_point = 0
  i.step = 0
  i.steps_with_mono_events = {}
  i.mono_event_idx = 0
  i.loop = 1
  i.clear_mono = 0
  i.name = id

  i.process = function(_) print("event") end

  return i
end

--- clear this pattern
function pattern:clear()
  print('pattern clear')
  self:end_playback()
  self.rec = 0
  self:set_overdub(0)
  self.event = {}
  self.count = 0
  self.clear_mono = 0
  self.step = 0
  self.steps_with_mono_events = {}
  self.mono_event_idx = 0
  if self.clock then
    clock.cancel(self.clock)
    self.clock = nil
  end
end

--- start recording
function pattern:rec_start()
  self.rec = 1
  self:begin_playback()
end

function pattern:begin_playback()
  if self.clock ~= nil then
    clock.cancel(self.clock)
  end
  self.step = 0
  self.play = 1
  self.clock = clock.run(
    function()
      print('starting playback', self.name)
      -- while true do
      while self.play == 1 do
        clock.sync(1/48)
        if self.step == 0 and self.start_callback ~= nil then
          self.start_callback()
        end
        self.step = self.step + 1
        if self.end_point ~= 0 then
          if self.event[self.step] and next(self.event[self.step]) ~= nil then
            for i = 1,#self.event[self.step] do
              self.process(self.event[self.step][i])
            end
            if self.event[self.step].parameter_value_change ~= nil then
              self.process(self.event[self.step].parameter_value_change)
            end
          end
          if self.step >= self.end_point then
            if self.loop == 0 then
              print('end loop')
              self:end_playback()
            elseif self.loop == 1 then
              self.step = 0
            end
          end
        end
      end
    end
  )
end

function pattern:end_playback()
  self.play = 0
  -- if self.clock then clock.cancel(self.clock) end
  print('clock ending')
  -- self.step = 0
end

--- stop recording
function pattern:rec_stop()
  self.rec = 0
  self.end_point = self.step
  print('rec stop')
  self:end_playback()
end

--- watch
function pattern:watch(e)
  if self.rec == 1 then
    self:rec_event(e)
  elseif self.overdub == 1 then
    self:rec_event(e)
  end
end

function pattern:watch_mono(e)
  if self.rec == 1 and self.clear_mono ~= 1 then
    self:rec_event_mono(e)
  elseif self.overdub == 1 and self.clear_mono ~= 1 then
    -- self:overdub_event(e)
    self:rec_event_mono(e)
  end
end

--- record event
function pattern:rec_event(e)
  if self.event[self.step] == nil then
    self.event[self.step] = {}
  end
  -- table.insert(self.event[self.step],e) -- inefficient!
  local current_size = #self.event[self.step] + 1
  self.event[self.step][current_size] = e
  self.count = self.count + 1
end

--- record event (mono)
function pattern:rec_event_mono(e)
  -- 
  if not self.event[self.step] then
    self.event[self.step] = {}
    self.event[self.step][1] = {
      ['event'] = e.event,
      ['voice'] = e.voice,
      ['model'] = e.model,
      ['param'] = e.param,
      ['value'] = e.value
    }
    self.steps_with_mono_events[self.step] = true
    self.count = self.count + 1
    -- print('creating first entry for mono event',self.step,e.param, e.value)
  else
    -- what if the step exists, but the mono data doesn't?
    local register_a_new_mono_step, already_registered_index;
    for i = 1,#self.event[self.step] do
      if self.event[self.step][i].event == e.event
      and self.event[self.step][i].voice == e.voice
      and self.event[self.step][i].model == e.model
      and self.event[self.step][i].param == e.param
      then
        register_a_new_mono_step = false
        already_registered_index = i
        print(already_registered_index)
        break
      else
        register_a_new_mono_step = true
      end
    end
    if register_a_new_mono_step == true then
      self.event[self.step][#self.event[self.step] + 1] = {
        ['event'] = e.event,
        ['voice'] = e.voice,
        ['model'] = e.model,
        ['param'] = e.param,
        ['value'] = e.value
      }
      self.steps_with_mono_events[self.step] = true
      -- print('baking a new mono data step',self.step,e.param, e.value)
    elseif register_a_new_mono_step == false then
      self.event[self.step][already_registered_index] = {
        ['event'] = e.event,
        ['voice'] = e.voice,
        ['model'] = e.model,
        ['param'] = e.param,
        ['value'] = e.value
      }
      -- print('overwriting a mono data step',self.step, already_registered_index, e.param, e.value)
    end
  end
end

function pattern:clear_mono_events(e)
  for i = 0,self.end_point do
    if self.event[i] then
      for j = 1,#self.event[i] do
        if self.event[i][j]
        and self.event[i][j].voice == e.voice
        and self.event[i][j].model == e.model
        and self.event[i][j].param == e.param
        then
          self.event[i][j] = nil
          if #self.event[i] == 0 then
            self.event[i] = nil
          end
        end
      end
    end
  end
  if e.model == params:string('voice_model_'..e.voice) then
    prms.send_to_engine(e.voice, e.param, e.value)
  end
end

--- start this pattern
function pattern:start()
  if self.count > 0 then
    --print("start pattern ")
    self.play = 1
    self:begin_playback()
    -- if self.start_callback ~= nil then
    --   self.start_callback()
    -- end
  end
end

--- stop this pattern
function pattern:stop()
  if self.play == 1 then
    self.play = 0
    -- self.overdub = 0
    self:set_overdub(0)
    print('stop')
    self:end_playback()
  end
end

-- duplicate the pattern 
function pattern:duplicate()
  if self.end_point > 0 then
    for i = 1,self.end_point do
      self.event[i+self.end_point] = self.deep_copy(self.event[i])
    end
    self.count = self.count * 2
    self.end_point = self.end_point * 2
  end
end

--- set overdub
function pattern:set_overdub(s)
  if s==1 and self.play == 1 and self.rec == 0 then
    self.overdub = 1
  else
    self.overdub = 0
  end
  if self.overdub_action ~= nil then
    self.overdub_action(self.name,self.overdub == 1)
  end
end

function pattern.deep_copy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == "table" then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[pattern.deep_copy(orig_key)] = pattern.deep_copy(orig_value)
    end
    setmetatable(copy, pattern.deep_copy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

return pattern