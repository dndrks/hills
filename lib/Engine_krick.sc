Engine_Krick : CroneEngine {
	var pg;
	var synthArray;
	var bd_amp;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
		pg = ParGroup.tail(context.xg);
		synthArray = Array.newClear(10);

		SynthDef("bd", {
			arg out, md_amp = 2, md_carHz = 55, md_carAtk = 0, md_carRel = 0.3,
			md_modHz = 600, md_modAmp = 127, md_modAtk = 0, md_modRel = 0.05, md_feedAmp = 10,
			md_pan = 0, md_rampDepth = 0.5, md_rampAtk = 0, md_rampDec = 0.3,
			md_AMD = 1, md_AMF = 2698.8,
			md_EQF = 6000, md_EQG = 0, md_brate = 24000, md_bcnt = 24,
			md_click = 1, md_LPfreq = 19000, md_HPfreq = 0, md_filterQ = 1,
			kill_gate = 1;
			var md_car, md_mod, md_carEnv, md_modEnv, md_carRamp,
			md_feedMod, md_feedCar, md_ampMod, md_EQ,md_clicksound,
			mod_1,slewLP, slewHP;
			md_modEnv = EnvGen.kr(Env.perc(md_modAtk, md_modRel),gate: kill_gate);
			md_carRamp = EnvGen.kr(Env([1000, 0.000001], [md_rampDec], curve: \exp));
			md_carEnv = EnvGen.kr(envelope: Env.perc(md_carAtk, md_carRel),gate: kill_gate);

			mod_1 = SinOscFB.ar(
				md_modHz+ ((md_carRamp*3)*md_rampDepth),
				md_feedAmp,
				md_modAmp*10
			)* md_modEnv;

			md_car = SinOsc.ar(md_carHz + (mod_1) + (md_carRamp*md_rampDepth)) * md_carEnv * md_amp;
			md_ampMod = SinOsc.ar(freq:md_AMF,mul:(md_AMD/2),add:1);
			md_click = md_amp/4;
			md_clicksound = LPF.ar(Impulse.ar(0.003),16000,md_click) * EnvGen.kr(envelope: Env.perc(md_carAtk, 0.2),gate: kill_gate);
			md_car = (md_car + md_clicksound)* md_ampMod;

			md_car = BPeakEQ.ar(in:md_car,freq:md_EQF,rq:1,db:md_EQG,mul:1);
			slewLP = Lag2.kr(md_LPfreq,0.1);
			slewHP = Lag2.kr(md_HPfreq,0.1);
			md_car = RLPF.ar(in:md_car,freq:slewLP, rq: md_filterQ, mul:1);
			md_car = RHPF.ar(in:md_car,freq:slewHP, rq: md_filterQ, mul:1);

			md_car = Decimator.ar(Pan2.ar(md_car,md_pan),md_brate,md_bcnt,1.0);
			Out.ar(out, md_car);

			FreeSelf.kr(Done.kr(md_carEnv) * Done.kr(md_modEnv));
		}).add;

		SynthDef("sd", {
			arg out, md_carHz = 277.2, md_modHz = 700, md_modAmp = 10, md_modAtk = 0,
			md_modRel = 0.2, md_carAtk = 0, md_carRel = 0.2, md_amp = 1, md_pan = 0,
			md_rampDepth = 0.06, md_rampDec = 0.1, md_feedAmp = 0, md_noiseAmp = 1,
			md_noiseAtk = 0, md_noiseRel = 1, md_brate = 48000.0, md_bcnt = 24,
			md_EQF = 12000,md_EQG = 20, md_click = 1,
			md_LPfreq = 19000, md_HPfreq = 0, md_filterQ = 1,
			md_AMD = 0, md_AMF = 2698.8,
			kill_gate = 1;
			var md_car, md_mod, md_carEnv, md_modEnv, md_carRamp, md_feedMod, md_feedCar,
			md_noise, md_noiseEnv, md_mix,slewLP, slewHP, md_ampMod;

			md_modEnv = EnvGen.kr(Env.perc(md_modAtk, md_modRel));
			md_carRamp = EnvGen.kr(Env([1000, 0.000001], [md_rampDec], curve: \exp));
			md_carEnv = EnvGen.kr(Env.perc(md_carAtk, md_carRel),gate: kill_gate);
			md_feedMod = SinOsc.ar(md_modHz, mul:md_modAmp*100) * md_modEnv;
			md_feedCar = SinOsc.ar(md_carHz + md_feedMod + (md_carRamp*md_rampDepth)) * md_carEnv * (md_feedAmp*10);
			md_mod = SinOsc.ar(md_modHz + md_feedCar, mul:md_modAmp*100) * md_modEnv;
			md_car = SinOsc.ar(md_carHz + md_mod + (md_carRamp*md_rampDepth)) * md_carEnv * md_amp;
			md_noiseEnv = EnvGen.kr(Env.perc(md_noiseAtk,md_noiseRel),gate: kill_gate);
			md_noise = BPF.ar(WhiteNoise.ar,8000,1.3) * (md_noiseAmp*md_noiseEnv);
			md_noise = BPeakEQ.ar(in:md_noise,freq:md_EQF,rq:1,db:md_EQG,mul:1);
			md_noise = RLPF.ar(in:md_noise,freq:md_LPfreq, rq: md_filterQ, mul:1);
			md_noise = RHPF.ar(in:md_noise,freq:md_HPfreq, rq: md_filterQ, mul:1);

			md_ampMod = SinOsc.ar(freq:md_AMF,mul:(md_AMD/2),add:1);

			md_car = BPeakEQ.ar(in:md_car,freq:md_EQF,rq:1,db:md_EQG,mul:1);
			slewLP = Lag2.kr(md_LPfreq,0.1);
			slewHP = Lag2.kr(md_HPfreq,0.1);
			md_car = RLPF.ar(in:md_car,freq:slewLP, rq: md_filterQ, mul:1);
			md_car = RHPF.ar(in:md_car,freq:slewHP, rq: md_filterQ, mul:1);

			md_mix = Decimator.ar(md_car,md_brate,md_bcnt,1.0);
			Out.ar(out, Pan2.ar(md_mix,md_pan));
			Out.ar(out, Pan2.ar(md_noise,md_pan));
			FreeSelf.kr(Done.kr(md_carEnv) * Done.kr(md_noiseEnv));
		}).add;

		SynthDef("xt", {
			arg out, md_carHz = 87.3,
			md_modHz = 174.6, md_modAmp = 100, md_modAtk = 0, md_modRel = 0.2, md_feedAmp = 21,
			md_carAtk = 0, md_carRel = 0.3, md_amp = 1,
			md_click = 1,
			md_pan = 0, md_rampDepth = 0.3, md_rampDec = 0.13, md_AMD = 0, md_AMF = 2698.8,
			md_EQF = 6000, md_EQG = 0, bdx_fMorph = 0, md_brate = 24000, md_bcnt = 24,
			md_LPfreq = 19000, md_HPfreq = 0, md_filterQ = 1,
			kill_gate = 1;
			var md_car, md_mod, md_carEnv, md_modEnv, md_carRamp, md_feedMod,
			md_feedCar, md_ampMod, md_EQ, md_clicksound,
			mod_1,slewLP, slewHP;
			md_modEnv = EnvGen.kr(Env.perc(md_modAtk, md_modRel));
			md_carRamp = EnvGen.kr(Env([600, 0.000001], [md_rampDec], curve: \lin));
			md_carEnv = EnvGen.kr(Env.perc(md_carAtk, md_carRel), gate: kill_gate, doneAction:2);

			mod_1 = SinOscFB.ar(
				md_modHz,
				md_feedAmp,
				md_modAmp*10
			)* md_modEnv;

			md_car = SinOsc.ar(md_carHz + (mod_1) + (md_carRamp*md_rampDepth)) * md_carEnv * md_amp;

			md_ampMod = SinOsc.ar(freq:md_AMF,mul:md_AMD,add:1);
			md_clicksound = LPF.ar(Impulse.ar(0.003),16000,md_click) * EnvGen.kr(envelope: Env.perc(md_carAtk, 0.2),gate: kill_gate);
			md_car = (md_car + md_clicksound) * md_ampMod;

			md_car = BPeakEQ.ar(in:md_car,freq:md_EQF,rq:1,db:md_EQG,mul:1);

			slewLP = Lag2.kr(md_LPfreq,0.1);
			slewHP = Lag2.kr(md_HPfreq,0.1);
			md_car = RLPF.ar(in:md_car,freq:slewLP, rq: md_filterQ, mul:1);
			md_car = RHPF.ar(in:md_car,freq:slewHP, rq: md_filterQ, mul:1);

			md_car = Decimator.ar(Pan2.ar(md_car,md_pan),md_brate,md_bcnt,1.0);
			Out.ar(out, md_car);
		}).add;

		SynthDef("cp", {
			arg out, md_carHz = 450,
			md_modHz = 300, md_modAmp = 127, md_modRel = 0.5, md_feedAmp = 10,
			md_carRel = 0.5, md_amp = 1, md_click = 1,
			md_pan = 0, md_AMD = 0, md_AMF = 127,
			md_EQF = 600, md_EQG = 0, md_brate = 24000, md_bcnt = 24,
			md_LPfreq = 19000, md_HPfreq = 600, md_filterQ = 0.3,
			kill_gate = 1;
			var md_car, md_mod, md_carEnv, md_modEnv, md_carRamp, md_feedMod, md_feedCar, md_ampMod, md_EQ,
			mod_1,mod_2,
			noise1,noise2,
			slewLP, slewHP;
			md_modEnv = EnvGen.ar(
				Env.new(
					[0, 1, 0, 0.9, 0, 0.7, 0, 0.5, 0],
					[0.001, 0.009, 0, 0.008, 0, 0.01, 0, md_modRel],
					curve: \lin
				),gate: kill_gate
			);
			md_carRamp = EnvGen.kr(Env([600, 0.000001], [0], curve: \lin));
			md_carEnv = EnvGen.ar(
				Env.new(
					[0, 1, 0, 0.9, 0, 0.7, 0, 0.5, 0],
					[0,0,0,0,0,0,0,md_carRel/4],
					[0, -3, 0, -3, 0, -3, 0, -3]
					// curve:\squared
				),gate: kill_gate
			);

			mod_2 = SinOscFB.ar(
				(md_modHz*4),
				md_feedAmp,
				0,
				md_modAmp*1
			)* md_modEnv;

			mod_1 = SinOscFB.ar(
				md_modHz+mod_2,
				md_feedAmp,
				md_modAmp*100
			)* md_modEnv;

			md_car = SinOsc.ar(md_carHz + (mod_1)) * md_carEnv * md_amp;
			md_car = RHPF.ar(in:md_car+(LPF.ar(Impulse.ar(0.003),12000,1)*md_click),freq:md_HPfreq,rq:md_filterQ,mul:1);

			md_ampMod = SinOsc.ar(freq:md_AMF,mul:md_AMD,add:1);
			md_car = md_car * md_ampMod;

			md_car = BPeakEQ.ar(in:md_car,freq:md_EQF,rq:1,db:md_EQG*15,mul:1);

			md_car = Decimator.ar(Pan2.ar(md_car,md_pan),md_brate,md_bcnt,1.0);

			slewLP = Lag2.kr(md_LPfreq,0.1);
			slewHP = Lag2.kr(md_HPfreq,0.1);
			md_car = RLPF.ar(in:md_car,freq:slewLP, rq: md_filterQ, mul:1);
			md_car = RHPF.ar(in:md_car,freq:slewHP, rq: md_filterQ, mul:1);

			md_car = md_car.softclip;
			Out.ar(out, md_car);
			FreeSelf.kr(Done.kr(md_modEnv) * Done.kr(md_carEnv));
		}).add;

		SynthDef("rs", {
			arg out, md_carHz = 3729,
			md_modHz = 4000, md_modAmp = 127,
			md_carAtk = 0, md_carRel = 0.05, md_amp = 0.4,
			tom_click = 1,
			md_pan = 0, md_rampDepth = 0, md_rampDec = 0, md_AMD = 0, md_AMF = 2698.8,
			md_EQF = 6000, md_EQG = 0, md_brate = 24000, md_bcnt = 24,

			sd_carHz = 277.2, sd_modHz = 700, sd_modAmp = 10, sd_modAtk = 0,
			sd_modRel = 0.05, sd_carAtk = 0, sd_carRel = 0.05, sd_amp = 1, sd_pan = 0,
			sd_rampDepth = 0.06, sd_rampDec = 1, sd_feedAmp = 10, sd_noiseAmp = 0,
			sd_noiseAtk = 0, sd_noiseRel = 1.4, sd_brate = 48000.0, sd_bcnt = 24,

			md_LPfreq = 19000, md_HPfreq = 600, md_filterQ = 0.3,
			sd_LPfreq = 19000, sd_HPfreq = 600, sd_filterQ = 0.3,
			kill_gate = 1;

			var md_car, md_mod, md_carEnv, md_modEnv, md_carRamp, md_feedMod, md_feedCar, md_ampMod, md_EQ,
			mod_1,mod_2,md_feedAmp,md_feedAMP,
			sd_car, sd_mod, sd_carEnv, sd_modEnv, sd_carRamp, sd_feedMod, sd_feedCar, sd_noise, sd_noiseEnv,
			sd_mix,
			slewLP, slewHP;

			md_modAmp = md_modAmp;
			md_feedAmp = md_modAmp.linlin(0, 127, 0, 3);
			md_feedAMP = md_modAmp.linlin(0, 127, 0, 4);
			md_carRamp = EnvGen.kr(Env([600, 0.000001], [md_rampDec], curve: \lin));
			md_carEnv = EnvGen.kr(Env.perc(md_carAtk, md_carRel),gate: kill_gate);

			mod_2 = SinOscFB.ar(
				md_modHz*16,
				md_feedAmp,
				md_modAmp*10
			)* 1;

			mod_1 = SinOscFB.ar(
				md_modHz+mod_2,
				md_feedAmp,
				md_modAmp*10
			)* 1;

			md_car = SinOscFB.ar(md_carHz + (mod_1+mod_2) + (md_carRamp*md_rampDepth),md_feedAMP) * md_carEnv * md_amp;

			md_ampMod = SinOsc.ar(freq:md_AMF,mul:md_AMD,add:1);
			md_car = (md_car+(LPF.ar(Impulse.ar(0.003),16000,1)*tom_click)) * md_ampMod;

			md_car = BPeakEQ.ar(in:md_car,freq:md_EQF,rq:1,db:md_EQG,mul:1);

			slewLP = Lag2.kr(md_LPfreq,0.1);
			slewHP = Lag2.kr(md_HPfreq,0.1);
			md_car = RLPF.ar(in:md_car,freq:slewLP, rq: md_filterQ, mul:1);
			md_car = RHPF.ar(in:md_car,freq:slewHP, rq: md_filterQ, mul:1);


			md_car = Decimator.ar(Pan2.ar(md_car,md_pan),md_brate,md_bcnt,1.0);
			md_car = LPF.ar(md_car,12000,1);
			Out.ar(out, md_car);

			sd_modHz = sd_carHz*2.52;
			sd_modEnv = EnvGen.kr(Env.perc(sd_modAtk, sd_modRel));
			sd_carRamp = EnvGen.kr(Env([1000, 0.000001], [sd_rampDec], curve: \exp));
			sd_carEnv = EnvGen.kr(Env.perc(sd_carAtk, sd_carRel),gate:kill_gate);
			sd_feedMod = SinOsc.ar(sd_modHz, mul:sd_modAmp*100) * sd_modEnv;
			sd_feedCar = SinOsc.ar(sd_carHz + sd_feedMod + (sd_carRamp*sd_rampDepth)) * sd_carEnv * (sd_feedAmp*10);
			sd_mod = SinOsc.ar(sd_modHz + sd_feedCar, mul:sd_modAmp*100) * sd_modEnv;
			sd_car = SinOsc.ar(sd_carHz + sd_mod + (sd_carRamp*sd_rampDepth)) * sd_carEnv * sd_amp;
			sd_noiseEnv = EnvGen.kr(Env.perc(sd_noiseAtk,sd_noiseRel));
			sd_noise = BPF.ar(WhiteNoise.ar,8000,1.3) * (sd_noiseAmp*sd_noiseEnv);
			sd_mix = Decimator.ar(sd_car,sd_brate,sd_bcnt,1.0);
			slewLP = Lag2.kr(sd_LPfreq,0.1);
			slewHP = Lag2.kr(sd_HPfreq,0.1);
			sd_mix = RLPF.ar(in:sd_mix,freq:slewLP, rq: sd_filterQ, mul:1);
			sd_mix = RHPF.ar(in:sd_mix,freq:slewHP, rq: sd_filterQ, mul:1);
			Out.ar(out, Pan2.ar(sd_mix,sd_pan));

			FreeSelf.kr(Done.kr(sd_carEnv) * Done.kr(md_carEnv));
		}).add;

		SynthDef("cb", {
			arg out, md_carHz = 404,
			md_modHz = 404, md_modAmp = 0, md_modAtk = 0, md_modRel = 0.3, md_feedAmp = 1,
			md_carAtk = 0, md_carRel = 0.3, md_amp = 1, click = 1,
			md_snap = 0,
			md_pan = 0, md_rampDepth = 0, md_rampDec = 4, md_AMD = 0, md_AMF = 303,
			md_EQF = 600, md_EQG = 0, md_brate = 24000, md_bcnt = 24,
			md_LPfreq = 19000, md_HPfreq = 600, md_filterQ = 0.3,
			kill_gate = 1;
			var md_car, md_mod, md_carEnv, md_modEnv, md_carRamp, md_feedMod, md_feedCar, md_ampMod, md_EQ,
			sig,md_1,md_2,klank_env,other_mod1,other_mod2,
			slewLP, slewHP;

			md_modEnv = EnvGen.kr(Env.perc(md_modAtk, md_modRel), gate:kill_gate);
			md_carRamp = EnvGen.kr(Env([600, 0.000001], [md_rampDec], curve: \lin));
			md_carEnv = EnvGen.kr(Env.perc(md_carAtk, md_carRel),gate: kill_gate);

			md_1 = LFPulse.ar((md_carHz) + (md_carRamp*md_rampDepth)) * md_carEnv * md_amp;
			md_1 = LPF.ar(md_1,md_feedAmp.linlin(0, 1, 500, 12000));
			md_2 = SinOscFB.ar((md_carHz*1.5085)+ (md_carRamp*md_rampDepth),md_feedAmp) * md_carEnv * md_amp;
			md_ampMod = SinOsc.ar(freq:md_AMF,mul:md_AMD,add:1);
			md_1 = (md_1+(LPF.ar(Impulse.ar(0.003),16000,1)*md_snap)) * md_ampMod;
			md_2 = (md_2+(LPF.ar(Impulse.ar(0.003),16000,1)*md_snap)) * md_ampMod;
			md_1 = BPeakEQ.ar(in:md_1,freq:md_EQF,rq:1,db:md_EQG,mul:1);
			md_2 = BPeakEQ.ar(in:md_2,freq:md_EQF,rq:1,db:md_EQG,mul:1);
			md_1 = Decimator.ar(Pan2.ar(md_1,md_pan),md_brate,md_bcnt,1.0);
			md_2 = Decimator.ar(Pan2.ar(md_2,md_pan),md_brate,md_bcnt,1.0);
			// md_2 = SinOscFB.ar((md_carHz*1.5085)+ (md_carRamp*md_rampDepth),md_feedAmp) * md_carEnv * md_amp;
			sig = (DynKlank.ar(`
				[[md_modHz,md_modHz*1.5085, md_modHz*3.017, md_modHz*4.5255, md_modHz*5.27975,md_modHz*7.5425, md_modHz*9.051,md_modHz*10.5595,md_modHz*18.102]
					, [0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.1,0.05],
					[md_modRel, md_modRel, md_modRel, md_modRel,md_modRel,md_modRel,md_modRel,md_modRel,md_modRel]],
				Impulse.ar(0.003))*click) * md_modEnv;
			sig = LPF.ar(sig,2000);
			sig = (sig+(LPF.ar(Impulse.ar(0.003),16000,1)*md_snap)) * md_ampMod;
			sig = BPeakEQ.ar(in:sig,freq:md_EQF,rq:1,db:md_EQG,mul:1);
			slewLP = Lag2.kr(md_LPfreq,0.1);
			slewHP = Lag2.kr(md_HPfreq,0.1);
			sig = RLPF.ar(in:sig,freq:slewLP, rq: md_filterQ, mul:1);
			sig = RHPF.ar(in:sig,freq:slewHP, rq: md_filterQ, mul:1);
			sig = Decimator.ar(Pan2.ar(sig,md_pan),md_brate,md_bcnt,1.0);
			md_1 = (md_1*0.33)+(md_2*0.33)+(sig);
			Out.ar(out, md_1);
			FreeSelf.kr(Done.kr(md_carEnv) * Done.kr(md_modEnv));
		}).add;


		// hh's feedAmp can go up to 12, maybe 11? 10 is sweet on lower.
		// modAmp needs to go up to 100000 or 900??

		SynthDef("hh", {
			arg out, md_amp = 1,
			md_carHz = 100, md_carAtk = 0, md_carRel = 0.03,
			md_tremDepth = 1, md_tremHz = 1000,
			md_modAmp = 0, md_modHz = 110, md_modAtk = 0, md_modRel = 2,
			md_feedAmp = 10,
			md_AMD = 0, md_AMF = 303,
			md_EQF = 600, md_EQG = 0,
			md_brate = 24000, md_bcnt = 24,
			md_LPfreq = 19000, md_HPfreq = 20, md_filterQ = 0.3,
			md_pan = 0,
			kill_gate = 1;
			var md_car, md_mod, md_carEnv, md_modEnv, md_carRamp, tremolo, tremod,
			md_ampMod,
			slewLP, slewHP;
			md_modEnv = EnvGen.kr(Env.perc(md_modAtk, md_modRel));
			md_carRamp = EnvGen.kr(Env([1000, 0.000001], [md_tremHz], curve: \exp));
			md_carEnv = EnvGen.kr(Env.perc(md_carAtk, md_carRel), gate: kill_gate, doneAction:2);
			md_ampMod = SinOsc.ar(freq:md_AMF,mul:md_AMD,add:1);
			md_mod = SinOsc.ar(md_modHz, mul:md_modAmp) * md_modEnv;
			md_car = SinOscFB.ar(md_carHz + md_mod, md_feedAmp) * md_carEnv * md_amp;
			md_car = HPF.ar(md_car,1100,1);
			md_car = md_car*md_ampMod;
			tremolo = SinOsc.ar(md_tremHz, 0, md_tremDepth);
			tremod = (1.0 - md_tremDepth) + tremolo;
			md_car = md_car*tremod;
			md_car = BPeakEQ.ar(in:md_car,freq:md_EQF,rq:1,db:md_EQG*15,mul:1);
			slewLP = Lag2.kr(md_LPfreq,0.1);
			slewHP = Lag2.kr(md_HPfreq,0.1);
			md_car = RLPF.ar(in:md_car,freq:slewLP, rq: md_filterQ, mul:1);
			md_car = RHPF.ar(in:md_car,freq:slewHP, rq: md_filterQ, mul:1);
			md_car = Pan2.ar(md_car,md_pan);
			Out.ar(out, md_car);
		}).add;

		context.server.sync;
		synthArray = Array.fill(10,{Synth("bd",
			[ \out,0,
			\md_amp,0
			],target:context.xg)});
		context.server.sync;

		this.addCommand("hh","ifffffffffffffffffff", {
		arg msg;
			if (synthArray[msg[1]-1].isRunning,{
				// ("killing previous voice "++(synthArray[msg[1]-1].nodeID)).postln;
				synthArray[msg[1]-1].set(\kill_gate,-1.05);
            });
			synthArray[msg[1]-1]=Synth("hh",
			[
			\out,0,
			\md_amp,msg[2],
			\md_carHz,msg[3],
			\md_carAtk,msg[4],
			\md_carRel,msg[5],
			\md_tremDepth,msg[6],
			\md_tremHz,msg[7],
			\md_modAmp,msg[8],
			\md_modHz,msg[9],
			\md_modAtk,msg[10],
			\md_modRel,msg[11],
			\md_feedAmp,msg[12],
			\md_AMD,msg[13],
			\md_AMF,msg[14],
			\md_LPfreq,msg[15],
			\md_HPfreq,msg[16],
			\md_filterQ,msg[17],
			\md_pan,msg[18],
			\md_brate,msg[19],
			\md_bcnt,msg[20]
			]);
			NodeWatcher.register(synthArray[msg[1]-1]);
			/*synthArray[msg[1]-1].onFree({
				("freed: "++(synthArray[msg[1]-1].nodeID)).postln;
			});*/
		});

		this.addCommand("trig","isffffffffffffffffffff", {
		arg msg;
			if (synthArray[msg[1]-1].isRunning,{
				// ("killing previous voice "++(synthArray[msg[1]-1].nodeID)).postln;
				synthArray[msg[1]-1].set(\kill_gate,-1.05);
            });
		synthArray[msg[1]-1]=Synth(msg[2],
			[
			\out,0,
			\md_amp,msg[3],
			\md_carHz,msg[4],
			\md_carAtk,msg[5],
			\md_carRel,msg[6],
			\md_rampDepth,msg[7],
			\md_rampDec,msg[8],
			\md_modAmp,msg[9],
			\md_modHz,msg[10],
			\md_modAtk,msg[11],
			\md_modRel,msg[12],
			\md_feedAmp,msg[13],
			\md_click,msg[14],
			\md_AMD,msg[15],
			\md_AMF,msg[16],
			\md_LPfreq,msg[17],
			\md_HPfreq,msg[18],
			\md_filterQ,msg[19],
			\md_pan,msg[20],
			\md_brate,msg[21],
			\md_bcnt,msg[22]
			]);
			NodeWatcher.register(synthArray[msg[1]-1]);
			/*synthArray[msg[1]-1].onFree({
				("freed: "++(synthArray[msg[1]-1].nodeID)).postln;
			});*/
		});

		this.addCommand("rs","iffffffffffffffffffffffffffffffffffffffff", {
		arg msg;
			if (synthArray[msg[1]-1].isRunning,{
				// ("killing previous voice "++(synthArray[msg[1]-1].nodeID)).postln;
				synthArray[msg[1]-1].set(\kill_gate,-1.05);
            });
			synthArray[msg[1]-1]=Synth("rs",
			[
			\out,0,
			\md_amp,msg[2],
			\md_carHz,msg[3],
			\md_carAtk,msg[4],
			\md_carRel,msg[5],
			\md_rampDepth,msg[6],
			\md_rampDec,msg[7],
			\md_modAmp,msg[8],
			\md_modHz,msg[9],
			\md_modAtk,msg[10],
			\md_modRel,msg[11],
			\md_feedAmp,msg[12],
			\md_click,msg[13],
			\md_AMD,msg[14],
			\md_AMF,msg[15],
			\md_LPfreq,msg[16],
			\md_HPfreq,msg[17],
			\md_filterQ,msg[18],
			\md_pan,msg[19],
			\md_brate,msg[20],
			\md_bcnt,msg[21],
			\sd_amp,msg[22],
			\sd_carHz,msg[23],
			\sd_carAtk,msg[24],
			\sd_carRel,msg[25],
			\sd_rampDepth,msg[26],
			\sd_rampDec,msg[27],
			\sd_modAmp,msg[28],
			\sd_modHz,msg[29],
			\sd_modAtk,msg[30],
			\sd_modRel,msg[31],
			\sd_feedAmp,msg[32],
			\sd_click,msg[33],
			\sd_AMD,msg[34],
			\sd_AMF,msg[35],
			\sd_LPfreq,msg[36],
			\sd_HPfreq,msg[37],
			\sd_filterQ,msg[38],
			\sd_pan,msg[39],
			\sd_brate,msg[40],
			\sd_bcnt,msg[41],
			]);
			NodeWatcher.register(synthArray[msg[1]-1]);
			/*synthArray[msg[1]-1].onFree({
				("freed: "++(synthArray[msg[1]-1].nodeID)).postln;
			});*/
		});

	//BASS DRUM

	this.addCommand("LEV","isf",{
		arg msg;
		if (synthArray[msg[1]-1].isRunning,{
	      synthArray[msg[1]-1].set(\md_amp,msg[3]);
		});
	});

	this.addCommand("PTCH","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_carHz,msg[3]);
    	});
	});
	this.addCommand("ATK","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_carAtk,msg[3]);
    	});
	});
	this.addCommand("DEC","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_carRel,msg[3]);
    	});
	});
	this.addCommand("RAMP","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_rampDepth,msg[3]);
    	});
	});
	this.addCommand("RDEC","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_rampDec,msg[3]);
    	});
	});
	this.addCommand("TREM","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_tremDepth,msg[3]);
    	});
	});
	this.addCommand("TFRQ","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_tremHz,msg[3]);
    	});
	});
	this.addCommand("MOD","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_modAmp,msg[3]);
    	});
	});
	this.addCommand("MFRQ","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_modHz,msg[3]);
    	});
	});
	this.addCommand("MATK","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_modAtk,msg[3]);
    	});
	});
	this.addCommand("MDEC","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_modRel,msg[3]);
    	});
	});
	this.addCommand("MFB","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_feedAmp,msg[3]);
    	});
	});
	this.addCommand("PAN","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_pan,msg[3]);
    	});
	});
	this.addCommand("SRR","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_brate,msg[3]);
    	});
	});
	this.addCommand("BCR","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_bcnt,msg[3]);
    	});
	});
	this.addCommand("LPF","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_LPfreq,msg[3]);
    	});
	});
	this.addCommand("HPF","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\md_HPfreq,msg[3]);
    	});
	});
	this.addCommand("SNAR","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\sd_amp,msg[3]);
    	});
	});
	this.addCommand("SPTC","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\sd_carHz,msg[3]);
    	});
	});
	this.addCommand("SATK","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\sd_carAtk,msg[3]);
    	});
	});
	this.addCommand("SDEC","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\sd_carRel,msg[3]);
    	});
	});
	this.addCommand("SRMP","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\sd_rampDepth,msg[3]);
    	});
	});
	this.addCommand("SRDC","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\sd_rampDec,msg[3]);
    	});
	});
	this.addCommand("SMOD","isf",{
		arg msg;
    	if (synthArray[msg[1]-1].isRunning,{
    	  synthArray[msg[1]-1].set(\sd_modAmp,msg[3]);
    	});
	});
/*			\sd_modAmp,msg[28],
			\sd_modHz,msg[29],
			\sd_modAtk,msg[30],
			\sd_modRel,msg[31],
			\sd_feedAmp,msg[32],
			\sd_click,msg[33],
			\sd_AMD,msg[34],
			\sd_AMF,msg[35],
			\sd_LPfreq,msg[36],
			\sd_HPfreq,msg[37],
			\sd_filterQ,msg[38],
			\sd_pan,msg[39],
			\sd_brate,msg[40],
			\sd_bcnt,msg[41],*/


	}
	free {
		(0..9).do({arg i; synthArray[i].free});
	}
}