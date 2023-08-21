KildareCP {

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
			\carHz,1600,
			\carDetune,0,
			\carRel,0.43,
			\modAmp,1,
			\modHz,300,
			\modFollow,0,
			\modNum,1,
			\modDenum,1,
			\modRel,0.5,
			\feedAmp,1,
			\click,0,
			\squishPitch,1,
			\squishChunk,1,
			\amDepth,0,
			\amHz,2698.8,
			\eqHz,6000,
			\eqAmp,0,
			\bitRate,24000,
			\bitCount,24,
			\click,1,
			\lpHz,24000,
			\hpHz,20,
			\filterQ,50,
			\pan,0,
		]);
		^returnTable
	}

	init {
		SynthDef(\kildare_cp, {
			arg out = 0, t_gate = 0,
			delayAuxL, delayAuxR, delaySend,
			delayEnv, delayAtk, delayRel, delayCurve = -4,
			feedbackAux,feedbackSend,
			feedbackEnv, feedbackAtk, feedbackRel, feedbackCurve = -4,
			velocity = 0,
			carHz, carHzThird, carHzSeventh, carDetune,
			modHz, modAmp, modRel, feedAmp,
			modFollow, modNum, modDenum,
			carRel, amp, click,
			squishPitch, squishChunk,
			pan, amDepth, amHz,
			eqHz, eqAmp, bitRate, bitCount,
			lpHz, hpHz, filterQ,
			lpAtk, lpRel, lpCurve = -4, lpDepth;

			var car, carThird, carSeventh,
			mod, modHzThird, modHzSeventh,
			carEnv, modEnv, feedMod, feedCar, ampMod,
			mod_1, mod_1b, filterEnv, delEnv, feedEnv, mainSend;

			eqHz = eqHz.lag3(0.1);
			lpHz = lpHz.lag3(0.1);
			hpHz = hpHz.lag3(0.1);
			delaySend = delaySend.lag3(0.1);
			feedbackSend = feedbackSend.lag3(0.1);

			carHz = carHz * (2.pow(carDetune/12));
			carHz = carHz.lag2(t1:0.01);
			modHz = Select.kr(modFollow > 0, [modHz, carHz * (modNum / modDenum)]);

			filterQ = LinLin.kr(filterQ,0,100,1.0,0.001);
			modAmp = LinLin.kr(modAmp,0.0,1.0,0,127);
			feedAmp = LinLin.kr(feedAmp,0.0,1.0,0.0,10.0);
			eqAmp = LinLin.kr(eqAmp,-2.0,2.0,-10.0,10.0);
			amDepth = LinLin.kr(amDepth,0,1.0,0.0,2.0);

			modEnv = EnvGen.ar(
				Env.new(
					[0, 1, 0, 0.9, 0, 0.7, 0, 0.5, 0],
					[0.001, 0.009, 0, 0.008, 0, 0.01, 0, modRel],
					curve: \lin
				),gate: t_gate
			);
			filterEnv = EnvGen.ar(
				envelope: Env.new([0,0,1,0], times: [0.01,lpAtk,lpRel], curve: [0, lpCurve*(-1), lpCurve]),
				gate: t_gate
			);
			carEnv = EnvGen.ar(
				Env.new(
					[0, 1, 0, 0.9, 0, 0.7, 0, 0.5, 0],
					[0,0,0,0,0,0,0,carRel/4],
					[0, -3, 0, -3, 0, -3, 0, -3]
				),gate: t_gate
			);

			mod_1b = SinOscFB.ar(
				(modHz*4),
				feedAmp,
				0,
				modAmp*1
			)* modEnv;

			mod_1 = SinOscFB.ar(
				modHz+mod_1b,
				feedAmp,
				modAmp*100
			)* modEnv;

			car = SinOsc.ar(carHz + (mod_1)) * carEnv * amp;
			car = RHPF.ar(in:car+(LPF.ar(Impulse.ar(0.003),12000,1)*click),freq:hpHz,rq:filterQ,mul:1);

			ampMod = SinOsc.ar(freq:amHz,mul:amDepth,add:1);
			car = car * ampMod;
			car = Squiz.ar(in:car, pitchratio:squishPitch, zcperchunk:squishChunk, mul:1);
			car = Decimator.ar(car,bitRate,bitCount,1.0);
			car = BPeakEQ.ar(in:car,freq:eqHz,rq:1,db:eqAmp,mul:1);
			car = RLPF.ar(in:car,freq:Clip.kr(lpHz + ((5*(lpHz * filterEnv)) * lpDepth), 20, 20000), rq: filterQ, mul:1);
			car = RHPF.ar(in:car,freq:hpHz, rq: filterQ, mul:1);

			car = car.softclip;
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