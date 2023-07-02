Grvl {
    const maxLoopTime = 60;
    const chans = 2;

    var s;
    var <tf;
    var <tfBuf;
    var <def;
    var <commands;
    var <synth;
    var <buffers;

    *new {
		^super.new.init;
	}

	init {
        //NamedControls not to auto-make into commands
        var notCommand = [\outBus, \loopBuf];

        commands = Dictionary.new();

        s = Server.default;

        //analog waveshaper table by @ganders
        tf = (Env([-0.7, 0, 0.7], [1,1], [8,-8]).asSignal(1025) + (
            Signal.sineFill(
                1025,
                (0!3) ++ [0,0,1,1,0,1].scramble,
                    {rrand(0,2pi)}!9
                )/10;
        )).normalize;
        tfBuf = Buffer.loadCollection(s, tf.asWavetableNoWrap);

        s.sync;

        //the synthdef
        def = SynthDef.new(\grvl, {
            var extIn = SoundIn.ar([0,1]);

            var mod_freq = \mod_freq.kr(10000!chans);
            var sin = SinOsc.ar(mod_freq);
            var tri = LFTri.ar(mod_freq);
            var saw = LFSaw.ar(mod_freq);
            var pulse = LFPulse.ar(mod_freq);
            var noise = GrayNoise.ar();

            var mod = Select.ar(\mod_source.kr(3!chans).asInteger - 1, [
                extIn[1], sin, tri, saw, pulse, noise
            ]) * \mod_depth.kr(1!chans);

            var in = Select.ar(\adc_channel.kr(0!chans).asInteger, [extIn[0], extIn[1]]);

            var buf = \loopBuf.kr(0!chans);
            var bufFrames = BufFrames.kr(buf);
            var rate_slew = \rate_slew.kr(0);
            var rate_write = \rate_write.kr(1!chans, rate_slew);

            var readWritePhase = Phasor.ar(
                0,
                BufRateScale.kr(buf) * rate_write,
                bufFrames * \start_minutes_write.kr(0!chans),
                bufFrames * \end_minutes_write.kr((1/60)!chans)
            );
            var readOnlyPhase = Phasor.ar(
                0,
                BufRateScale.kr(buf) * \rate_read.kr(1!chans, rate_slew),
                bufFrames * \start_minutes_read.kr(0!chans),
                bufFrames * \end_minutes_read.kr((1/60)!chans)
            );

            //TODO: pm depth read
            var readPhase = Select.ar(\couple_phases.kr(1!chans).asInteger, [
                readOnlyPhase,
                readWritePhase,
            ]);
            var read = BufRd.ar(
                1, buf, readPhase + (mod * \mod_read_phase.kr(1!chans)),
                1, \interp.kr(0!chans)
            );

            var comp = read;
            var comped = Compander.ar(comp, comp, //limiter/compression
                thresh: 1,
                slopeBelow: 1,
                slopeAbove: 0.5,
                clampTime:  0.01,
                relaxTime:  0.01
            );

            var steps = 2.pow(\bit_depth.kr(8!chans));
            var mu = steps.sqrt;
            var shape = comped;
            var shaped = shape.sign * log(1 + (mu * shape.abs)) / log(1 + mu);
            var round = shaped;
            var rounded = (
                (round.abs * steps) + (
                    // 0
                    \bitnoise.kr(0.5!chans) * GrayNoise.ar(1!chans)
                    * (0.25 + CoinGate.ar(0.125, Dust.ar(0!chans)))
                )
            ).round * round.sign / steps;
            var unshape = rounded;
            var unshaped = unshape.sign / mu * ((1+mu)**(unshape.abs) - 1);

            //TODO: lp/hp fm from mod depth
            var filter = unshaped;
            var highpassed = RHPF.ar(filter, \hp_freq.kr(100), \hp_rq.kr(1));
            var lowpassed = MoogLadder.ar(
                highpassed,
                \lp_freq.kr(6000) + (mod * \mod_filter_freq.kr(0!chans)),
                \lp_q.kr(0)
            );

            //TODO: filter: bypass
            var drive = lowpassed;
            var driven = XFade2.ar(drive,
                Shaper.ar(tfBuf, drive), (\drive.kr(0.025)*2) - 1
            );

            var out = driven;
            var write = driven;

            var out_amp = \out_amp.kr(1!chans);
            var out_pan = \out_pan.kr([-1, 1]);
            var outMixed = [
                Pan2.ar(out[0] * out_amp[0], out_pan[0]),
                Pan2.ar(out[1] * out_amp[1], out_pan[1])
            ];

            var writeMixed = (in * \rec_amp.kr(1!chans)) + (write * \feedback_amp.kr(0.5!chans));
            var offsetReadPhase = readWritePhase - (rate_write.sign * \head_offset.kr(2!chans));
            var writePhase = Select.ar(\rec_enable.kr(1!chans).asInteger, [
                DC.ar(bufFrames),
                offsetReadPhase  + (mod * \mod_write_phase.kr(0!chans))
            ]);

            //TODO: pm depth read write
            BufWr.ar(writeMixed[0], buf[0], writePhase[0]);
            BufWr.ar(writeMixed[1], buf[1], writePhase[1]);

            Out.ar(\outBus.kr(0), outMixed[0] + outMixed[1]);
        }).add;


        //add the rest of NamedControls to commands w/ callback
        def.allControlNames.do({ arg c;
            var name = c.name;

            if(notCommand.indexOf(name).isNil, {
                commands.put(name, (
                    oscFunc: { arg msg;
                        msg.postln;

                        synth.seti(name, msg[1] - 1, msg[2])
                    },
                    format: \if,
                ));
            });
        });

        //add buffer assignment commands
        commands.put(\buf, (
            oscFunc: { arg msg;
                msg.postln;

                synth.seti(\loopBuf, msg[1] - 1, buffers[msg[2] - 1].bufnum)
            },
            format: \ii
        ));

        //add buffer clearing command
        commands.put(\clear_buf, (
            oscFunc: { arg msg;
                msg.postln;

                buffers[msg[1] - 1].zero;
            },
            format: \i
        ));

        //TODO: buffer read & write

        //TODO: polls dict, add phase polls based phases sent out of dedicated busses

        buffers = Array.fill(2, { Buffer.alloc(s, s.sampleRate * maxLoopTime) });

        s.sync;
        synth = Synth.new(\grvl, [\loopBuf, [buffers[0].bufnum, buffers[1].bufnum]]);
        s.sync;

        postln("🪨 layin' gravel 🪨");
	}

    free {
        synth.free;
        buffers.do({ arg b; b.free; });
    }
}
