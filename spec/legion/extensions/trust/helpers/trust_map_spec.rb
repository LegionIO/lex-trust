# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Legion::Extensions::Trust::Helpers::TrustMap do
  subject(:map) { described_class.new }

  let(:agent_id) { 'agent-001' }

  describe '#initialize' do
    it 'starts with an empty entries hash' do
      expect(map.entries).to eq({})
    end
  end

  describe '#get' do
    it 'returns nil for an unknown agent' do
      expect(map.get(agent_id)).to be_nil
    end

    it 'returns nil for a known agent in a different domain' do
      map.get_or_create(agent_id, domain: :code)
      expect(map.get(agent_id, domain: :ops)).to be_nil
    end

    it 'returns the entry after it has been created' do
      map.get_or_create(agent_id)
      expect(map.get(agent_id)).not_to be_nil
    end

    it 'retrieves an entry for the correct domain' do
      map.get_or_create(agent_id, domain: :code)
      entry = map.get(agent_id, domain: :code)
      expect(entry[:domain]).to eq(:code)
    end

    it 'defaults domain to :general' do
      map.get_or_create(agent_id)
      entry = map.get(agent_id)
      expect(entry[:domain]).to eq(:general)
    end
  end

  describe '#get_or_create' do
    it 'creates a new entry for a new agent' do
      entry = map.get_or_create(agent_id)
      expect(entry).not_to be_nil
    end

    it 'returns the same entry on subsequent calls' do
      first  = map.get_or_create(agent_id)
      second = map.get_or_create(agent_id)
      expect(first).to equal(second)
    end

    it 'initializes composite to NEUTRAL_TRUST' do
      entry = map.get_or_create(agent_id)
      expect(entry[:composite]).to eq(Legion::Extensions::Trust::Helpers::TrustModel::NEUTRAL_TRUST)
    end

    it 'creates independent entries per domain' do
      general = map.get_or_create(agent_id, domain: :general)
      code    = map.get_or_create(agent_id, domain: :code)
      expect(general).not_to equal(code)
    end

    it 'creates independent entries per agent' do
      a = map.get_or_create('agent-a')
      b = map.get_or_create('agent-b')
      expect(a).not_to equal(b)
    end
  end

  describe '#record_interaction' do
    context 'with a positive interaction' do
      it 'increments interaction_count by 1' do
        map.record_interaction(agent_id, positive: true)
        expect(map.get(agent_id)[:interaction_count]).to eq(1)
      end

      it 'increments positive_count by 1' do
        map.record_interaction(agent_id, positive: true)
        expect(map.get(agent_id)[:positive_count]).to eq(1)
      end

      it 'does not increment negative_count' do
        map.record_interaction(agent_id, positive: true)
        expect(map.get(agent_id)[:negative_count]).to eq(0)
      end

      it 'increases all dimension values above NEUTRAL_TRUST' do
        map.record_interaction(agent_id, positive: true)
        entry = map.get(agent_id)
        Legion::Extensions::Trust::Helpers::TrustModel::TRUST_DIMENSIONS.each do |dim|
          expect(entry[:dimensions][dim]).to be > Legion::Extensions::Trust::Helpers::TrustModel::NEUTRAL_TRUST
        end
      end

      it 'increases composite above NEUTRAL_TRUST' do
        map.record_interaction(agent_id, positive: true)
        expect(map.get(agent_id)[:composite]).to be > Legion::Extensions::Trust::Helpers::TrustModel::NEUTRAL_TRUST
      end

      it 'sets last_interaction to a recent time' do
        before = Time.now.utc
        map.record_interaction(agent_id, positive: true)
        expect(map.get(agent_id)[:last_interaction]).to be >= before
      end
    end

    context 'with a negative interaction' do
      it 'increments interaction_count by 1' do
        map.record_interaction(agent_id, positive: false)
        expect(map.get(agent_id)[:interaction_count]).to eq(1)
      end

      it 'increments negative_count by 1' do
        map.record_interaction(agent_id, positive: false)
        expect(map.get(agent_id)[:negative_count]).to eq(1)
      end

      it 'does not increment positive_count' do
        map.record_interaction(agent_id, positive: false)
        expect(map.get(agent_id)[:positive_count]).to eq(0)
      end

      it 'decreases composite below NEUTRAL_TRUST' do
        map.record_interaction(agent_id, positive: false)
        expect(map.get(agent_id)[:composite]).to be < Legion::Extensions::Trust::Helpers::TrustModel::NEUTRAL_TRUST
      end

      it 'applies the asymmetric penalty (penalty > reinforcement)' do
        map.record_interaction(agent_id, positive: true)
        positive_composite = map.get(agent_id)[:composite]
        map2 = described_class.new
        map2.record_interaction(agent_id, positive: false)
        negative_composite = map2.get(agent_id)[:composite]
        delta_positive = positive_composite - Legion::Extensions::Trust::Helpers::TrustModel::NEUTRAL_TRUST
        delta_negative = Legion::Extensions::Trust::Helpers::TrustModel::NEUTRAL_TRUST - negative_composite
        expect(delta_negative).to be > delta_positive
      end
    end

    it 'creates the entry if it does not exist' do
      map.record_interaction('new-agent', positive: true)
      expect(map.get('new-agent')).not_to be_nil
    end

    it 'tracks trust separately per domain' do
      map.record_interaction(agent_id, positive: true, domain: :code)
      map.record_interaction(agent_id, positive: false, domain: :ops)
      expect(map.get(agent_id, domain: :code)[:composite]).to be > map.get(agent_id, domain: :ops)[:composite]
    end
  end

  describe '#reinforce_dimension' do
    it 'increases the targeted dimension' do
      map.get_or_create(agent_id)
      map.reinforce_dimension(agent_id, dimension: :competence, amount: 0.2)
      entry = map.get(agent_id)
      expect(entry[:dimensions][:competence]).to be > Legion::Extensions::Trust::Helpers::TrustModel::NEUTRAL_TRUST
    end

    it 'does not change non-targeted dimensions' do
      map.get_or_create(agent_id)
      map.reinforce_dimension(agent_id, dimension: :competence, amount: 0.1)
      entry = map.get(agent_id)
      expect(entry[:dimensions][:reliability]).to eq(Legion::Extensions::Trust::Helpers::TrustModel::NEUTRAL_TRUST)
    end

    it 'updates composite after reinforcement' do
      map.get_or_create(agent_id)
      original_composite = map.get(agent_id)[:composite]
      map.reinforce_dimension(agent_id, dimension: :competence, amount: 0.2)
      expect(map.get(agent_id)[:composite]).to be > original_composite
    end

    it 'ignores an invalid dimension' do
      map.get_or_create(agent_id)
      original = map.get(agent_id)[:composite]
      map.reinforce_dimension(agent_id, dimension: :invalid_dim)
      expect(map.get(agent_id)[:composite]).to eq(original)
    end

    it 'clamps dimension to 1.0 maximum' do
      map.get_or_create(agent_id)
      map.reinforce_dimension(agent_id, dimension: :reliability, amount: 5.0)
      expect(map.get(agent_id)[:dimensions][:reliability]).to eq(1.0)
    end
  end

  describe '#decay_all' do
    it 'returns 0 when no entries exist' do
      expect(map.decay_all).to eq(0)
    end

    it 'returns the number of entries decayed' do
      map.get_or_create('agent-a')
      map.get_or_create('agent-b')
      expect(map.decay_all).to eq(2)
    end

    it 'reduces each dimension by TRUST_DECAY_RATE' do
      map.get_or_create(agent_id)
      map.decay_all
      entry = map.get(agent_id)
      Legion::Extensions::Trust::Helpers::TrustModel::TRUST_DIMENSIONS.each do |dim|
        expected = Legion::Extensions::Trust::Helpers::TrustModel::NEUTRAL_TRUST -
                   Legion::Extensions::Trust::Helpers::TrustModel::TRUST_DECAY_RATE
        expect(entry[:dimensions][dim]).to be_within(0.0001).of(expected)
      end
    end

    it 'floors dimensions at 0.0 when trust is already near-zero' do
      map.get_or_create(agent_id)
      200.times { map.decay_all }
      entry = map.get(agent_id)
      Legion::Extensions::Trust::Helpers::TrustModel::TRUST_DIMENSIONS.each do |dim|
        expect(entry[:dimensions][dim]).to eq(0.0)
      end
    end

    it 'recomputes composite after decay' do
      map.get_or_create(agent_id)
      before = map.get(agent_id)[:composite]
      map.decay_all
      expect(map.get(agent_id)[:composite]).to be < before
    end
  end

  describe '#trusted_agents' do
    it 'returns empty array when no entries exist' do
      expect(map.trusted_agents).to be_empty
    end

    it 'returns entries with composite >= min_trust' do
      5.times { map.record_interaction(agent_id, positive: true) }
      result = map.trusted_agents
      expect(result).not_to be_empty
      result.each do |entry|
        expect(entry[:composite]).to be >= Legion::Extensions::Trust::Helpers::TrustModel::TRUST_CONSIDER_THRESHOLD
      end
    end

    it 'excludes entries below min_trust' do
      map.record_interaction(agent_id, positive: false)
      expect(map.trusted_agents).to be_empty
    end

    it 'filters by domain' do
      5.times { map.record_interaction(agent_id, positive: true, domain: :code) }
      map.record_interaction('other-agent', positive: true, domain: :ops)
      result = map.trusted_agents(domain: :code)
      expect(result.all? { |e| e[:domain] == :code }).to be true
    end

    it 'sorts by composite descending' do
      5.times { map.record_interaction('agent-high', positive: true) }
      3.times { map.record_interaction('agent-low', positive: true) }
      result = map.trusted_agents
      composites = result.map { |e| e[:composite] }
      expect(composites).to eq(composites.sort.reverse)
    end

    it 'accepts a custom min_trust threshold' do
      5.times { map.record_interaction(agent_id, positive: true) }
      strict_result = map.trusted_agents(min_trust: 0.9)
      loose_result  = map.trusted_agents(min_trust: 0.3)
      expect(strict_result.size).to be <= loose_result.size
    end
  end

  describe '#delegatable_agents' do
    it 'requires TRUST_DELEGATE_THRESHOLD (higher than trusted_agents default)' do
      5.times { map.record_interaction(agent_id, positive: true) }
      trusted = map.trusted_agents.size
      delegatable = map.delegatable_agents.size
      expect(delegatable).to be <= trusted
    end

    it 'returns empty array when no entries meet the delegation threshold' do
      map.record_interaction(agent_id, positive: true)
      expect(map.delegatable_agents).to be_empty
    end
  end

  describe '#count' do
    it 'returns 0 for an empty map' do
      expect(map.count).to eq(0)
    end

    it 'counts total entries across all agents and domains' do
      map.get_or_create('a', domain: :general)
      map.get_or_create('a', domain: :code)
      map.get_or_create('b', domain: :general)
      expect(map.count).to eq(3)
    end
  end
end
