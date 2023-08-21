KildareRS {

	*new {
		arg srv;
		^super.new.init(srv);
	}

	*buildParams {
		arg mainOutBus, delayLSendBus, delayRSendBus, feedbackSendBus;
		var returnTable;
		returnTable = Dictionary.newFrom([
			\out,mainOutBus,
			\delayAuxL,delayLSendBus,
			\delayAuxR,delayRSendBus,
			\feedbackAux,feedbackSendBus,
			\delayEnv,0,
			\delayAtk,0,
			\delayRel,2,
			\delayCurve,-4,
			\delaySend,0,
			\feedbackEnv,0,
			\feedbackAtk,0,
			\feedbackRel,2,
			\feedbackCurve,-4,
			\feedbackSend,0,
			\amp,1.0,
			\carHz,370,
			\carDetune,0,
			\carAtk,0,
			\carRel,0.05,
			\modAmp,1,
			\modHz,4000,
			\modFollow,0,
			\modNum,1,
			\modDenum,1,
			\sdAmp,1,
			\sdAtk,0,
			\sdRel,0.05,
			\rampDepth,0,
			\rampDec,0.06,
			\squishPitch,1,
			\squishChunk,1,
			\amDepth,0,
			\amHz,8175.08,
			\eqHz,6000,
			\eqAmp,0,
			\bitRate,24000,
			\bitCount,24,
			\lpHz,19000,
			\hpHz,20,
			\filterQ,50,
			\pan,0,
		]);
		^returnTable
	}

	init {
		SynthDef(\kildare_rs, {
			arg out = 0, t_gate = 0,
			delayAuxL, delayAuxR, delaySend,
			delayEnv, delayAtk, delayRel, delayCurve = -4,
			feedbackAux,feedbackSend,
			feedbackEnv, feedbackAtk, feedbackRel, feedbackCurve = -4,
			velocity = 0,
			carHz, carDetune,
			modHz, modAmp,
			modFollow, modNum, modDenum,
			carAtk, carRel, carCurve = -4, amp,
			pan, rampDepth, rampDec, amDepth, amHz,
			eqHz, eqAmp, bitRate, bitCount,
			sdAmp, sdRel, sdAtk, sdCurve = -4,
			lpHz, hpHz, filterQ,
			lpAtk, lpRel, lpCurve = -4, lpDepth,
			squishPitch, squishChunk;

			var car, mod, carEnv, modEnv, carRamp, feedMod, feedCar, ampMod,
			mod_1,mod_2,feedAmp3,feedAmp4, sd_modHz,
			sd_car, sd_mod, sd_carEnv, sd_modEnv, sd_carRamp, sd_feedMod, sd_feedCar, sd_noise, sd_noiseEnv,
			sd_mix, filterEnv, delEnv, feedEnv, mainSendMix, delaySendMix;

			amp = amp*0.45;
			eqHz = eqHz.lag3(0.1);
			lpHz = lpHz.lag3(0.1);
			hpHz = hpHz.lag3(0.1);
			delaySend = delaySend.lag3(0.1);
			feedbackSend = feedbackSend.lag3(0.1);

			carHz = carHz * (2.pow(carDetune/12));
			carHz = carHz.lag2(t1: (carAtk/2).clip(0.01,0.1));
			modHz = Select.kr(modFollow > 0, [modHz, carHz * (modNum / modDenum)]);

			filterQ = LinLin.kr(filterQ,0,100,1.0,0.001);
			modAmp = LinLin.kr(modAmp,0.0,1.0,0,127);
			eqAmp = LinLin.kr(eqAmp,-2.0,2.0,-10.0,10.0);
			rampDepth = LinLin.kr(rampDepth,0.0,1.0,0.0,2.0);
			amDepth = LinLin.kr(amDepth,0,1.0,0.0,2.0);

			feedAmp3 = modAmp.linlin(0, 127, 0, 3);
			feedAmp4 = modAmp.linlin(0, 127, 0, 4);

			carRamp = EnvGen.ar(
				Env([600,600, 0.000001], [0,rampDec], curve: \lin),
				gate: t_gate
			);
			carEnv = EnvGen.ar(
				envelope: Env.new([0,0,1,0], times: [0.01,carAtk,carRel], curve: [0, carCurve*(-1), carCurve]),
				gate: t_gate
			);
			filterEnv = EnvGen.ar(
				envelope: Env.new([0,0,1,0], times: [0.01,lpAtk,lpRel], curve: [0, lpCurve*(-1), lpCurve]),
				gate: t_gate
			);

			mod_2 = SinOscFB.ar(
				modHz*16,
				feedAmp3,
				modAmp*10
			)* 1;

			mod_1 = SinOscFB.ar(
				modHz+mod_2,
				feedAmp3,
				modAmp*10
			)* 1;

			car = SinOscFB.ar(carHz + (mod_1+mod_2) + (carRamp*rampDepth),feedAmp4) * carEnv * amp;

			ampMod = SinOsc.ar(freq:amHz,mul:amDepth,add:1);

			car = (car+(LPF.ar(Impulse.ar(0.003),16000,1)*amp)) * ampMod;
			car = LPF.ar(car,12000,1);
			car = car.softclip;

			sd_modHz = carHz*2.52;
			sd_modEnv = EnvGen.ar(
				envelope: Env.new([0,0,1,0], times: [0,carAtk,carRel], curve: [0,carCurve*(-1),carCurve]),
				gate: t_gate
			);
			sd_carRamp = EnvGen.ar(
				Env([1000,1000, 0.000001], [0,rampDec], curve: \exp),
				gate: t_gate
			);
			sd_carEnv = EnvGen.ar(
				envelope: Env.new([0,0,1,0], times: [0.01,sdAtk,sdRel], curve: [sdCurve,sdCurve*(-1)]),
				gate: t_gate
			);
			sd_feedMod = SinOsc.ar(modHz, mul:modAmp*100) * sd_modEnv;
			sd_feedCar = SinOsc.ar(carHz + sd_feedMod + (carRamp*rampDepth)) * sd_carEnv * (feedAmp3*10);
			sd_mod = SinOsc.ar(modHz + sd_feedCar, mul:modAmp) * sd_modEnv;
			sd_car = SinOsc.ar(carHz + sd_mod + (carRamp*rampDepth)) * sd_carEnv * sdAmp;
			sd_mix = sd_car * ampMod;
			sd_mix = sd_mix.softclip;

			delEnv = Select.kr(
				delayEnv > 0, [
					delaySend,
					delaySend * EnvGen.ar(
						envelope: Env.new([0,0,1,0], times: [0.01,delayAtk,delayRel], curve: [0, delayCurve*(-1), delayCurve]),
						gate: t_gate
					)
				]
			);

			mainSendMix = (car + sd_mix);
			mainSendMix = Squiz.ar(in:mainSendMix, pitchratio:squishPitch, zcperchunk:squishChunk, mul:1);
			mainSendMix = Decimator.ar(mainSendMix,bitRate,bitCount,1.0);
			mainSendMix = BPeakEQ.ar(in:mainSendMix,freq:eqHz,rq:1,db:eqAmp,mul:1);
			mainSendMix = RLPF.ar(in:mainSendMix,freq:Clip.kr(lpHz + ((5*(lpHz * filterEnv)) * lpDepth), 20, 20000), rq: filterQ, mul:1);
			mainSendMix = RHPF.ar(in:mainSendMix,freq:hpHz, rq: filterQ, mul:1);
			mainSendMix = Compander.ar(in:mainSendMix,control:mainSendMix, thresh:0.3, slopeBelow:1, slopeAbove:0.1, clampTime:0.01, relaxTime:0.01);
			delaySendMix = mainSendMix;
			mainSendMix = Pan2.ar(mainSendMix,pan);
			mainSendMix = mainSendMix * amp * LinLin.kr(velocity,0,127,0.0,1.0);

			feedEnv = Select.kr(
				feedbackEnv > 0, [
					feedbackSend,
					feedbackSend * EnvGen.ar(
						envelope: Env.new([0,0,1,0], times: [0.01,feedbackAtk,feedbackRel], curve: [0, feedbackCurve*(-1), feedbackCurve]),
						gate: t_gate
					)
				]
			);

			Out.ar(out, mainSendMix);
			Out.ar(delayAuxL, (delaySendMix * amp * LinLin.kr(velocity,0,127,0.0,1.0) * delEnv));
			Out.ar(delayAuxR, (delaySendMix * amp * LinLin.kr(velocity,0,127,0.0,1.0) * delEnv));
			Out.ar(feedbackAux, (mainSendMix * (feedbackSend * feedEnv)));

		}).send;
	}
}