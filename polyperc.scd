//list yr audio interfaces
ServerOptions.devices;

//Languge > Recompile Class Library (Cmd+Shfit+L) to recompile class files

//get SC's IP & port (for receiving OSC)
NetAddr.localAddr;

//reboot w/ your audio interface
(
s.options.device = "TX-6"; //set ur interface here ;)
s.reboot;

// s.doWhenBooted({
//     fork {
//     }
// });
)

//def & listener function
(
SynthDef("PolyPerc", {
			arg out, freq = 880, pw=0.5, amp=0.5, cutoff=800, gain=1, release=0.9, pan=0;
			var snd = Pulse.ar(freq, pw);
			var filt = MoogFF.ar(snd,cutoff,gain);
			var env = Env.perc(level: amp, releaseTime: release).kr(2);
			Out.ar(out, Pan2.ar((filt*env), pan));
		}).add;

o = OSCFunc({ arg msg, time, addr, recvPort;
	Synth(\PolyPerc, [\freq, msg[1].midicps]);
}, '/n', n);
)