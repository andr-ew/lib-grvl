Grvl {
    const maxLoopTime = 60;

    var s;
    var <def;
    var <commandNames;
    var <synth;
    var <buffers;

    *new {
		^super.new.init;
	}

	init {
        //synthdef controls not to make into engine commands
        var notCommand = [\outBus, \loopBufA, \loopBufB];

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
                BufRateScale.kr(bufB) * \rate_b.kr(0.5),
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

            var readA = BufRd.ar(
                1, bufA, readWritePhaseA, loopA, \interp_a.kr(0)
            );
            var readB = BufRd.ar(
                1, bufB, readWritePhaseB, loopB, \interp_b.kr(0)
            );

            var a = inA;
            var b = inB;

            var writeA = a + (readA * \feedback_a.kr(0.5));
            var writeB = b + (readB * \feedback_b.kr(0.5));

            BufWr.ar(writeA, bufA, readWritePhaseA, loopA);
            BufWr.ar(writeB, bufB, readWritePhaseB, loopB);

            outA = Pan2.ar(readA, \out_pan_a.kr(-1));
            outB = Pan2.ar(readB, \out_pan_b.kr(1));

            Out.ar(\outBus.kr(0), outA + outB);
        }).add;

        //make list of commands from NamedControls
        commandNames = List.new();
        def.allControlNames.do({ arg c;
            if(notCommand.indexOf(c.name).isNil, {
                commandNames.add(c.name);
            });
        });

        s = Server.default;

        buffers = Array.fill(2, { Buffer.alloc(s, s.sampleRate * maxLoopTime) });

        s.sync;
        synth = Synth.new(\grvl, [\loopBufA, buffers[0].bufnum, \loopBufB, buffers[1].bufnum]);
        s.sync;

        //TODO: buffer re-assignment functions

        postln("🪨 layin' gravel 🪨");
	}

    free {
        synth.free;
        buffers.do({ arg b; b.free; });
    }
}
