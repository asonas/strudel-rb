# frozen_string_literal: true

module Strudel
  class Pattern
    def initialize(&query)
      @query = query
    end

    # Returns an array of Haps based on the state
    def query(state)
      @query.call(state)
    end

    # Query by time range (convenience method)
    def query_arc(begin_time, end_time, controls = {})
      span = TimeSpan.new(begin_time, end_time)
      query(State.new(span, controls))
    end

    # ---- Factory Methods ----

    # Single value pattern (occurs once per cycle)
    def self.pure(value)
      Pattern.new do |state|
        state.span.span_cycles.map do |subspan|
          whole = subspan.begin_time.whole_cycle
          Hap.new(whole, subspan, value)
        end
      end
    end

    # Silent pattern
    def self.silence
      Pattern.new { |_state| [] }
    end

    # Convert value to pattern (returns as-is if already a pattern)
    def self.reify(value)
      return value if value.is_a?(Pattern)

      pure(value)
    end

    # Query-time value injection. The accessor block is evaluated on every
    # query, allowing external state (e.g. MIDI CC values) to be threaded
    # into a Pattern without re-evaluation of the user's pattern code.
    # Mirrors Strudel JS's ref().
    def self.ref(&accessor)
      raise ArgumentError, "block is required" unless accessor

      pure(1).with_value { |_| reify(accessor.call) }.inner_join
    end

    # Sequence (plays all patterns within one cycle)
    def self.fastcat(*items)
      return silence if items.empty?

      slowcat(*items).fast(items.length)
    end

    # Sequence (alias for fastcat)
    def self.sequence(*items)
      fastcat(*items)
    end

    # Plays one item per cycle
    def self.slowcat(*items)
      return silence if items.empty?

      patterns = items.map { |item| reify(item) }
      n = patterns.length

      Pattern.new do |state|
        state.span.span_cycles.flat_map do |subspan|
          cycle_num = subspan.begin_time.sam.to_i
          pattern_index = cycle_num % n
          patterns[pattern_index].query(state.set_span(subspan))
        end
      end
    end

    # Parallel playback (stack)
    def self.stack(*items)
      return silence if items.empty?

      patterns = items.map { |item| reify(item) }

      Pattern.new do |state|
        patterns.flat_map { |pattern| pattern.query(state) }
      end
    end

    # Euclidean rhythm
    def self.euclid(pulses, steps, rotation = 0)
      return silence if pulses <= 0 || steps <= 0

      # Generate beat pattern using Bjorklund algorithm
      pattern_array = bjorklund(pulses, steps)

      # Apply rotation
      pattern_array = pattern_array.rotate(rotation) if rotation != 0

      # Calculate beat positions
      step_duration = Rational(1, steps)
      beats = pattern_array.each_with_index.filter_map do |beat, i|
        beat ? i : nil
      end

      # Generate pattern
      Pattern.new do |state|
        state.span.span_cycles.flat_map do |subspan|
          cycle = subspan.begin_time.sam

          beats.filter_map do |beat_pos|
            whole_begin = cycle + Fraction.new(Rational(beat_pos, steps))
            whole_end = cycle + Fraction.new(Rational(beat_pos + 1, steps))
            whole = TimeSpan.new(whole_begin, whole_end)

            part = whole.intersection(subspan)
            next unless part

            Hap.new(whole, part, true)
          end
        end
      end
    end

    # Bjorklund algorithm (Euclidean rhythm generation)
    def self.bjorklund(pulses, steps)
      return Array.new(steps, false) if pulses == 0
      return Array.new(steps, true) if pulses >= steps

      # Initial pattern: pulses number of [1] and (steps-pulses) number of [0]
      groups = Array.new(pulses) { [true] } + Array.new(steps - pulses) { [false] }

      loop do
        # Count groups that are the same as the last group
        last_group = groups.last
        remainder_count = groups.count { |g| g == last_group }

        # Exit if only one remainder or all groups are the same
        break if remainder_count <= 1 || remainder_count == groups.length

        # Pop from the end and append to the beginning groups
        remainder_count.times do |i|
          break if groups.length <= remainder_count

          tail = groups.pop
          groups[i] = groups[i] + tail
        end
      end

      groups.flatten
    end

    # ---- Transformation Methods ----

    # Increase speed
    def fast(factor)
      factor = Fraction.new(factor) unless factor.is_a?(Fraction)

      with_query_time { |t| t * factor }
        .with_hap_time { |t| t / factor }
    end

    # Decrease speed
    def slow(factor)
      fast(Fraction.new(1) / Fraction.new(factor))
    end

    # Transform values
    def with_value(&block)
      Pattern.new do |state|
        query(state).map { |hap| hap.with_value(&block) }
      end
    end

    # fmap (alias for with_value)
    def fmap(&block)
      with_value(&block)
    end

    # Filter Haps
    def filter_haps(&predicate)
      Pattern.new do |state|
        query(state).select(&predicate)
      end
    end

    # Only Haps with onset
    def onsets_only
      filter_haps(&:has_onset?)
    end

    # Transform query time
    def with_query_time(&block)
      Pattern.new do |state|
        new_span = state.span.with_time(&block)
        query(state.set_span(new_span))
      end
    end

    # Transform Hap time
    def with_hap_time(&block)
      Pattern.new do |state|
        query(state).map do |hap|
          hap.with_span { |span| span.with_time(&block) }
        end
      end
    end

    # Split queries at cycle boundaries
    def split_queries
      Pattern.new do |state|
        state.span.span_cycles.flat_map do |subspan|
          query(state.set_span(subspan))
        end
      end
    end

    # ---- Arithmetic Methods ----

    # Add pattern values
    def add(other)
      apply_op(other) { |a, b| a + b }
    end

    # Subtract pattern values
    def sub(other)
      apply_op(other) { |a, b| a - b }
    end

    # Multiply pattern values
    def mul(other)
      apply_op(other) { |a, b| a * b }
    end

    # Divide pattern values
    def div(other)
      apply_op(other) { |a, b| a / b }
    end

    # Power pattern values
    def pow(other)
      apply_op(other) { |a, b| a**b }
    end

    # Fit sample to cycle length (Strudel JS parity).
    # Pairs with scheduler handling of unit: "c".
    def fit
      Pattern.new do |state|
        query(state).map do |hap|
          cps = Strudel.cps.to_f
          hap_duration = hap.whole ? hap.whole.duration.to_f : hap.part.duration.to_f
          slicedur = 1.0
          if hap.value.is_a?(Hash) && hap.value[:end] && hap.value[:begin]
            slicedur = hap.value[:end].to_f - hap.value[:begin].to_f
          end
          speed = (cps / hap_duration) * slicedur

          new_value = case hap.value
                      when Hash
                        hap.value.merge(unit: "c", speed: speed)
                      else
                        { s: hap.value, unit: "c", speed: speed }
                      end

          Hap.new(hap.whole, hap.part, new_value, hap.context)
        end
      end
    end

    # Apply function every n cycles
    def every(n, &func)
      Pattern.new do |state|
        state.span.span_cycles.flat_map do |subspan|
          cycle_num = subspan.begin_time.sam.to_i
          pat = (cycle_num % n == n - 1) ? func.call(self) : self
          pat.query(state.set_span(subspan))
        end
      end
    end

    # Reverse pattern playback
    def rev
      split_queries.then do |pat|
        Pattern.new do |state|
          span = state.span
          cycle = span.begin_time.sam

          # Function to reflect position within cycle
          reflect_in_cycle = lambda do |t, base_cycle|
            pos = t.value - base_cycle.value
            # Adjust if exceeding 1 (next cycle)
            pos = 1 if pos == 0 && t != base_cycle
            Fraction.new(base_cycle.value + (1 - pos))
          end

          # Calculate reflected range
          reflected_begin = reflect_in_cycle.call(span.end_time, cycle)
          reflected_end = reflect_in_cycle.call(span.begin_time, cycle)
          reflected_span = TimeSpan.new(reflected_begin, reflected_end)

          # Query with reflected range
          haps = pat.query(state.set_span(reflected_span))

          # Reflect time in result haps
          haps.map do |hap|
            hap_cycle = hap.whole&.begin_time&.sam || hap.part.begin_time.sam

            new_whole = hap.whole && begin
              w_begin = reflect_in_cycle.call(hap.whole.end_time, hap_cycle)
              w_end = reflect_in_cycle.call(hap.whole.begin_time, hap_cycle)
              TimeSpan.new(w_begin, w_end)
            end

            p_begin = reflect_in_cycle.call(hap.part.end_time, hap_cycle)
            p_end = reflect_in_cycle.call(hap.part.begin_time, hap_cycle)
            new_part = TimeSpan.new(p_begin, p_end)

            Hap.new(new_whole, new_part, hap.value, hap.context)
          end.sort_by { |h| h.part.begin_time.value }
        end
      end
    end

    # Transpose notes (in semitones)
    def trans(semitones)
      semitones_pattern = self.class.reify(semitones)

      Pattern.new do |state|
        query(state).flat_map do |hap|
          query_span = hap.whole || hap.part
          semitone_haps = semitones_pattern.query(state.set_span(query_span))

          semitone_haps.filter_map do |semitone_hap|
            intersection = hap.part.intersection(semitone_hap.part)
            next unless intersection

            new_whole = if hap.whole && semitone_hap.whole
                          hap.whole.intersection(semitone_hap.whole)
                        end

            new_value = if hap.value.is_a?(Hash) && hap.value[:note]
                          hap.value.merge(note: hap.value[:note] + semitone_hap.value)
                        else
                          hap.value
                        end

            Hap.new(new_whole, intersection, new_value)
          end
        end
      end
    end

    # Convert scale degrees to notes
    def scale(scale_spec)
      root, scale_name, octave = Theory::Scale.parse_scale_name(scale_spec)
      octave ||= 3 # Strudel/tonal default when tonic has no octave
      base_note = (octave + 1) * 12 + root

      with_value do |degree|
        semitone = Theory::Scale.degree_to_semitone(degree, scale_name)
        { note: base_note + semitone }
      end
    end

    # ---- Control Methods ----

    # Set sound source (waveform or sample name)
    def s(sound_name)
      set_control(:s, sound_name)
    end

    alias_method :sound, :s

    # Set volume (0.0 - 1.0)
    def gain(value)
      set_control(:gain, value)
    end

    # Set pan (0.0 = left, 0.5 = center, 1.0 = right)
    def pan(value)
      set_control(:pan, value)
    end

    # Set playback speed
    def speed(value)
      set_control(:speed, value)
    end

    # Delay amount (0-1). Currently accepted as a control but not rendered yet.
    def delay(value = 0.5)
      set_control(:delay, value)
    end

    def delaytime(value)
      set_control(:delaytime, value)
    end

    alias_method :delayt, :delaytime
    alias_method :dt, :delaytime

    def delayfeedback(value)
      set_control(:delayfeedback, value)
    end

    alias_method :delayfb, :delayfeedback
    alias_method :dfb, :delayfeedback

    def delaysync(value)
      set_control(:delaysync, value)
    end

    def delayspeed(value)
      set_control(:delayspeed, value)
    end

    # Set low-pass filter cutoff frequency (Hz)
    def lpf(value)
      set_control(:lpf, value)
    end

    # Set low-pass filter envelope amount (how much the envelope opens the filter)
    def lpenv(value)
      set_control(:lpenv, value)
    end

    # Set low-pass filter envelope attack time (seconds)
    def lpa(value)
      set_control(:lpa, value)
    end

    # Set low-pass filter envelope decay time (seconds)
    def lpd(value)
      set_control(:lpd, value)
    end

    # Set low-pass filter envelope sustain level (0.0 - 1.0)
    def lps(value)
      set_control(:lps, value)
    end

    # Set low-pass filter envelope release time (seconds)
    def lpr(value)
      set_control(:lpr, value)
    end

    # Set low-pass filter resonance (Q value, 0.0 - 1.0)
    def lpq(value)
      set_control(:lpq, value)
    end

    # Set high-pass filter cutoff frequency
    def hpf(value)
      set_control(:hpf, value)
    end

    # Set detune amount (for supersaw, etc.)
    def detune(value)
      set_control(:detune, value)
    end

    # Set number of stacked voices (for supersaw, etc.)
    def unison(value)
      set_control(:unison, value)
    end

    # Set stereo spread (for supersaw, etc.)
    # NOTE: Currently used as a hint only; strudel-rb renders mono internally.
    def spread(value)
      set_control(:spread, value)
    end

    # ---- Amp Envelope Controls (Strudel-like) ----

    def attack(value)
      set_control(:attack, value)
    end

    alias_method :att, :attack

    def decay(value)
      set_control(:decay, value)
    end

    alias_method :dec, :decay

    def sustain(value)
      set_control(:sustain, value)
    end

    alias_method :sus, :sustain

    def release(value)
      set_control(:release, value)
    end

    alias_method :rel, :release

    # ---- FM / Ducking (accepted but not rendered yet) ----

    # Frequency Modulation harmonicity ratio
    def fmh(value)
      set_control(:fmh, value)
    end

    # Frequency Modulation index (brightness). In Strudel this is `fmi` and `fm` is a synonym.
    def fmi(value)
      set_control(:fmi, value)
    end

    alias_method :fm, :fmi

    def fmwave(value)
      set_control(:fmwave, value)
    end

    def duckdepth(value)
      set_control(:duckdepth, value)
    end

    def duckattack(value)
      set_control(:duckattack, value)
    end

    def duckonset(value)
      set_control(:duckonset, value)
    end

    alias_method :duckons, :duckonset

    def duckorbit(value)
      set_control(:duckorbit, value)
    end

    alias_method :duck, :duckorbit

    # Visual helpers in Strudel (no-op in strudel-rb)
    def _pianoroll(*_args)
      self
    end

    # Set orbit (audio routing channel)
    def orbit(value)
      set_control(:orbit, value)
    end

    # Alias for orbit
    alias_method :o, :orbit

    # ---- Reverb Controls ----

    # Set reverb wet/dry mix (0.0 - 1.0)
    def room(value)
      set_control(:room, value)
    end

    # Set reverb room size (0 - 10)
    def roomsize(value)
      set_control(:roomsize, value)
    end

    alias_method :rsize, :roomsize
    alias_method :sz, :roomsize
    alias_method :size, :roomsize

    # ---- Tonal Controls ----

    # Transpose by octaves (additive). oct(2) = trans(24).
    def oct(value)
      trans(value.is_a?(Pattern) ? value.mul(12) : value * 12)
    end

    # Alias for trans (semitone transposition)
    alias_method :transpose, :trans

    # ---- Clip Control ----

    # Set clip (event duration factor, 0.0 - 1.0)
    def clip(value)
      set_control(:clip, value)
    end

    # ---- Distortion Controls ----

    # Set distortion amount
    def distort(value)
      set_control(:distort, value)
    end

    alias_method :dist, :distort

    # Set distortion type
    def distorttype(value)
      set_control(:distorttype, value)
    end

    # Sinefold distortion shortcut
    def sinefold(value)
      distort(value).distorttype("sinefold")
    end

    # Fold distortion shortcut
    def fold(value)
      distort(value).distorttype("fold")
    end

    # Diode distortion shortcut
    def diode(value)
      distort(value).distorttype("diode")
    end

    # Set post-distortion volume
    def distortvol(value)
      set_control(:distortvol, value)
    end

    # ---- Pattern Operation Methods ----

    # Segment: sample a continuous pattern into n discrete events per cycle.
    def segment(n)
      Pattern.new do |state|
        state.span.span_cycles.flat_map do |subspan|
          cycle = subspan.begin_time.sam
          step = Rational(1, n)

          n.times.filter_map do |i|
            seg_begin = cycle + Fraction.new(step * i)
            seg_end = cycle + Fraction.new(step * (i + 1))
            whole = TimeSpan.new(seg_begin, seg_end)

            part = whole.intersection(subspan)
            next unless part

            # Sample the pattern at the segment start
            sample_span = TimeSpan.new(seg_begin, seg_end)
            sample_state = state.set_span(sample_span)
            haps = query(sample_state)
            next if haps.empty?

            Hap.new(whole, part, haps.first.value)
          end
        end
      end
    end

    alias_method :seg, :segment

    # Ribbon: loop a section of the pattern from [offset, offset+cycles).
    def ribbon(offset, cycles)
      Pattern.new do |state|
        state.span.span_cycles.flat_map do |subspan|
          cycle_num = subspan.begin_time.sam.to_i
          mapped_cycle = offset + (cycle_num % cycles)
          shift = Fraction.new(mapped_cycle - cycle_num)

          shifted_span = TimeSpan.new(
            subspan.begin_time + shift,
            subspan.end_time + shift
          )

          query(state.set_span(shifted_span)).map do |hap|
            new_whole = hap.whole && TimeSpan.new(
              hap.whole.begin_time - shift,
              hap.whole.end_time - shift
            )
            new_part = TimeSpan.new(
              hap.part.begin_time - shift,
              hap.part.end_time - shift
            )
            Hap.new(new_whole, new_part, hap.value, hap.context)
          end
        end
      end
    end

    alias_method :rib, :ribbon

    # InnerJoin: flatten a Pattern<Pattern<T>> to Pattern<T>.
    # For each outer Hap whose value is a Pattern, query that inner pattern
    # within the outer Hap's time range and return intersecting Haps.
    # Non-Pattern values pass through unchanged.
    def inner_join
      Pattern.new do |state|
        query(state).flat_map do |outer_hap|
          unless outer_hap.value.is_a?(Pattern)
            next [outer_hap]
          end

          query_span = outer_hap.whole || outer_hap.part
          outer_hap.value.query(state.set_span(query_span)).filter_map do |inner_hap|
            intersection = outer_hap.part.intersection(inner_hap.part)
            next unless intersection

            new_whole = if outer_hap.whole && inner_hap.whole
                          outer_hap.whole.intersection(inner_hap.whole)
                        end

            Hap.new(new_whole, intersection, inner_hap.value)
          end
        end
      end
    end

    # Ply: repeat each event n times, subdividing its time span.
    def ply(n)
      n = n.to_i

      Pattern.new do |state|
        query(state).flat_map do |hap|
          whole = hap.whole || hap.part
          dur = whole.duration
          sub_dur = dur / n

          n.times.filter_map do |i|
            sub_begin = whole.begin_time + Fraction.new(sub_dur * i)
            sub_end = whole.begin_time + Fraction.new(sub_dur * (i + 1))
            sub_whole = TimeSpan.new(sub_begin, sub_end)

            sub_part = sub_whole.intersection(state.span)
            next unless sub_part

            Hap.new(sub_whole, sub_part, hap.value, hap.context)
          end
        end
      end
    end

    # Round: round numeric values to nearest integer.
    def round
      with_value { |v| v.round }
    end

    # Range: scale 0.0-1.0 values to min..max range.
    def range(min, max)
      with_value { |v| min + v * (max - min) }
    end

    # Fill: extend each event to fill the gap until the next event.
    def fill
      Pattern.new do |state|
        cycle = state.span.begin_time.sam
        wide_span = TimeSpan.new(cycle, cycle + Fraction.new(1))
        all_haps = query(state.set_span(wide_span))
          .select { |h| h.whole }
          .sort_by { |h| h.whole.begin_time.value }

        all_haps.each_with_index.filter_map do |hap, i|
          next_onset = if i + 1 < all_haps.length
                         all_haps[i + 1].whole.begin_time
                       else
                         cycle + Fraction.new(1)
                       end

          new_whole = TimeSpan.new(hap.whole.begin_time, next_onset)
          new_part = new_whole.intersection(state.span)
          next unless new_part

          Hap.new(new_whole, new_part, hap.value, hap.context)
        end
      end
    end

    # Beat: place events at specified beat positions within a division.
    def beat(positions_str, division)
      positions = positions_str.split(",").map { |p| p.strip.to_i }

      bool_array = Array.new(division, false)
      positions.each { |p| bool_array[p] = true if p < division }

      bool_pattern = self.class.fastcat(*bool_array)
      struct(bool_pattern)
    end

    # Scrub: set sample playback position control.
    def scrub(value)
      set_control(:scrub, value)
    end

    # Restart: restart this pattern at each onset of the trigger pattern.
    def restart(trigger_pattern)
      trigger_pattern = self.class.reify(trigger_pattern)

      Pattern.new do |state|
        state.span.span_cycles.flat_map do |subspan|
          trigger_haps = trigger_pattern.query(state.set_span(subspan))
            .select(&:has_onset?)

          if trigger_haps.empty?
            query(state.set_span(subspan))
          else
            cycle = subspan.begin_time.sam
            frac_begin = subspan.begin_time - cycle
            frac_end = subspan.end_time - cycle
            restarted_span = TimeSpan.new(frac_begin, frac_end)

            query(state.set_span(restarted_span)).map do |hap|
              new_whole = hap.whole && TimeSpan.new(
                hap.whole.begin_time + cycle,
                hap.whole.end_time + cycle
              )
              new_part = TimeSpan.new(
                hap.part.begin_time + cycle,
                hap.part.end_time + cycle
              )
              Hap.new(new_whole, new_part, hap.value, hap.context)
            end
          end
        end
      end
    end

    # Mask: keep events where bool_pattern is truthy, remove where 0/falsy.
    # Unlike struct, mask preserves the original pattern's timing (whole).
    def mask(bool_pattern)
      bool_pattern = self.class.reify(bool_pattern)

      Pattern.new do |state|
        query(state).select do |hap|
          query_span = hap.whole || hap.part
          bool_haps = bool_pattern.query(state.set_span(query_span))
          bool_haps.any? { |bh| bh.part.intersection(hap.part) && bh.value != 0 && bh.value }
        end
      end
    end

    # Apply euclidean rhythm structure to this pattern.
    def euclid(pulses, steps, rotation = 0)
      struct(self.class.euclid(pulses, steps, rotation))
    end

    # Apply a boolean pattern as rhythmic structure.
    # Only events where the bool pattern is true are kept.
    def struct(bool_pattern)
      bool_pattern = self.class.reify(bool_pattern)

      Pattern.new do |state|
        bool_pattern.query(state).flat_map do |bool_hap|
          next [] unless bool_hap.value

          query_span = bool_hap.whole || bool_hap.part
          query(state.set_span(query_span)).filter_map do |hap|
            intersection = hap.part.intersection(bool_hap.part)
            next unless intersection

            Hap.new(bool_hap.whole, intersection, hap.value)
          end
        end
      end
    end

    # ---- Probability Methods ----

    # Apply function with given probability per event.
    def sometimes_by(prob, &func)
      Pattern.new do |state|
        original_haps = query(state)
        transformed_haps = func.call(self).query(state)

        original_haps.zip(transformed_haps).map do |orig, trans|
          t = (orig.whole || orig.part).begin_time.to_f
          rand_val = self.class.send(:time_to_rand, t + 0.123)
          rand_val < prob ? (trans || orig) : orig
        end
      end
    end

    def sometimes(&func)
      sometimes_by(0.5, &func)
    end

    def often(&func)
      sometimes_by(0.75, &func)
    end

    def rarely(&func)
      sometimes_by(0.25, &func)
    end

    def almost_never(&func)
      sometimes_by(0.1, &func)
    end

    alias_method :almostNever, :almost_never

    def almost_always(&func)
      sometimes_by(0.9, &func)
    end

    alias_method :almostAlways, :almost_always

    # Remove events with given probability.
    def degrade_by(amount)
      Pattern.new do |state|
        query(state).select do |hap|
          t = (hap.whole || hap.part).begin_time.to_f
          rand_val = self.class.send(:time_to_rand, t + 0.456)
          rand_val >= amount
        end
      end
    end

    def degrade
      degrade_by(0.5)
    end

    def inspect
      "Pattern"
    end

    private

    # Deterministic pseudo-random value for a given time (0..1)
    def self.time_to_rand(x)
      t = x / 300.0
      frac = t - t.truncate
      seed = (frac * 536_870_912).truncate
      a = int32((seed << 13) ^ seed)
      b = int32((a >> 17) ^ a)
      c = int32((b << 5) ^ b)
      (c.remainder(536_870_912) / 536_870_912.0).abs
    end

    def self.int32(n)
      n &= 0xFFFF_FFFF
      n >= 0x8000_0000 ? n - 0x1_0000_0000 : n
    end

    # Set control value (pattern-aware with inner join)
    def set_control(key, value)
      value_pattern = self.class.reify(value)

      Pattern.new do |state|
        query(state).flat_map do |hap|
          query_span = hap.whole || hap.part
          value_haps = value_pattern.query(state.set_span(query_span))

          value_haps.filter_map do |value_hap|
            intersection = hap.part.intersection(value_hap.part)
            next unless intersection

            new_whole = if hap.whole && value_hap.whole
                          hap.whole.intersection(value_hap.whole)
                        end

            new_value = hap.value.is_a?(Hash) ? hap.value.merge(key => value_hap.value) : { key => value_hap.value }
            Hap.new(new_whole, intersection, new_value)
          end
        end
      end
    end

    # Apply binary operation (inner join)
    def apply_op(other, &block)
      other_pattern = self.class.reify(other)

      Pattern.new do |state|
        query(state).flat_map do |hap_left|
          # Query right pattern with left Hap's whole time range
          query_span = hap_left.whole || hap_left.part
          right_haps = other_pattern.query(state.set_span(query_span))

          right_haps.filter_map do |hap_right|
            # Calculate overlapping part of two Haps' time ranges
            intersection = hap_left.part.intersection(hap_right.part)
            next unless intersection

            # New whole (intersection of both wholes)
            new_whole = if hap_left.whole && hap_right.whole
                          hap_left.whole.intersection(hap_right.whole)
                        end

            # Combine values with operation
            new_value = combine_values(hap_left.value, hap_right.value, &block)
            Hap.new(new_whole, intersection, new_value)
          end
        end
      end
    end

    # Combine two values with a binary operation.
    # When both values are Hashes, merge them and apply the operation
    # to shared numeric keys (Strudel-compatible behavior).
    def combine_values(left, right, &block)
      if left.is_a?(Hash) && right.is_a?(Hash)
        left.merge(right) do |_key, lval, rval|
          if lval.is_a?(Numeric) && rval.is_a?(Numeric)
            block.call(lval, rval)
          else
            rval
          end
        end
      else
        block.call(left, right)
      end
    end
  end
end
