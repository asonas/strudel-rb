# frozen_string_literal: true

module Strudel
  module Scheduler
    class Cyclist
      ActiveVoice = Data.define(:player, :orbit, :pan)
      OrbitState = Data.define(:delay, :duck)

      attr_accessor :cps, :pattern
      attr_reader :sample_rate

      DEFAULT_CPS = 0.5 # cycles per second (1 cycle = 2 seconds)
      DEFAULT_SAMPLE_RATE = 44_100
      SYNTH_WAVEFORMS = %w[sine sawtooth square triangle supersaw white].freeze
      WAVEFORM_ALIASES = {
        "saw" => "sawtooth",
        "tri" => "triangle",
        "sqr" => "square",
        "sin" => "sine",
      }.freeze

      def initialize(sample_rate: DEFAULT_SAMPLE_RATE, cps: DEFAULT_CPS, samples_path: nil)
        @sample_rate = sample_rate
        @cps = cps
        @pattern = nil
        @sample_bank = Audio::SampleBank.new(samples_path)
        @active_players = []
        @current_cycle = Fraction.new(0)
        @mutex = Mutex.new
        @orbits = Hash.new do |h, k|
          h[k] = OrbitState.new(
            Audio::DelayLine.new(sample_rate: @sample_rate),
            Audio::DuckEnvelope.new(sample_rate: @sample_rate)
          )
        end
      end

      # Set the pattern
      def set_pattern(pattern)
        @mutex.synchronize do
          @pattern = pattern
        end
      end

      # Generate audio frames (called by VCA)
      def generate(frame_count)
        @mutex.synchronize do
          # Convert frame count to cycle count
          frames_per_cycle = @sample_rate / @cps
          duration_in_cycles = Fraction.new(Rational(frame_count, frames_per_cycle.to_i))

          end_cycle = @current_cycle + duration_in_cycles

          # Query pattern to get Haps
          if @pattern
            begin
              haps = @pattern.query_arc(@current_cycle.value, end_cycle.value)

              # Trigger sounds for Haps with onset
              haps.select(&:has_onset?).each do |hap|
                trigger_sound(hap)
              end
            rescue StandardError => e
              warn "Error querying pattern: #{e.message}"
            end
          end

          # Generate and mix samples from active players
          samples = mix_players(frame_count)

          # Remove finished players
          @active_players.reject! { |v| !v.player.playing? }

          @current_cycle = end_cycle
          samples
        end
      end

      # Reset cycle position
      def reset
        @mutex.synchronize do
          @current_cycle = Fraction.new(0)
          @active_players.clear
        end
      end

      private

      def trigger_sound(hap)
        value = hap.value

        # Extract sound name and sample number from value
        sound_name, sample_n = extract_sound_info(value)
        return unless sound_name

        sound_name = WAVEFORM_ALIASES.fetch(sound_name, sound_name)

        duration_seconds = hap.duration.to_f / @cps

        gain = extract_gain(value)
        orbit = extract_orbit(value)
        pan = extract_pan(value)
        delay_params = extract_delay_params(value, duration_seconds)
        duck_event = extract_duck_event(value)

        # For synth sounds
        if SYNTH_WAVEFORMS.include?(sound_name)
          detune = extract_detune(value)
          unison = extract_unison(value)
          spread = extract_spread(value)
          lpf_params = extract_lpf_params(value)
          amp_params = extract_amp_params(value)
          fm_params = extract_fm_params(value)

          player = Audio::SynthPlayer.new(
            sound_name.to_sym,
            sample_rate: @sample_rate,
            gain: gain,
            detune: detune,
            unison: unison,
            spread: spread
          )
          note = extract_note(value)
          player.trigger(
            note: note,
            duration: duration_seconds,
            detune: detune,
            **amp_params,
            **fm_params,
            **lpf_params
          )
          apply_orbit_delay(orbit, delay_params) if delay_params
          trigger_duck(duck_event) if duck_event
          @active_players << ActiveVoice.new(player, orbit, pan)
          return
        end

        # For sample sounds
        sample_data = @sample_bank.get(sound_name, sample_n)
        return if sample_data.empty?

        speed = extract_speed(value)
        amp_params = extract_amp_params(value)
        player = Audio::SamplePlayer.new(sample_data, @sample_rate)
        player.trigger(gain: gain, speed: speed, duration: duration_seconds, **amp_params)
        apply_orbit_delay(orbit, delay_params) if delay_params
        trigger_duck(duck_event) if duck_event
        @active_players << ActiveVoice.new(player, orbit, pan)
      end

      def extract_sound_info(value)
        case value
        when String
          [value, 0]
        when Hash
          name = value[:s] || value[:sound]
          n = value[:n] || 0
          [name, n]
        else
          [nil, 0]
        end
      end

      def extract_gain(value)
        return 1.0 unless value.is_a?(Hash)

        value[:gain] || value[:velocity]&./(127.0) || 1.0
      end

      def extract_note(value)
        return 60 unless value.is_a?(Hash) # Default: C4

        value[:note] || value[:n] || 60
      end

      def extract_speed(value)
        return 1.0 unless value.is_a?(Hash)

        value[:speed] || 1.0
      end

      def extract_orbit(value)
        return 1 unless value.is_a?(Hash)

        value[:orbit] || 1
      end

      def extract_pan(value)
        return 0.5 unless value.is_a?(Hash)

        value[:pan] || 0.5
      end

      def extract_delay_params(value, duration_seconds)
        return nil unless value.is_a?(Hash)

        wet = value[:delay]
        delaytime = value[:delaytime] || value[:delayt] || value[:dt]
        delayfeedback = value[:delayfeedback] || value[:delayfb] || value[:dfb]
        delaysync = value[:delaysync]

        return nil if wet.nil? && delaytime.nil? && delayfeedback.nil? && delaysync.nil?

        time =
          if delaytime
            delaytime.to_f
          elsif delaysync
            # delaysync is in cycles
            delaysync.to_f / @cps
          else
            0.25
          end

        {
          wet: wet.to_f,
          time: time,
          feedback: (delayfeedback || 0.5).to_f,
        }
      end

      def extract_duck_event(value)
        return nil unless value.is_a?(Hash)

        duckorbit = value[:duckorbit]
        duckdepth = value[:duckdepth]
        duckattack = value[:duckattack]
        duckonset = value[:duckonset] || 0.0

        return nil if duckorbit.nil? && duckdepth.nil? && duckattack.nil? && value[:duck].nil?

        {
          duckorbit: duckorbit || value[:duck],
          depth: (duckdepth || 1.0).to_f,
          onset: duckonset.to_f,
          attack: (duckattack || 0.2).to_f,
        }
      end

      def parse_duck_orbits(value)
        case value
        when Integer
          [value]
        when Float
          [value.to_i]
        when String
          value.split(":").map(&:to_i)
        else
          []
        end
      end

      def trigger_duck(event)
        targets = parse_duck_orbits(event[:duckorbit])
        return if targets.empty?

        targets.each do |orbit|
          @orbits[orbit].duck.trigger(onset: event[:onset], attack: event[:attack], depth: event[:depth])
        end
      end

      def apply_orbit_delay(orbit, params)
        state = @orbits[orbit]
        state.delay.configure(**params)
      end

      def extract_detune(value)
        return nil unless value.is_a?(Hash)

        value[:detune]
      end

      def extract_unison(value)
        return nil unless value.is_a?(Hash)

        value[:unison]
      end

      def extract_spread(value)
        return nil unless value.is_a?(Hash)

        value[:spread]
      end

      def extract_lpf_params(value)
        return {} unless value.is_a?(Hash)

        params = {}
        params[:lpf] = value[:lpf] if value[:lpf]
        params[:lpq] = value[:lpq] if value[:lpq]
        params[:lpenv] = value[:lpenv] if value[:lpenv]
        params[:lpa] = value[:lpa] if value[:lpa]
        params[:lpd] = value[:lpd] if value[:lpd]
        params[:lps] = value[:lps] if value[:lps]
        params[:lpr] = value[:lpr] if value[:lpr]
        params
      end

      def extract_amp_params(value)
        return {} unless value.is_a?(Hash)

        params = {}
        params[:attack] = value[:attack] if value[:attack]
        params[:decay] = value[:decay] if value[:decay]
        params[:sustain] = value[:sustain] if value[:sustain]
        params[:release] = value[:release] if value[:release]
        params
      end

      def extract_fm_params(value)
        return {} unless value.is_a?(Hash)

        params = {}
        params[:fmi] = value[:fmi] if value[:fmi]
        params[:fmh] = value[:fmh] if value[:fmh]
        params[:fmwave] = value[:fmwave] if value[:fmwave]
        params
      end

      def mix_players(frame_count)
        return [Array.new(frame_count, 0.0), Array.new(frame_count, 0.0)] if @active_players.empty?

        # Get samples from each player
        orbit_buffers = Hash.new do |h, k|
          h[k] = [Array.new(frame_count, 0.0), Array.new(frame_count, 0.0)]
        end

        @active_players.each do |voice|
          left, right = voice.player.generate(frame_count)

          # Strudel(superdough/supradough) panning:
          # pan in 0..1 -> panpos in 0..PI/2
          # left *= cos(panpos), right *= sin(panpos)
          pan = voice.pan.to_f.clamp(0.0, 1.0)
          if pan != 0.5
            panpos = (pan * Math::PI) / 2.0
            gain_l = Math.cos(panpos)
            gain_r = Math.sin(panpos)
            frame_count.times do |i|
              left[i] = left[i].to_f * gain_l
              right[i] = right[i].to_f * gain_r
            end
          end

          buf_l, buf_r = orbit_buffers[voice.orbit]
          frame_count.times do |i|
            buf_l[i] += left[i].to_f
            buf_r[i] += right[i].to_f
          end
        end

        mixed_l = Array.new(frame_count, 0.0)
        mixed_r = Array.new(frame_count, 0.0)
        orbit_buffers.each do |orbit, (buf_l, buf_r)|
          # Orbit-level delay (Strudel-like)
          processed_l, processed_r = @orbits[orbit].delay.process(buf_l, buf_r)
          # Orbit-level ducking (Strudel-like)
          gains = @orbits[orbit].duck.process(frame_count)
          frame_count.times do |i|
            g = gains[i]
            mixed_l[i] += processed_l[i] * g
            mixed_r[i] += processed_r[i] * g
          end
        end

        # Calculate target gain based on number of simultaneous sounds
        active_count = @active_players.count { |v| v.player.playing? }
        target_gain = active_count > 1 ? 1.0 / Math.sqrt(active_count) : 1.0

        # Initialize smoothed gain if not set
        @smoothed_gain ||= target_gain

        # Apply gain with smoothing to prevent clicks
        mixed_l.map!.with_index do |s, i|
          # Smooth gain changes over the buffer
          @smoothed_gain = @smoothed_gain * 0.999 + target_gain * 0.001
          # Soft limiter (tanh) to prevent harsh clipping
          soft_limit(s * @smoothed_gain)
        end
        mixed_r.map!.with_index do |s, i|
          # Keep gain smoothing in sync with left channel
          soft_limit(s * @smoothed_gain)
        end

        [mixed_l, mixed_r]
      end

      # Soft limiter using tanh - smoother than hard clipping
      def soft_limit(sample)
        if sample.abs > 0.8
          Math.tanh(sample)
        else
          sample
        end
      end
    end
  end
end
