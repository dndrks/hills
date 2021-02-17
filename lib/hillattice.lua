local hillattice = {}

function hillattice.init(i)
  hills[i].pattern = hills.lattice:new_pattern{
    action = function() hillattice.iterate(i) end,
    division = 1/32,
    enabled = true
  }
  hills[i].pattern.sub_step = 0
  hills[i].pattern.index = 0
  hills[i].pattern.bar = 0
  hills[i].pattern.bar_max = 4
  hills[i].pattern.rec = false
  hills[i].pattern.entries = {}
  for j = 1,128 do
    hills[i].pattern.entries[j] = {}
  end
end

function hillattice.iterate(i)
  local h = hills[i].pattern
  h.index = util.wrap(h.index + 1,0,util.round(1/h.division)-1)
  if h.index == 1 then
    h.bar = util.wrap(h.bar + 1,1,h.bar_max)
    print("tick "..i, clock.get_beats(), h.bar)
  end
  if h.entries[h.bar][h.index] ~= nil then
    local event = h.entries[h.bar][h.index]
    local param,val = event:match("(.+): (.+)")
    print("here's a "..param, val, print(clock.get_beats()))
    _G[param](i,tonumber(val)) -- fuck this is cool...
  end
end

function hillattice.blast_off()
  clock.run(function() clock.sync(4) hills.lattice:hard_sync() end); print(clock.get_beats())
end

function hillattice.timed_reset(i)
  clock.run(function() clock.sync(4) p_rec.hard_reset(i) end); print(clock.get_beats())
end

function hillattice.hard_reset(i)
  hills[i].pattern.sub_step = 0
  hills[i].pattern.index = 0
  hills[i].pattern.bar = 0
end

function hillattice.add_event(i,param)
  local h = hills[i].pattern
  if h.rec then
    h.entries[h.bar][h.index] = param
    print(clock.get_beats())
  end
end

return hillattice