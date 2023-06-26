Grvl {
    const maxLoopTime = 60;

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
        var notCommand = [\outBus, \loopBufA, \loopBufB];

        commands = Dictionary.new();

        //the synthdef
        def = SynthDef.new(\grvl, {
            var extIn = SoundIn.ar([0,1]);
            var buf = [\loopBufA.kr(0), \loopBufB.kr(0)];
            var read, write, outA, outB;

            var loop = [\loop_a.kr(1), \loop_b.kr(1)];

            var readWritePhase = Phasor.ar(
                0,
                BufRateScale.kr(buf) * [\rate_a.kr(1), \rate_b.kr(1)],
                BufFrames.kr(buf) * [\start_a_minutes.kr(0), \start_b_minutes.kr(0)],
                BufFrames.kr(buf) * [\end_a_minutes.kr(1/60), \end_b_minutes.kr(1/60)]
            );

            //TODO: read-only phasors, Select.kr to choose

            // var pm = LFTri.ar(MouseX.kr(0, 40000), 0, MouseY.kr(0, 50));
            //var pm = inB * MouseY.kr(0, 200);
            var pm = [0, 0];

            var in = [
                Mix.ar(
                    extIn * [\in_amp_left_a.kr(1), \in_amp_right_a.kr(0)]
                ),
                Mix.ar(
                    extIn * [\in_amp_left_b.kr(0), \in_amp_right_b.kr(1)]
                )
            ];

            read = BufRd.ar(
                1, buf, readWritePhase + pm,
                loop, [\interp_a.kr(0), \interp_b.kr(0)]
            );



            //TODO: ulaw bitcrusher
            //    - waveshape & round pre-write, toggle waveshaping
            //    - unwaveshape post-read, toggle unwaveshaping

            //smooth out some high freqs
            read = Slew.ar(
                read,
                [\smooth_a.kr(20000), \smooth_b.kr(20000)],
                [\smooth_a.kr(20000), \smooth_b.kr(20000)],
            );

            write = (in * [\rec_amp_a.kr(1), \rec_amp_b.kr(1)])
            + (read * [\feedback_amp_a.kr(0.5), \feedback_amp_b.kr(0.5)]);

            BufWr.ar(write[0], buf[0], readWritePhase[0] - 1, loop[0]);
            BufWr.ar(write[1], buf[1], readWritePhase[1] - 1, loop[1]);

            outA = Pan2.ar(read[0] * \out_amp_a.kr(1), \out_pan_a.kr(-1));
            outB = Pan2.ar(read[1] * \out_amp_b.kr(1), \out_pan_b.kr(1));

            Out.ar(\outBus.kr(0), outA + outB);
        }).add;


        //add the rest of NamedControls to commands w/ callback
        def.allControlNames.do({ arg c;
            var name = c.name;

            if(notCommand.indexOf(name).isNil, {
                commands.put(name, (
                    oscFunc: { arg msg;
                        msg.postln;

                        synth.set(name, msg[1])
                    },
                    format: \f,
                ));
            });
        });

        //add buffer assignment commands
        commands.put(\buf_a, (
            oscFunc: { arg msg;
                msg.postln;

                synth.set(\loopBufA, buffers[msg[1] - 1].bufnum)
            },
            format: \i
        ));
        commands.put(\buf_b, (
            oscFunc: { arg msg;
                msg.postln;

                synth.set(\loopBufB, buffers[msg[1] - 1].bufnum)
            },
            format: \i
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
        synth = Synth.new(\grvl, [\loopBufA, buffers[0].bufnum, \loopBufB, buffers[1].bufnum]);
        s.sync;

        postln("🪨 layin' gravel 🪨");
	}

    free {
        synth.free;
        buffers.do({ arg b; b.free; });
    }
}
