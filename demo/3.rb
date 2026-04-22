setcpm 120/4

track(:drums) {
  sound("bd*4, hh*8, - sd - sd, [- oh]*4, - cp - cp").gain(0.3)
}

track(:harmony) { note("<[c4,e4,g4] [a3,c4,e4] [f3,a3,c4] [g3,b3,d4]>").s("sine").gain(0.5) }

track(:arpeggio) { note("<c4 e4 g4 b4>*8").s("sawtooth").gain(0.3) }
