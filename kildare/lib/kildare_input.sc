KildareInput {

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
			\pitchRatio,1,
			\windowSize,0.2,
			\pitchDispersion,0,
			\timeDispersion,0,
			\carAtk,0,
			\carRel,10,
			\carCurve,-4,
			\ampMix,0,
			\modAtk,0,
			\modRel,10,
			\modCurve,-4,
			\squishPitch,1,
			\squishChunk,1,
			\amDepth,0,
			\amHz,8175.08,
			\eqHz,6000,
			\eqAmp,0,
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

		SynthDef(\kildare_input, {
			arg out = 0, t_gate = 0,
			delayAuxL, delayAuxR, delaySend,
			delayEnv, delayAtk, delayRel, delayCurve = -4,
			feedbackAux, feedbackSend,
			feedbackEnv, feedbackAtk, feedbackRel, feedbackCurve = -4,
			velocity = 127, amp,
			pitchRatio, windowSize, pitchDispersion, timeDispersion,
			carDetune, carAtk, carRel, carCurve = -4,
			modHz, ampMix, modAtk, modRel, modCurve = -4, feedAmp,
			modFollow, modNum, modDenum,
			pan, rampDepth, rampDec,
			squishPitch, squishChunk,
			amDepth, amHz,
			eqHz, eqAmp, bitRate, bitCount,
			lpHz, hpHz, filterQ,
			lpAtk, lpRel, lpCurve = -4, lpDepth;

			var input, car, carThird, carSeventh,
			mod,
			carEnv, modEnv, carRamp,
			feedMod, feedCar, ampMod, click, clicksound,
			filterEnv, delEnv, feedEnv, mainSend;

			eqHz = eqHz.lag3(0.1);
			lpHz = lpHz.lag3(0.1);
			hpHz = hpHz.lag3(0.1);
			delaySend = delaySend.lag3(0.1);
			feedbackSend = feedbackSend.lag3(0.1);
			// modHz = (modHz * (1 - modFollow)) + (carHz * modFollow * modDenum);

			filterQ = LinLin.kr(filterQ,0,100,1.0,0.001);
			feedAmp = LinLin.kr(feedAmp,0.0,1.0,0.0,10.0);
			eqAmp = LinLin.kr(eqAmp,-2.0,2.0,-10.0,10.0);
			rampDepth = LinLin.kr(rampDepth,0.0,1.0,0.0,2.0);
			amDepth = LinLin.kr(amDepth,0.0,1.0,0.0,2.0);
			timeDispersion = Clip.kr(timeDispersion,0,windowSize);
			amp = amp*10;

			modEnv = EnvGen.kr(
				envelope: Env.new([0,0,1,0], times: [0,modAtk,modRel], curve: [0, modCurve*(-1), modCurve]),
				gate: t_gate
			);
			filterEnv = EnvGen.kr(
				envelope: Env.new([0,0,1,0], times: [0.01,lpAtk,lpRel], curve: [0, lpCurve*(-1), lpCurve]),
				gate: t_gate
			);
			carRamp = EnvGen.kr(
				Env([4,4,0], [0,rampDec], curve: \exp),
				gate: t_gate
			);
			carEnv = EnvGen.kr(
				envelope: Env.new([0,0,1,0], times: [0,carAtk,carRel], curve: [0, carCurve*(-1), carCurve]),
				gate: t_gate
			);

			input = SoundIn.ar([0,1]);
			mod = (input*modEnv)*10;
			car = PitchShift.ar(
				input,
				windowSize: windowSize,
				pitchRatio: pitchRatio + (carRamp*rampDepth),
				pitchDispersion: pitchDispersion,
				timeDispersion: timeDispersion
			);
			car = car*carEnv;
			car = SelectX.ar(ampMix,[car, (car*mod*10)]);

			ampMod = SinOsc.ar(freq:amHz,mul:(amDepth/2),add:1);
			car = car * ampMod;

			car = Squiz.ar(in:car, pitchratio:squishPitch, zcperchunk:squishChunk, mul:1);
			car = Decimator.ar(car,bitRate,bitCount);
			car = BPeakEQ.ar(in:car,freq:eqHz,rq:1,db:eqAmp);
			car = RLPF.ar(in:car,freq:Clip.kr(lpHz + ((5*(lpHz * filterEnv)) * lpDepth), 20, 20000), rq: filterQ);
			car = RHPF.ar(in:car,freq:hpHz, rq: filterQ);
			car = Compander.ar(in:car, control:car, thresh:0.3, slopeBelow:1, slopeAbove:0.1, clampTime:0.01, relaxTime:0.01);

			mainSend = Balance2.ar(car[0],car[1],pan);
			mainSend = mainSend * amp * LinLin.kr(velocity,0,127,0.0,1.0);

			delEnv = Select.kr(
				delayEnv > 0, [
					delaySend,
					delaySend * EnvGen.kr(
						envelope: Env.new([0,0,1,0], times: [0,delayAtk,delayRel], curve: [0, delayCurve*(-1), delayCurve]),
						gate: t_gate
					)
				]
			);

			feedEnv = Select.kr(
				feedbackEnv > 0, [
					feedbackSend,
					feedbackSend * EnvGen.kr(
						envelope: Env.new([0,0,1,0], times: [0,feedbackAtk,feedbackRel], curve: [0, feedbackCurve*(-1), feedbackCurve]),
						gate: t_gate
					)
				]
			);

			Out.ar(out, mainSend);
			Out.ar(delayAuxL, (car * amp * LinLin.kr(velocity,0,127,0.0,1.0) * delEnv));
			Out.ar(delayAuxR, (car * amp * LinLin.kr(velocity,0,127,0.0,1.0) * delEnv));
			Out.ar(feedbackAux, (mainSend * (feedbackSend * feedEnv)));
		}).send;
	}
}