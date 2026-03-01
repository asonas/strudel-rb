# frozen_string_literal: true

require "ffi-portaudio"

module Strudel
  module Audio
    # Blocking-write audio output.
    #
    # Instead of using a PortAudio callback (which requires the GVL and therefore
    # competes with the Ruby scheduler thread), this class opens the stream in
    # blocking I/O mode and writes pre-generated audio via Pa_WriteStream.
    # Pa_WriteStream is a native C call that releases the GVL while waiting for
    # the device, so no GVL contention occurs.
    class VCA
      include FFI::PortAudio

      SAMPLE_RATE = 44_100
      BUFFER_SIZE = 2048
      CHUNK_SIZE = 128          # ~2.9ms sub-chunks for finer timing resolution
      SUGGESTED_LATENCY = 0.15  # 150ms – generous buffer for Ruby

      def initialize(generator, sample_rate: SAMPLE_RATE, buffer_size: BUFFER_SIZE)
        @generator = generator
        @sample_rate = sample_rate
        @buffer_size = buffer_size
        @running = false

        open_blocking_stream
        @write_buffer = FFI::MemoryPointer.new(:float, buffer_size * 2)
      end

      def start
        return if @running

        @running = true
        err = API.Pa_StartStream(@stream_ptr)
        unless err == :paNoError
          raise "Pa_StartStream failed: #{API.Pa_GetErrorText(err)}"
        end

        @thread = Thread.new { audio_loop }
        @thread.priority = 1  # higher priority for audio thread
      end

      def stop
        return unless @running

        @running = false
        @thread&.join(2)
        @thread = nil
        API.Pa_StopStream(@stream_ptr)
      end

      def running?
        @running
      end

      def close
        API.Pa_CloseStream(@stream_ptr) if @stream_ptr
        @stream_ptr = nil
      end

      class << self
        def initialize_audio
          FFI::PortAudio::API.Pa_Initialize
        end

        def terminate_audio
          FFI::PortAudio::API.Pa_Terminate
        end
      end

      private

      def open_blocking_stream
        output_params = API::PaStreamParameters.new
        output_params[:device] = API.Pa_GetDefaultOutputDevice
        output_params[:channelCount] = 2
        output_params[:sampleFormat] = API::Float32
        output_params[:suggestedLatency] = SUGGESTED_LATENCY
        output_params[:hostApiSpecificStreamInfo] = nil

        stream_holder = FFI::MemoryPointer.new(:pointer)
        err = API.Pa_OpenStream(
          stream_holder,
          nil,              # no input
          output_params,
          @sample_rate,
          @buffer_size,
          API::NoFlag,
          nil,              # no callback -> blocking I/O mode
          nil               # no user data
        )
        unless err == :paNoError
          raise "Pa_OpenStream failed: #{API.Pa_GetErrorText(err)}"
        end

        @stream_ptr = stream_holder.read_pointer
      end

      def generate_buffer
        chunks = @buffer_size / CHUNK_SIZE
        left = Array.new(@buffer_size, 0.0)
        right = Array.new(@buffer_size, 0.0)

        chunks.times do |c|
          cl, cr = @generator.generate(CHUNK_SIZE)
          offset = c * CHUNK_SIZE
          CHUNK_SIZE.times do |i|
            left[offset + i] = cl[i]
            right[offset + i] = cr[i]
          end
        end

        [left, right]
      end

      def audio_loop
        buf = @write_buffer

        while @running
          left, right = generate_buffer

          # Interleave stereo samples into FFI buffer
          @buffer_size.times do |i|
            buf.put_float32((i * 2) * 4, left[i].to_f.clamp(-1.0, 1.0))
            buf.put_float32((i * 2 + 1) * 4, right[i].to_f.clamp(-1.0, 1.0))
          end

          # Pa_WriteStream blocks until the device consumes the buffer.
          # As a native C call, it releases the GVL while waiting.
          err = API.Pa_WriteStream(@stream_ptr, buf, @buffer_size)
          if err != :paNoError && err != :paOutputUnderflowed
            warn "Pa_WriteStream: #{API.Pa_GetErrorText(err)}"
            break
          end
        end
      rescue => e
        warn "Audio thread error: #{e.message}"
      end
    end
  end
end
