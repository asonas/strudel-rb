# frozen_string_literal: true

module Strudel
  # Global tempo state (cycles per second).
  #
  # Strudel/Tidal expresses tempo as CPS (cycles per second). 1 cycle is a unit
  # used for patterns; perceived BPM depends on how many "beats" you interpret
  # per cycle (bpc).
  #
  # See: https://tidalcycles.org/docs/reference/tempo/#setcps
  DEFAULT_CPS = 0.5

  @cps = DEFAULT_CPS

  class << self
    def cps
      @cps
    end

    def cps=(value)
      @cps = value.to_f
    end

    def setcps(value)
      self.cps = value
    end

    # Cycles per minute. Same as setcps(cpm / 60.0)
    def setcpm(value)
      setcps(value.to_f / 60.0)
    end

    def cpm
      cps.to_f * 60.0
    end

    # Helper to reason about perceived tempo.
    #
    # bpm = cps * 60 * bpc
    def bpm(bpc: 4)
      cps.to_f * 60.0 * bpc.to_f
    end

    def cps_for_bpm(bpm, bpc: 4)
      bpm.to_f / (60.0 * bpc.to_f)
    end

    def setbpm(bpm, bpc: 4)
      setcps(cps_for_bpm(bpm, bpc: bpc))
    end
  end
end
