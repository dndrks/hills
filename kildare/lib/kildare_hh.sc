KildareHH {

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
			\amp,0.7,
			\carHz,200,
			\carHzThird,200,
			\carHzSeventh,200,
			\carDetune,0,
			\carAtk,0,
			\carRel,0.03,
			\modAmp,1,
			\modHz,100,
			\modFollow,0,
			\modNum,1,
			\modDenum,1,
			\modAtk,0,
			\modRel,2,
			\feedAmp,1,
			\tremDepth,1,
			\tremHz,1000,
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
		SynthDef(\kildare_hh, {
			arg out = 0, t_gate = 0,
			delayAuxL, delayAuxR, delaySend,
			delayEnv, delayAtk, delayRel, delayCurve = -4,
			feedbackAux,feedbackSend,
			feedbackEnv, feedbackAtk, feedbackRel, feedbackCurve = -4,
			velocity = 127, amp,
			carHz, carHzThird, carHzSeventh,
			carDetune, carAtk, carRel, carCurve = -4,
			tremDepth, tremHz,
			modAmp, modHz, modAtk, modRel, modCurve = -4,
			modFollow, modNum, modDenum,
			feedAmp,
			amDepth, amHz,
			eqHz, eqAmp,
			bitRate, bitCount,
			lpHz, hpHz, filterQ,
			lpAtk, lpRel, lpCurve = -4, lpDepth,
			pan,
			squishPitch, squishChunk;

			var car,
			mod,
			feedScale,
			carEnv, modEnv, tremolo, tremod,
			ampMod, filterEnv, delEnv, feedEnv, mainSend;

			amp = amp*0.85;
			eqHz = eqHz.lag3(0.1);
			lpHz = lpHz.lag3(0.1);
			hpHz = hpHz.lag3(0.1);
			delaySend = delaySend.lag3(0.1);
			feedbackSend = feedbackSend.lag3(0.1);

			filterQ = LinLin.kr(filterQ,0,100,1.0,0.001);
			modAmp = LinLin.kr(modAmp,0.0,1.0,0,127);
			feedAmp = LinLin.kr(feedAmp,0.0,1.0,0.0,6.0);
			eqAmp = LinLin.kr(eqAmp,-2.0,2.0,-10.0,10.0);
			amDepth = LinLin.kr(amDepth,0,1.0,0.0,2.0);

			carHz = carHz * (2.pow(carDetune/12));
			carHz = carHz.lag2(t1: (carAtk/2).clip(0.01,0.1));

			modHz = Select.kr(modFollow > 0, [modHz, carHz * (modNum / modDenum)]);

			modEnv = EnvGen.ar(
				envelope: Env.new([0,0,1,0], times: [0.01,modAtk,modRel], curve: [0, modCurve*(-1), modCurve]),
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

			ampMod = SinOsc.ar(freq:amHz,mul:amDepth,add:1);

			mod = SinOsc.ar(modHz, mul:modAmp) * modEnv;

			car = SinOscFB.ar(carHz + mod, feedAmp) * carEnv * amp;

			feedScale = LinLin.kr(feedAmp,0,6,40,6600);
			car = HPF.ar(car,feedScale);
			car = car*ampMod;
			tremolo = SinOsc.ar(freq: tremHz, mul: tremDepth);
			tremod = (1.0 - tremDepth) + tremolo;
			car = car*tremod;
			car = Squiz.ar(in:car, pitchratio:squishPitch, zcperchunk:squishChunk, mul:1);
			car = Decimator.ar(car,bitRate,bitCount,1.0);
			car = BPeakEQ.ar(in:car,freq:eqHz,rq:1,db:eqAmp,mul:1);
			car = RLPF.ar(in:car,freq:Clip.kr(lpHz + ((5*(lpHz * filterEnv)) * lpDepth), 20, 20000), rq: filterQ, mul:1);
			car = RHPF.ar(in:car,freq:hpHz, rq: filterQ, mul:1);

			car = Compander.ar(in:car,control:car, thresh:0.3, slopeBelow:1, slopeAbove:0.1, clampTime:0.01, relaxTime:0.01);
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