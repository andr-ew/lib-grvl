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
            var bufA = \loopBufA.kr(0);
            var bufB = \loopBufB.kr(0);
            var outA, outB;

            var readWritePhaseA = Phasor.ar(
                0,
                BufRateScale.kr(bufA) * \rate_a.kr(1),
                BufFrames.kr(bufA) * \start_a_minutes.kr(0),
                BufFrames.kr(bufA) * \end_a_minutes.kr(1/60)
            );
            var readWritePhaseB = Phasor.ar(
                0,
                BufRateScale.kr(bufB) * \rate_b.kr(1),
                BufFrames.kr(bufB) * \start_b_minutes.kr(0),
                BufFrames.kr(bufB) * \end_b_minutes.kr(1/60)
            );

            var inA = Mix.ar(
                extIn * [\amp_in_left_a.kr(1), \amp_in_right_a.kr(0)]
            );
            var inB = Mix.ar(
                extIn * [\amp_in_left_b.kr(0), \amp_in_right_b.kr(1)]
            );

            //TODO: read-only phasors, Select.kr to choose

            var loopA = \loop_a.kr(1);
            var loopB = \loop_b.kr(1);

            // var pm = LFTri.ar(MouseX.kr(0, 40000), 0, MouseY.kr(0, 50));
            //var pm = inB * MouseY.kr(0, 200);
            var pm = 0;

            var readA = BufRd.ar(
                1, bufA, readWritePhaseA + pm,
                loopA, \interp_a.kr(0)
            );
            var readB = BufRd.ar(
                1, bufB, readWritePhaseB + pm,
                loopB, \interp_b.kr(0)
            );

            var a = inA;
            var b = inB;

            //TODO: ulaw bitcrusher
            //    - waveshape & round pre-write, toggle waveshaping
            //    - unwaveshape post-read, toggle unwaveshaping

            var writeA = a + (readA * \feedback_a.kr(0.5));
            var writeB = b + (readB * \feedback_b.kr(0.5));

            BufWr.ar(writeA, bufA, readWritePhaseA, loopA);
            BufWr.ar(writeB, bufB,
                readWritePhaseB,
                loopB
            );

            outA = Pan2.ar(readA * \out_amp_a.kr(1), \out_pan_a.kr(-1));
            outB = Pan2.ar(readB * \out_amp_b.kr(1), \out_pan_b.kr(1));

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
        commands.put(\clear_buf, (
            oscFunc: { arg msg;
                msg.postln;

                buffers[msg[1] - 1].zero;
            },
            format: \i
        ));

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
