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
            var read, write, out;

            var loop = \loop.kr(1!chans);
            var out_amp = \out_amp.kr(1!chans);
            var out_pan = \out_pan.kr([-1, 1]);
            var rate = \rate.kr(1!chans);
            var bufFrames = BufFrames.kr(buf);

            var readWritePhase = Phasor.ar(
                0,
                BufRateScale.kr(buf) * rate,
                bufFrames * \start_minutes.kr(0!chans),
                bufFrames * \end_minutes.kr((1/60)!chans)
            );

            //TODO: read-only phasors, Select.kr to choose

            // var pm = LFTri.ar(MouseX.kr(0, 40000), 0, MouseY.kr(0, 50));
            //var pm = inB * MouseY.kr(0, 200);
            var pm = 0!chans;

            var in_amp_left = \in_amp_left.kr([1, 0]);
            var in_amp_right = \in_amp_right.kr([0, 1]);

            var in = Mix.ar(
                extIn * [
                    [in_amp_left[0], in_amp_right[0]],
                    [in_amp_left[1], in_amp_right[1]]
                ]
            );

            read = BufRd.ar(
                1, buf, readWritePhase + pm,
                loop, \interp.kr(0!chans)
            );

            //TODO: ulaw bitcrusher
            //    - waveshape & round pre-write, toggle waveshaping
            //    - unwaveshape post-read, toggle unwaveshaping

            //smooth out some high freqs
            read = Slew.ar(
                read,
                \smooth.kr(20000!chans),
                \smooth.kr(20000!chans)
            );

            write = (in * \rec_amp.kr(1!chans)) + (read * \feedback_amp.kr(0.5!chans));

            BufWr.ar(write[0], buf[0], readWritePhase[0] - (rate[0].sign * 2), loop[0]);
            BufWr.ar(write[1], buf[1], readWritePhase[1] - (rate[1].sign * 2), loop[1]);

            out = [
                Pan2.ar(read[0] * out_amp[0], out_pan[0]),
                Pan2.ar(read[1] * out_amp[1], out_pan[1])
            ];

            Out.ar(\outBus.kr(0), out[0] + out[1]);
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
