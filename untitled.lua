local Formatters=require 'formatters'
engine.name = "Krick"

default_values =
{
  ["bd"] =
  {
    ["PTCH"] = 36,
    ["DEC"] = 76
  }
}

function add_params()
  for i = 1,2 do
    params:add_separator("voice "..i)
    params:add_option(i.."_voice","voice",{"bd","sd","xt","cp","rs","cb","hh","cy"})
    params:add_number(i.."_ptch","PTCH",0,127,36)
  end
end

function go()
  _1 = clock.run(function()
    while true do
      clock.sync(1/3)
      trigger("hh",1)
    end
  end
  )
  _2 = clock.run(function()
    while true do
      clock.sync(1/math.random(1,3))
      trigger("xt",2)
    end
  end
  )
  -- _2 = clock.run(function()
  --   while true do
  --     clock.sync(math.random(1,2)/math.random(1,3))
  --     trigger("xt",2)
  --   end
  -- end
  -- )
  _3 = clock.run(function()
    while true do
      clock.sync(math.random(1,3)/math.random(1,3))
      trigger("cp",3)
    end
  end
  )
  _4 = clock.run(function()
    while true do
      clock.sync(math.random(3,6)/math.random(1,8))
      trigger("cb",4)
    end
  end
  )
end

function stop()
  clock.cancel(_1)
  clock.cancel(_2)
  clock.cancel(_3)
  clock.cancel(_4)
end


function init()
  add_params()
end
  --     \out,0,
		-- 	\md_amp,msg[3],
		-- 	\md_carHz,msg[4],
		-- 	\md_carAtk,msg[5],
		-- 	\md_carRel,msg[6],
		-- 	\md_rampDepth,msg[7],
		-- 	\md_rampDec,msg[8],
		-- 	\md_modAmp,msg[9],
		-- 	\md_modHz,msg[10],
		-- 	\md_modAtk,msg[11],
		-- 	\md_modRel,msg[12],
		-- 	\md_feedAmp,msg[13],
		-- 	\md_click,msg[14],
		-- 	\md_AMD,msg[15],
		-- 	\md_AMF,msg[16],
		-- 	\md_LPfreq,msg[17],
		-- 	\md_HPfreq,msg[18],
		-- 	\md_filterQ,msg[19],
		-- 	\md_pan,msg[20],
		-- 	\md_brate,msg[21],
		-- 	\md_bcnt,msg[22]

function key(n,z)
  if n == 3 and z == 1 then
    trigger("xt",2)
  end
  if n == 2 and z == 1 then
    -- engine.trig(1,"bd",1,math.random(130,140),0,2,0,0,120,600,0,0,0.2,1,0,0,19000,20,1,0,24000,12)
    -- engine.trig(1,"sd",
    --   1,
    --   277.2,
    --   0,
    --   0.2,
    --   0.06,
    --   0.1,
    --   10,
    --   700,
    --   0,
    --   0.2,
    --   0,
    --   1,
    --   0,
    --   0,
    --   19000,
    --   20,
    --   1,
    --   0,
    --   24000,
    --   12
    --   )
    -- engine.trig(1,"cp",
    --   1,
    --   450,
    --   0,
    --   0.5,
    --   0,
    --   0,
    --   127,
    --   300,
    --   0,
    --   0.5,
    --   10,
    --   0,
    --   0,
    --   0,
    --   19000,
    --   20,
    --   1,
    --   0,
    --   24000,
    --   16
    --   )
    -- engine.trig(1,"cb",
    --   1,
    --   404,
    --   0,
    --   0.3,
    --   0,
    --   4,
    --   0,
    --   404,
    --   0,
    --   0.3,
    --   0,
    --   1,
    --   0,
    --   303,
    --   19000,
    --   600,
    --   0.3,
    --   0,
    --   24000,
    --   24
    --   )
    trigger("hh",1)
    end
end

function trigger(synth,id)
  if synth == "hh" then
    engine.hh(id,
      0.3,
      100,
      0,
      math.random(1,50)/100,
      math.random(),
      math.random(3,100),
      0,
      110,
      0,
      2,
      10,
      0,
      303,
      math.random(14000,19000),
      math.random(600,19000),
      0.3,
      math.random(-60,60)/100,
      24000,
      16
    )
  elseif synth == "xt" then
    engine.trig(id,"xt",
      1.4,
      87.3,
      0,
      0.3,
      0.3,
      0.1,
      math.random(100),
      math.random(1,87*3),
      0,
      0.2,
      21,
      1,
      0,
      0,
      19000,
      20,
      1,
      0,
      24000,
      12
    )
  elseif synth == "cp" then
    engine.trig(id,"cp",
      1,
      450,
      0,
      0.5,
      0,
      0,
      127,
      300,
      0,
      0.5,
      10,
      0,
      0,
      0,
      19000,
      20,
      1,
      math.random(-30,30)/100,
      24000,
      16
    )
  elseif synth == "cb" then
    engine.trig(1,"cb",
      1,
      808/(math.random(6)),
      0,
      math.random(10,100)/100,
      0,
      4,
      0,
      808*math.random(10),
      0,
      math.random(0,3)/10,
      math.random(100),
      1,
      0,
      303,
      math.random(1000,9000),
      math.random(600,19000),
      0.3,
      math.random(-10,20)/100,
      24000,
      24
    )
  end
end