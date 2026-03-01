# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::VCA do
  it "calls generator with smaller chunks for finer timing resolution" do
    call_sizes = []
    generator = Object.new
    generator.define_singleton_method(:generate) do |frame_count|
      call_sizes << frame_count
      [Array.new(frame_count, 0.0), Array.new(frame_count, 0.0)]
    end

    vca = Strudel::Audio::VCA.allocate
    vca.instance_variable_set(:@generator, generator)
    vca.instance_variable_set(:@buffer_size, 2048)

    left, right = vca.send(:generate_buffer)

    assert_equal 2048, left.length
    assert_equal 2048, right.length
    # 128フレームチャンクで16回呼ばれるはず
    assert_equal 16, call_sizes.length
    assert call_sizes.all? { |s| s == 128 }
  end
end
