# frozen_string_literal: true

require_relative "../spec_helper"

describe Strudel::Audio::DuckEnvelope do
  it "ducks down then returns to 1.0" do
    duck = Strudel::Audio::DuckEnvelope.new(sample_rate: 10)
    duck.trigger(onset: 0.2, attack: 0.2, depth: 0.5) # 2 samples down, 2 samples up

    gains = duck.process(6)

    assert_in_delta 1.0, gains[0], 0.0001
    assert gains[1] < 1.0
    assert_in_delta 0.5, gains[2], 0.0001
    assert gains[3] > gains[2]
    assert_in_delta 1.0, gains[5], 0.0001
  end
end

