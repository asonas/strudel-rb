setcpm 135 / 4

kick_gain  = relative_cc(c, 71, step: 0.01, initial: 0.5)
mel_gain  = relative_cc(c, 72, step: 0.01, initial: 0.5)
chor_gain  = relative_cc(c, 73, step: 0.01, initial: 0.5)

_track(:asonas) { say(message) }
_track(:ivry) { say("ivry") }

track(:kick)  { sound("bd*4").gain(kick_gain) }

chords = note("<
  [eb3,g3,bb3,d4,f4]
  [[d3,gb3,a3,c4,eb4] _ _ [d3,gb3,a3,c4,d4]]
  [g3,a3,bb3,d4,f4]
  [f3,a3,c4,d4,f4]
  [eb3,g3,bb3,d4,f4]
  [[d3,gb3,a3,c4,eb4] _ _ [d3,gb3,a3,c4,d4]]
  [g3,f4,a4,bb4,d5]
  [c3,e3,g3,bb3,d4]
>")

_track(:harm) {
  chords
    .s("sawtooth").gain(0.3).lpf(1200)
    .attack(0.02).release(0.3)
}

track(:ride) { sound("ride*4") }

_track(:harm) { note("<eb3 g3 bb3 d4 f4>*4").s("sine") }




_track(:harm) {
  note("<
    [eb3,g3,bb3,d4,f4]
    [d3,gb3,a3,c4,eb4]
    [d3,gb3,a3,c4,d4]
    [g3,a3,bb3,d4,f4]
    [f3,a3,c4,d4,f4]
    [eb3,g3,bb3,d4,f4]
    [d3,gb3,a3,c4,eb4]
    [d3,gb3,a3,c4,d4]
    [g3,f4,a4,bb4,d5]
    [c3,e3,g3,bb3,d4]
  >").s("sawtooth").gain(0.4).lpf(1200)
}


_track(:base) {
    note("<eb2 d2 d2 g2 f2 eb2 d2 d2 g2 c2>")
      .s("sawtooth").gain(0.5).lpf(400)
  }

_track(:chords) do
  n("<[0,2,4] [3,5,7] [4,6,8] [0,2,4]>")
    .scale(scale)
    .s("sine")
    .attack(0.05)
    .release(0.3)
    .gain(chor_gain)
end

