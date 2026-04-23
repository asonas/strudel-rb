# @!parse extend Strudel::DSL
#
# !!!!!!!!!!!!THIS IS MONKEY PATCH!!!!!!!!!!!!1
::Strudel::Midi::Input.class_eval do
  unless method_defined?(:on_cc)
    alias_method :_original_record_cc, :record_cc

    def record_cc(cc_num, channel, raw_value)
      _original_record_cc(cc_num, channel, raw_value)
      (@listeners ||= {}).each do |(cc, ch), callback|
        next unless cc == cc_num
        next if ch && ch != channel
        callback.call(raw_value, channel)
      end
    end

    def on_cc(cc_num, channel: nil, &block)
      (@listeners ||= {})[[cc_num, channel]] = block
    end

    def accumulator_entry(cc_num, channel, initial)
      @accumulators ||= {}
      @accumulators[[cc_num, channel]] ||= { value: initial, mutex: Mutex.new }
    end
  end
end

def relative_cc(input, cc_num, step: 0.05, initial: 0.5, min: 0.0, max: 1.0, channel: nil)
  entry = input.accumulator_entry(cc_num, channel, initial)
  mutex = entry[:mutex]

  input.on_cc(cc_num, channel: channel) do |raw, _ch|
    mutex.synchronize do
      if raw == 127
        entry[:value] = [entry[:value] + step, max].min
      elsif raw == 1
        entry[:value] = [entry[:value] - step, min].max
      end
    end
  end

  ::Strudel::Pattern.ref { mutex.synchronize { entry[:value] } }
end
# !!! </THIS IS MONKEY PATCH> !!!!!!!!1


setcpm 135 / 4


c = midi_input "Ableton Ableton Move"
scale = "e:minor"

kick_gain  = relative_cc(c, 71, step: 0.01, initial: 0.5)
mel_gain  = relative_cc(c, 72, step: 0.01, initial: 0.5)
chor_gain  = relative_cc(c, 73, step: 0.01, initial: 0.5)

message = "hello! i am asonas"
_track(:asonas) { say(message) }
_track(:ivry) { say("ivry") }

track(:kick)  { sound("bd*4").gain(kick_gain) }
_track(:drum) {
  sound("hh*8, - sd - sd, [- oh]*4, - cp - cp").gain(kick_gain)
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

_track(:base) {
    note("<eb2 d2 d2 g2 f2 eb2 d2 d2 g2 c2>")
      .s("sawtooth").gain(0.5).lpf(400)
  }

_track(:melody) do
  n("7 <4 5> 6 <2 3>")
    .scale(scale)
    .s("triangle")
    .gain(mel_gain)
end

_track(:harm2) { note("<d3 f#3 a3 c4 eb4>*4").s("piano") }

_track(:chords) do
  n("<[0,2,4] [3,5,7] [4,6,8] [0,2,4]>")
    .scale(scale)
    .s("sine")
    .attack(0.05)
    .release(0.3)
    .gain(chor_gain)
end


_track(:say) { say(message).fit }

