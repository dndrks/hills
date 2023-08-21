KildarePTR {

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
			\delaySend,0,
			\delayEnv,0,
			\delayAtk,0,
			\delayRel,2,
			\delayCurve,-4,
			\feedbackEnv,0,
			\feedbackAtk,0,
			\feedbackRel,2,
			\feedbackCurve,-4,
			\feedbackSend,0,
			\velocity,127,
			\amp,0.7,
			\carHz,55,
			\carHzThird,55,
			\carHzSeventh,55,
			\carDetune,0,
			\carAtk,0,
			\carRel,3.3,
			\carCurve,-4,
			\formantHz,55,
			\formantFollow,0,
			\formantNum,1,
			\formantDenum,1,
			\width,0.5,
			\phaseMul,0,
			\phaseAmp,0,
			\sync,0,
			\phaseAtk,0,
			\phaseRel,0.05,
			\phaseCurve,-4,
			\rampDepth,0,
			\rampDec,0.3,
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

		SynthDef(\kildare_ptr, {
			arg out = 0, t_gate = 0,
			delayAuxL, delayAuxR, delaySend,
			delayEnv, delayAtk, delayRel, delayCurve = -4,
			feedbackAux, feedbackSend,
			feedbackEnv, feedbackAtk, feedbackRel, feedbackCurve = -4,
			velocity = 127, amp,
			formantHz, formantFollow, formantNum = 1, formantDenum = 1,
			pulseHz, pulseFollow, pulseNum = 1, pulseDenum = 1,
			width, phaseMul, phaseAmp, sync,
			phaseAtk, phaseRel, phaseCurve = -4,
			carHz,
			carDetune, carAtk, carRel, carCurve = -4,
			pan, rampDepth, rampDec,
			squishPitch, squishChunk,
			amDepth, amHz,
			eqHz, eqAmp, bitRate, bitCount,
			lpHz, hpHz, filterQ,
			lpAtk, lpRel, lpCurve = -4, lpDepth;

			var car, carThird, carSeventh,
			mod, modHzThird, modHzSeventh,
			carEnv, modEnv, carRamp,
			ampMod,
			phaseEnv,filterEnv, delEnv, feedEnv, mainSend,
			phz, frmnt;

			eqHz = eqHz.lag3(0.1);
			lpHz = lpHz.lag3(0.1);
			hpHz = hpHz.lag3(0.1);
			delaySend = delaySend.lag3(0.1);
			feedbackSend = feedbackSend.lag3(0.1);

			filterQ = LinLin.kr(filterQ,0,100,1.0,0.001);
			eqAmp = LinLin.kr(eqAmp,-2.0,2.0,-10.0,10.0);
			rampDepth = LinLin.kr(rampDepth,0.0,1.0,0.0,2.0);
			amDepth = LinLin.kr(amDepth,0.0,1.0,0.0,2.0);

			formantNum = VarLag.kr(formantNum, warp:3);
			formantDenum = VarLag.kr(formantDenum, warp:3);
			width = VarLag.kr(width, warp:3);
			// formantDenum = formantDenum.lag3(0.1);
			// pulseNum = pulseNum.lag3(0.1);
			// pulseDenum = pulseDenum.lag3(0.1);

			carHz = carHz * (2.pow(carDetune/12));
			carHz = carHz.lag2(t1: (carAtk/2).clip(0.01,0.1));

			// pulseHz = ((pulseHz * (1 - pulseFollow)) + (carHz * (pulseFollow * (pulseNum / pulseDenum))));
			pulseHz = (carHz * (pulseNum / pulseDenum));
			phz = Pulse.ar(freq:pulseHz, mul: phaseMul);

			phaseEnv = EnvGen.ar(
				envelope: Env.new([0,0,1,0], times: [0.01,phaseAtk,phaseRel], curve: [0,phaseCurve*(-1),phaseCurve]),
				gate: t_gate
			);
			filterEnv = EnvGen.ar(
				envelope: Env.new([0,0,1,0], times: [0.01,lpAtk,lpRel], curve: [0, lpCurve*(-1), lpCurve]),
				gate: t_gate
			);
			carRamp = EnvGen.ar(
				Env([1000,1000, 0.000001], [0,rampDec], curve: \exp),
				gate: t_gate
			);
			carEnv = EnvGen.ar(
				envelope: Env.new([0,0,1,0], times: [0.01,carAtk,carRel], curve: [0, carCurve*(-1), carCurve]),
				gate: t_gate
			);

			car = FormantTriPTR.ar(
				freq: carHz + (carRamp*rampDepth),
				formant: carHz * (formantNum/formantDenum),
				width: width,
				phase: (phz * phaseAmp * phaseEnv),
				sync: (Pulse.ar(pulseHz, mul: sync)),
			) * carEnv;

			car = LeakDC.ar(car);

			ampMod = SinOsc.ar(freq:amHz,mul:(amDepth/2),add:1);
			car = car * ampMod;

			car = Squiz.ar(in:car, pitchratio:squishPitch, zcperchunk:squishChunk, mul:1);
			car = Decimator.ar(car,bitRate,bitCount,1.0);
			car = BPeakEQ.ar(in:car,freq:eqHz,rq:1,db:eqAmp,mul:1);
			car = RLPF.ar(in:car,freq:Clip.kr(lpHz + ((5*(lpHz * filterEnv)) * lpDepth), 20, 20000), rq: filterQ, mul:1);
			car = RHPF.ar(in:car,freq:hpHz, rq: filterQ, mul:1);
			car = Compander.ar(in:car, control:car, thresh:0.3, slopeBelow:1, slopeAbove:0.1, clampTime:0.01, relaxTime:0.01);

			mainSend = Pan2.ar(car,pan);
			mainSend = mainSend * (amp * LinLin.kr(velocity,0,127,0.0,1.0));

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

			Out.ar(out, mainSend);
			Out.ar(delayAuxL, (car * amp * LinLin.kr(velocity,0,127,0.0,1.0) * delEnv));
			Out.ar(delayAuxR, (car * amp * LinLin.kr(velocity,0,127,0.0,1.0) * delEnv));
			Out.ar(feedbackAux, (mainSend * (feedbackSend * feedEnv)));
		}).send;
	}
}