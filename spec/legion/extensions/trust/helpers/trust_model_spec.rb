# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Trust::Helpers::TrustModel do
  describe 'TRUST_DIMENSIONS' do
    it 'is a frozen array of symbols' do
      expect(described_class::TRUST_DIMENSIONS).to be_a(Array)
      expect(described_class::TRUST_DIMENSIONS).to be_frozen
    end

    it 'contains exactly four dimensions' do
      expect(described_class::TRUST_DIMENSIONS.size).to eq(4)
    end

    it 'includes reliability' do
      expect(described_class::TRUST_DIMENSIONS).to include(:reliability)
    end

    it 'includes competence' do
      expect(described_class::TRUST_DIMENSIONS).to include(:competence)
    end

    it 'includes integrity' do
      expect(described_class::TRUST_DIMENSIONS).to include(:integrity)
    end

    it 'includes benevolence' do
      expect(described_class::TRUST_DIMENSIONS).to include(:benevolence)
    end
  end

  describe 'threshold constants' do
    it 'TRUST_CONSIDER_THRESHOLD is 0.3' do
      expect(described_class::TRUST_CONSIDER_THRESHOLD).to eq(0.3)
    end

    it 'TRUST_DELEGATE_THRESHOLD is 0.7' do
      expect(described_class::TRUST_DELEGATE_THRESHOLD).to eq(0.7)
    end

    it 'delegate threshold is higher than consider threshold' do
      expect(described_class::TRUST_DELEGATE_THRESHOLD).to be > described_class::TRUST_CONSIDER_THRESHOLD
    end

    it 'TRUST_DECAY_RATE is 0.005' do
      expect(described_class::TRUST_DECAY_RATE).to eq(0.005)
    end

    it 'TRUST_REINFORCEMENT is 0.05' do
      expect(described_class::TRUST_REINFORCEMENT).to eq(0.05)
    end

    it 'TRUST_PENALTY is 0.15' do
      expect(described_class::TRUST_PENALTY).to eq(0.15)
    end

    it 'penalty is asymmetrically larger than reinforcement' do
      expect(described_class::TRUST_PENALTY).to be > described_class::TRUST_REINFORCEMENT
    end

    it 'NEUTRAL_TRUST is 0.3' do
      expect(described_class::NEUTRAL_TRUST).to eq(0.3)
    end

    it 'NEUTRAL_TRUST equals TRUST_CONSIDER_THRESHOLD (new agents are borderline trustworthy)' do
      expect(described_class::NEUTRAL_TRUST).to eq(described_class::TRUST_CONSIDER_THRESHOLD)
    end
  end

  describe '.new_trust_entry' do
    let(:entry) { described_class.new_trust_entry(agent_id: 'agent-42') }

    it 'sets agent_id' do
      expect(entry[:agent_id]).to eq('agent-42')
    end

    it 'defaults domain to :general' do
      expect(entry[:domain]).to eq(:general)
    end

    it 'respects a custom domain' do
      custom = described_class.new_trust_entry(agent_id: 'agent-1', domain: :code)
      expect(custom[:domain]).to eq(:code)
    end

    it 'initializes all four dimensions to NEUTRAL_TRUST' do
      described_class::TRUST_DIMENSIONS.each do |dim|
        expect(entry[:dimensions][dim]).to eq(described_class::NEUTRAL_TRUST)
      end
    end

    it 'sets composite to NEUTRAL_TRUST' do
      expect(entry[:composite]).to eq(described_class::NEUTRAL_TRUST)
    end

    it 'starts with zero interaction_count' do
      expect(entry[:interaction_count]).to eq(0)
    end

    it 'starts with zero positive_count' do
      expect(entry[:positive_count]).to eq(0)
    end

    it 'starts with zero negative_count' do
      expect(entry[:negative_count]).to eq(0)
    end

    it 'sets last_interaction to nil' do
      expect(entry[:last_interaction]).to be_nil
    end

    it 'sets created_at to a recent UTC time' do
      before = Time.now.utc
      e = described_class.new_trust_entry(agent_id: 'x')
      expect(e[:created_at]).to be >= before
    end

    it 'returns a different hash for each call' do
      a = described_class.new_trust_entry(agent_id: 'a')
      b = described_class.new_trust_entry(agent_id: 'b')
      expect(a).not_to equal(b)
    end
  end

  describe '.composite_score' do
    it 'returns the arithmetic mean of dimension values' do
      dims = { reliability: 0.8, competence: 0.6, integrity: 0.4, benevolence: 0.2 }
      expect(described_class.composite_score(dims)).to be_within(0.0001).of(0.5)
    end

    it 'returns 1.0 when all dimensions are 1.0' do
      dims = described_class::TRUST_DIMENSIONS.to_h { |d| [d, 1.0] }
      expect(described_class.composite_score(dims)).to eq(1.0)
    end

    it 'returns 0.0 when all dimensions are 0.0' do
      dims = described_class::TRUST_DIMENSIONS.to_h { |d| [d, 0.0] }
      expect(described_class.composite_score(dims)).to eq(0.0)
    end

    it 'returns NEUTRAL_TRUST for freshly initialized dimensions' do
      dims = described_class::TRUST_DIMENSIONS.to_h { |d| [d, described_class::NEUTRAL_TRUST] }
      expect(described_class.composite_score(dims)).to eq(described_class::NEUTRAL_TRUST)
    end

    it 'returns 0.0 for an empty dimensions hash' do
      expect(described_class.composite_score({})).to eq(0.0)
    end
  end

  describe '.clamp' do
    it 'returns the value when within range' do
      expect(described_class.clamp(0.5)).to eq(0.5)
    end

    it 'clamps to 0.0 when value is negative' do
      expect(described_class.clamp(-0.1)).to eq(0.0)
    end

    it 'clamps to 1.0 when value exceeds 1.0' do
      expect(described_class.clamp(1.5)).to eq(1.0)
    end

    it 'returns exactly 0.0 at the lower boundary' do
      expect(described_class.clamp(0.0)).to eq(0.0)
    end

    it 'returns exactly 1.0 at the upper boundary' do
      expect(described_class.clamp(1.0)).to eq(1.0)
    end

    it 'accepts custom min/max bounds' do
      expect(described_class.clamp(5.0, 0.0, 10.0)).to eq(5.0)
      expect(described_class.clamp(15.0, 0.0, 10.0)).to eq(10.0)
      expect(described_class.clamp(-1.0, 0.0, 10.0)).to eq(0.0)
    end
  end
end
