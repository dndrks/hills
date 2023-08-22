local Engine = {}

-- currently loaded name
Engine.name = nil

function Engine.load(engine_name)
  osc.send({'127.0.0.1','57120'},"/engine/load/name",{engine_name})
end

function Engine.command(action, args)
  osc.send({'127.0.0.1','57120'},"/command/"..action,{table.unpack(args)})
end

return Engine