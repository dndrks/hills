KildareCB {

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
			\delayAtk,0,
			\delayRel,2,
			\delayCurve,-4,
			\delaySend,0,
			\feedbackEnv,0,
			\feedbackAtk,0,
			\feedbackRel,2,
			\feedbackCurve,-4,
			\feedbackSend,0,
			\amp,0.7,
			\carHz,404,
			\carDetune,0,
			\carAtk,0,
			\carRel,0.15,
			\feedAmp,0,
			\snap,0,
			\rampDepth,0,
			\rampDec,4,
			\squishPitch,1,
			\squishChunk,1,
			\amDepth,0,
			\amHz,2698.8,
			\eqHz,12000,
			\eqAmp,0,
			\bitRate,24000,
			\bitCount,24,
			\lpHz,24000,
			\hpHz,20,
			\filterQ,50,
			\pan,0,
		]);
		^returnTable
	}

	init {
		SynthDef(\kildare_cb, {
			arg out = 0, t_gate = 0,
			delayAuxL, delayAuxR, delaySend,
			delayEnv, delayAtk, delayRel, delayCurve = -4,
			feedbackAux,feedbackSend,
			feedbackEnv, feedbackAtk, feedbackRel, feedbackCurve = -4,
			velocity = 127,
			amp, carHz, carDetune,
			modHz, modAmp, modAtk, modRel, modCurve = -4, feedAmp,
			modFollow, modNum, modDenum,
			carAtk, carRel, carCurve = -4,
			snap,
			pan, rampDepth, rampDec, amDepth, amHz,
			eqHz, eqAmp, bitRate, bitCount,
			lpHz, hpHz, filterQ,
			lpAtk, lpRel, lpCurve = -4, lpDepth,
			squishPitch, squishChunk;

			var car, mod, carEnv, carRamp, feedMod, feedCar, ampMod,
			voice_1, voice_2, filterEnv, delEnv, feedEnv, mainSend;

			amp = amp*0.6;
			eqHz = eqHz.lag3(0.1);
			lpHz = lpHz.lag3(0.1);
			hpHz = hpHz.lag3(0.1);
			delaySend = delaySend.lag3(0.1);
			feedbackSend = feedbackSend.lag3(0.1);

			carHz = carHz * (2.pow(carDetune/12));
			carHz = carHz.lag2(t1: (carAtk/2).clip(0.01,0.1));

			filterQ = LinLin.kr(filterQ,0,100,1.0,0.001);
			feedAmp = LinLin.kr(feedAmp,0.0,1.0,1.0,3.0);
			eqAmp = LinLin.kr(eqAmp,-2.0,2.0,-10.0,10.0);
			rampDepth = LinLin.kr(rampDepth,0.0,1.0,0.0,2.0);
			amDepth = LinLin.kr(amDepth,0,1.0,0.0,2.0);
			snap = LinLin.kr(snap,0.0,1.0,0.0,10.0);

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

			voice_1 = LFPulse.ar((carHz) + (carRamp*rampDepth)) * carEnv * amp;
			voice_2 = SinOscFB.ar((carHz*1.5085)+ (carRamp*rampDepth),feedAmp) * carEnv * amp;
			ampMod = SinOsc.ar(freq:amHz,mul:amDepth,add:1);
			voice_1 = (voice_1+(LPF.ar(Impulse.ar(0.003),16000,1)*snap)) * ampMod;
			voice_1 = (voice_1*0.33)+(voice_2*0.33);
			voice_1 = Squiz.ar(in:voice_1, pitchratio:squishPitch, zcperchunk:squishChunk, mul:1);
			voice_1 = Decimator.ar(voice_1,bitRate,bitCount,1.0);
			voice_1 = BPeakEQ.ar(in:voice_1,freq:eqHz,rq:1,db:eqAmp,mul:1);
			voice_1 = RLPF.ar(in:voice_1,freq:Clip.kr(lpHz + ((5*(lpHz * filterEnv)) * lpDepth), 20, 20000), rq: filterQ, mul:1);
			voice_1 = RHPF.ar(in:voice_1,freq:hpHz, rq: filterQ, mul:1);

			voice_1 = Compander.ar(in:voice_1,control:voice_1, thresh:0.3, slopeBelow:1, slopeAbove:0.1, clampTime:0.01, relaxTime:0.01);
			mainSend = Pan2.ar(voice_1,pan);
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
			Out.ar(delayAuxL, (voice_1 * amp * LinLin.kr(velocity,0,127,0.0,1.0) * delEnv));
			Out.ar(delayAuxR, (voice_1 * amp * LinLin.kr(velocity,0,127,0.0,1.0) * delEnv));
			Out.ar(feedbackAux, (mainSend * (feedbackSend * feedEnv)));

		}).send;
	}
}