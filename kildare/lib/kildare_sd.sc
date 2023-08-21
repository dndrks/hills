KildareSD {

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
			\velocity,127,
			\amp,0.7,
			\carHz,282.54,
			\carHzThird,282.54,
			\carHzSeventh,282.54,
			\carDetune,0,
			\carAtk,0,
			\carRel,0.15,
			\carCurve,-4,
			\modAmp,0,
			\modHz,2770,
			\modFollow,0,
			\modNum,1,
			\modDenum,1,
			\modAtk,0.2,
			\modRel,1,
			\modCurve,-4,
			\feedAmp,0,
			\noiseAmp,0.01,
			\noiseAtk,0,
			\noiseRel,0.1,
			\noiseCurve,-4,
			\rampDepth,0.5,
			\rampDec,0.06,
			\squishPitch,1,
			\squishChunk,1,
			\amDepth,0,
			\amHz,2698.8,
			\eqHz,12000,
			\eqAmp,1,
			\bitRate,24000,
			\bitCount,24,
			\lpHz,20000,
			\hpHz,20,
			\filterQ,50,
			\lpAtk,0,
			\lpRel,0.3,
			\lpCurve,-4,
			\lpDepth,0,
			\pan,0,
		]);
		^returnTable
	}

	init {
		SynthDef(\kildare_sd, {
			arg out = 0, t_gate = 0,
			delayAuxL, delayAuxR, delaySend,
			delayEnv, delayAtk, delayRel, delayCurve = -4,
			feedbackAux,feedbackSend,
			feedbackEnv, feedbackAtk, feedbackRel, feedbackCurve = -4,
			velocity = 127,
			carHz, carHzThird, carHzSeventh,
			carDetune, carAtk, carRel, carCurve = -4,
			modHz, modAmp, modAtk, modRel, modCurve = -4, feedAmp,
			modFollow, modNum, modDenum,
			amp, pan,
			rampDepth, rampDec, noiseAmp,
			noiseAtk, noiseRel, noiseCurve = -4, bitRate, bitCount,
			eqHz,eqAmp,
			squishPitch, squishChunk,
			lpHz, hpHz, filterQ,
			lpAtk, lpRel, lpCurve = -4, lpDepth,
			amDepth, amHz;

			var car,
			mod,
			carEnv, modEnv, carRamp, feedMod, feedCar,
			noise, noiseEnv, mix, ampMod, filterEnv, delEnv, feedEnv, mainSendCar, mainSendNoise;

			amp = amp;
			noiseAmp = noiseAmp/2;
			eqHz = eqHz.lag3(0.1);
			lpHz = lpHz.lag3(0.1);
			hpHz = hpHz.lag3(0.1);
			delaySend = delaySend.lag3(0.1);
			feedbackSend = feedbackSend.lag3(0.1);

			carHz = (carHz * (1 - modFollow)) + (carHz * modFollow * modNum);
			carHz = carHz * (2.pow(carDetune/12));
			carHz = carHz.lag2(t1: (carAtk/2).clip(0.01,0.1));

			modHz = (modHz * (1 - modFollow)) + (carHz * modFollow * modDenum);

			filterQ = LinLin.kr(filterQ,0,100,1.0,0.001);
			modEnv = EnvGen.ar(
				envelope: Env.new([0,0,1,0], times: [0.01,modAtk,modRel], curve: [0, modCurve*(-1), modCurve]),
				gate: t_gate
			);
			filterEnv = EnvGen.ar(
				envelope: Env.new([0,0,1,0], times: [0.01,lpAtk,lpRel], curve: [0, lpCurve*(-1), lpCurve]),
				gate: t_gate
			);
			carRamp = EnvGen.ar(
				envelope: Env([0,1000, 0.000001], [0,rampDec], curve: \exp),
				gate: t_gate
			);
			carEnv = EnvGen.ar(
				envelope: Env.new([0,0,1,0], times: [0.01,carAtk,carRel], curve: [0, carCurve*(-1), carCurve]),
				gate: t_gate
			);
			modAmp = LinLin.kr(modAmp,0.0,1.0,0,127);
			feedMod = SinOsc.ar(modHz, mul:modAmp*100) * modEnv;
			feedAmp = LinLin.kr(feedAmp,0,1,0.0,10.0);
			eqAmp = LinLin.kr(eqAmp,-2.0,2.0,-10.0,10.0);
			feedAmp = feedAmp * modAmp;
			rampDepth = LinLin.kr(rampDepth,0.0,1.0,0.0,2.0);
			amDepth = LinLin.kr(amDepth,0.0,1.0,0.0,2.0);

			feedCar = SinOsc.ar(carHz + feedMod + (carRamp*rampDepth)) * carEnv * (feedAmp/modAmp * 127);
			mod = SinOsc.ar(modHz + feedCar, mul:modAmp*100) * modEnv;

			car = SinOsc.ar(carHz + mod + (carRamp*rampDepth)) * carEnv;

			noiseEnv = EnvGen.ar(
				envelope: Env.new([0,0,1,0], times: [0.01,noiseAtk,noiseRel], curve: [0,noiseCurve*(-1),noiseCurve]),
				gate: t_gate
			);
			// noise = BPF.ar(WhiteNoise.ar(0.24),8000,1.3) * (noiseAmp*noiseEnv);
			noise = HPF.ar(WhiteNoise.ar(0.24),8000,1.3) * (noiseAmp*noiseEnv);
			noise = BPeakEQ.ar(in:noise,freq:eqHz,rq:1,db:eqAmp,mul:1);
			noise = RLPF.ar(in:noise, freq:Clip.kr(lpHz + ((5*(lpHz * filterEnv)) * lpDepth), 20, 20000), rq: filterQ, mul:1);
			noise = RHPF.ar(in:noise,freq:hpHz, rq: filterQ, mul:1);

			ampMod = SinOsc.ar(freq:amHz,mul:(amDepth/2),add:1);
			car = car * ampMod;
			car = Squiz.ar(in:car, pitchratio:squishPitch, zcperchunk:squishChunk, mul:1);
			noise = Squiz.ar(in:noise, pitchratio:squishPitch, zcperchunk:squishChunk*100, mul:1);
			car = Decimator.ar(car,bitRate,bitCount,1.0);
			car = BPeakEQ.ar(in:car,freq:eqHz,rq:1,db:eqAmp,mul:1);
			car = RLPF.ar(in:car,freq:Clip.kr(lpHz + ((5*(lpHz * filterEnv)) * lpDepth), 20, 20000), rq: filterQ, mul:1);
			car = RHPF.ar(in:car,freq:hpHz, rq: filterQ, mul:1);

			car = Compander.ar(in:car, control:car, thresh:0.3, slopeBelow:1, slopeAbove:0.1, clampTime:0.01, relaxTime:0.01);
			mainSendCar = Pan2.ar(car,pan);
			mainSendCar = mainSendCar * amp * LinLin.kr(velocity,0,127,0.0,1.0);

			noise = Compander.ar(in:noise, control:noise, thresh:0.3, slopeBelow:1, slopeAbove:0.1, clampTime:0.01, relaxTime:0.01);
			mainSendNoise = Pan2.ar(noise,pan);
			mainSendNoise = mainSendNoise * amp * LinLin.kr(velocity,0,127,0.0,1.0);

			delEnv = Select.kr(
				delayEnv > 0, [
					delaySend,
					delaySend * EnvGen.ar(
						envelope: Env.new([0,0,1,0], times: [0.01,delayAtk,delayRel], curve: [0, delayCurve*(-1), delayCurve]),
						gate: t_gate
					)
				]
			);

			feedEnv = Select.kr(
				feedbackEnv > 0, [
					feedbackSend,
					feedbackSend * EnvGen.ar(
						envelope: Env.new([0,0,1,0], times: [0.01,feedbackAtk,feedbackRel], curve: [0, feedbackCurve*(-1), feedbackCurve]),
						gate: t_gate
					)
				]
			);

			Out.ar(out, mainSendCar);
			Out.ar(delayAuxL, (car * amp * LinLin.kr(velocity,0,127,0.0,1.0) * delEnv));
			Out.ar(delayAuxR, (car * amp * LinLin.kr(velocity,0,127,0.0,1.0) * delEnv));
			Out.ar(feedbackAux, (mainSendCar * (feedbackSend * feedEnv)));

			Out.ar(out, mainSendNoise);
			Out.ar(delayAuxL, (noise * amp * LinLin.kr(velocity,0,127,0.0,1.0) * delEnv));
			Out.ar(delayAuxR, (noise * amp * LinLin.kr(velocity,0,127,0.0,1.0) * delEnv));
			Out.ar(feedbackAux, (mainSendNoise * (feedbackSend * feedEnv)));

		}).send;
	}
}