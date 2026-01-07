# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::DelayLine do
  it "mixes in delayed signal according to delay time" do
    delay = Strudel::Audio::DelayLine.new(sample_rate: 10)
    delay.configure(wet: 1.0, time: 0.2, feedback: 0.0) # 2 samples

    left = [1.0, 0.0, 0.0, 0.0]
    right = [1.0, 0.0, 0.0, 0.0]

    out_l, out_r = delay.process(left, right)

    assert_in_delta 1.0, out_l[0], 0.0001
    assert_in_delta 0.0, out_l[1], 0.0001
    assert_in_delta 1.0, out_l[2], 0.0001
    assert_in_delta 0.0, out_l[3], 0.0001

    assert_equal out_l, out_r
  end
end
