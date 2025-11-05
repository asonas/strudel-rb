# frozen_string_literal: true

require "ffi-portaudio"

module Strudel
  module Audio
    class VCA < FFI::PortAudio::Stream
      include FFI::PortAudio

      SAMPLE_RATE = 44_100
      BUFFER_SIZE = 256

      def initialize(generator, sample_rate: SAMPLE_RATE, buffer_size: BUFFER_SIZE)
        @generator = generator
        @sample_rate = sample_rate
        @buffer_size = buffer_size
        @running = false

        setup_stream
      end

      def start
        return if @running

        super
        @running = true
      end

      def stop
        return unless @running

        super
        @running = false
      end

      def running?
        @running
      end

      def process(input, output, frame_count, time_info, status_flags, user_data)
        samples = @generator.generate(frame_count)

        # Mono to stereo conversion
        stereo_samples = []
        samples.each do |sample|
          # Clipping prevention
          clamped = sample.clamp(-1.0, 1.0)
          stereo_samples << clamped # left
          stereo_samples << clamped # right
        end

        output.write_array_of_float(stereo_samples)
        :paContinue
      end

      private

      def setup_stream
        output_params = API::PaStreamParameters.new
        output_params[:device] = API.Pa_GetDefaultOutputDevice
        output_params[:channelCount] = 2
        output_params[:sampleFormat] = API::Float32
        output_params[:suggestedLatency] = API.Pa_GetDeviceInfo(output_params[:device])[:defaultHighOutputLatency]
        output_params[:hostApiSpecificStreamInfo] = nil

        open(nil, output_params, @sample_rate, @buffer_size)
      end

      class << self
        def initialize_audio
          FFI::PortAudio::API.Pa_Initialize
        end

        def terminate_audio
          FFI::PortAudio::API.Pa_Terminate
        end
      end
    end
  end
end
