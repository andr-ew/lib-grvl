Grvl {
    const maxLoopTime = 60;
    const chans = 2;

    var s;
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

        //the synthdef
        def = SynthDef.new(\grvl, {
            var extIn = SoundIn.ar([0,1]);

            var buf = \loopBuf.kr(0!chans);
            var bufFrames = BufFrames.kr(buf);

            var rate = \rate.kr(1!chans, \rate_slew.kr(0));

            var readWritePhase = Phasor.ar(
                0,
                BufRateScale.kr(buf) * rate,
                bufFrames * \start_minutes.kr(0!chans),
                bufFrames * \end_minutes.kr((1/60)!chans)
            );
            //TODO: read-only phasor, Select.kr to choose

            // var mod = LFTri.ar(MouseX.kr(0, 40000), 0, MouseY.kr(0, 50));
            //var mod = inB * MouseY.kr(0, 200);

            //TODO: mod sources: L, R, LFTri, LFSaw, LFPulse, GrayNoise
            var mod = 0!chans;

            var in_amp_left = \in_amp_left.kr([1, 0]);
            var in_amp_right = \in_amp_right.kr([0, 1]);
            var in = Mix.ar(
                extIn * [
                    [in_amp_left[0], in_amp_right[0]],
                    [in_amp_left[1], in_amp_right[1]]
                ]
            );

            var loop = \loop.kr(1!chans);


            //TODO: filter: bypass
            //TODO: lp/hp fm from mod depth
            var steps = 2.pow(\bit_depth.kr(8!chans));
            var mu = steps.sqrt;
            // var mu = 255;

            //TODO: shape & unshape bypass
            var comp = in;
            var comped = Compander.ar(comp, comp, //limiter/compression
                thresh: 1,
                slopeBelow: 1,
                slopeAbove: 0.5,
                clampTime:  0.01,
                relaxTime:  0.01
            );
            var shape = comped;
            var shaped = shape.sign * log(1 + (mu * shape.abs)) / log(1 + mu);
            var round = Select.ar(\shape_enable.kr(1!chans), [shape, shaped]);
            var rounded = (
                (round.abs * steps) + (
                    // 0
                    \bitnoise.kr(0.5!chans) * GrayNoise.ar(1!chans)
                    * (0.25 + CoinGate.ar(0.125, Dust.ar(0!chans)))
                )
            ).round * round.sign / steps;

            var write = rounded;

            //TODO: pm depth read
            var read = BufRd.ar(
                1, buf, readWritePhase + mod,
                loop, \interp.kr(0!chans)
            );

            var unshape = read;
            var unshaped = unshape.sign / mu * ((1+mu)**(unshape.abs) - 1);

            var filter = Select.ar(\unshape_enable.kr(1!chans), [unshape, unshaped]);
            var highpassed = SVF.ar(filter, \hp_freq.kr(100), \hp_rq.kr(0), 0, 0, 1);
            var lowpassed = SVF.ar(highpassed, \lp_freq.kr(6000), \lp_rq.kr(0), 1);

            //TODO: waveshaper drive (using the tf wavetable)

            var out = lowpassed;
            var feedback = lowpassed;

            var writeMixed = (
                (write * \rec_amp.kr(1!chans))
                + (feedback * \feedback_amp.kr(0.5!chans))
            );

            var out_amp = \out_amp.kr(1!chans);
            var out_pan = \out_pan.kr([-1, 1]);
            var outMixed = [
                Pan2.ar(out[0] * out_amp[0], out_pan[0]),
                Pan2.ar(out[1] * out_amp[1], out_pan[1])
            ];

            var offsetReadPhase = readWritePhase - (rate.sign * \head_offset.kr(2!chans));
            var writePhase = Select.ar(\rec_enable.kr(1!chans).asInteger, [
                DC.ar(bufFrames),
                offsetReadPhase
            ]);

            //TODO: pm depth read write
            BufWr.ar(writeMixed[0], buf[0], writePhase[0], loop[0]);
            BufWr.ar(writeMixed[1], buf[1], writePhase[1], loop[1]);

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

        s = Server.default;

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
