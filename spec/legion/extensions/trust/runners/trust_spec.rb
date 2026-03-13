# frozen_string_literal: true

require 'legion/extensions/trust/client'

RSpec.describe Legion::Extensions::Trust::Runners::Trust do
  let(:client) { Legion::Extensions::Trust::Client.new }

  describe '#get_trust' do
    it 'returns found: false for unknown agent' do
      result = client.get_trust(agent_id: 'unknown')
      expect(result[:found]).to be false
    end
  end

  describe '#record_trust_interaction' do
    it 'creates entry and records positive interaction' do
      result = client.record_trust_interaction(agent_id: 'agent-1', positive: true)
      expect(result[:positive]).to be true
      expect(result[:composite]).to be > 0.3 # above neutral
    end

    it 'creates entry and records negative interaction' do
      result = client.record_trust_interaction(agent_id: 'agent-1', positive: false)
      expect(result[:composite]).to be < 0.3 # below neutral
    end

    it 'asymmetric: penalty > reinforcement' do
      client.record_trust_interaction(agent_id: 'agent-1', positive: true)
      client.get_trust(agent_id: 'agent-1')[:trust][:composite]

      client.record_trust_interaction(agent_id: 'agent-1', positive: false)
      after_negative = client.get_trust(agent_id: 'agent-1')[:trust][:composite]

      # Net of one positive + one negative should be below starting point
      expect(after_negative).to be < 0.3
    end

    it 'tracks per domain' do
      client.record_trust_interaction(agent_id: 'agent-1', domain: :code, positive: true)
      client.record_trust_interaction(agent_id: 'agent-1', domain: :ops, positive: false)

      code_trust = client.get_trust(agent_id: 'agent-1', domain: :code)
      ops_trust = client.get_trust(agent_id: 'agent-1', domain: :ops)

      expect(code_trust[:trust][:composite]).to be > ops_trust[:trust][:composite]
    end
  end

  describe '#reinforce_trust_dimension' do
    it 'reinforces specific dimension' do
      client.record_trust_interaction(agent_id: 'agent-1', positive: true)
      client.reinforce_trust_dimension(agent_id: 'agent-1', dimension: :competence, amount: 0.2)
      entry = client.get_trust(agent_id: 'agent-1')[:trust]
      expect(entry[:dimensions][:competence]).to be > entry[:dimensions][:reliability]
    end
  end

  describe '#decay_trust' do
    it 'decays all entries' do
      client.record_trust_interaction(agent_id: 'agent-1', positive: true)
      before = client.get_trust(agent_id: 'agent-1')[:trust][:composite]
      client.decay_trust
      after = client.get_trust(agent_id: 'agent-1')[:trust][:composite]
      expect(after).to be < before
    end
  end

  describe '#trusted_agents' do
    it 'returns agents above threshold' do
      5.times { client.record_trust_interaction(agent_id: 'agent-1', positive: true) }
      result = client.trusted_agents
      expect(result[:count]).to eq(1)
    end
  end

  describe '#delegatable_agents' do
    it 'requires higher trust for delegation' do
      3.times { client.record_trust_interaction(agent_id: 'agent-1', positive: true) }
      trusted = client.trusted_agents
      delegatable = client.delegatable_agents
      expect(delegatable[:count]).to be <= trusted[:count]
    end
  end
end
