# frozen_string_literal: true

module Legion
  module Extensions
    module Trust
      module Runners
        module Trust
          include Legion::Extensions::Helpers::Lex if Legion::Extensions.const_defined?(:Helpers) &&
                                                      Legion::Extensions::Helpers.const_defined?(:Lex)

          def get_trust(agent_id:, domain: :general, **)
            entry = trust_map.get(agent_id, domain: domain)
            if entry
              { found: true, trust: entry }
            else
              { found: false, agent_id: agent_id, domain: domain }
            end
          end

          def record_trust_interaction(agent_id:, domain: :general, positive:, **)
            entry = trust_map.record_interaction(agent_id, domain: domain, positive: positive)
            {
              agent_id:  agent_id,
              domain:    domain,
              positive:  positive,
              composite: entry[:composite],
              interactions: entry[:interaction_count]
            }
          end

          def reinforce_trust_dimension(agent_id:, domain: :general, dimension:, amount: nil, **)
            amt = amount || Helpers::TrustModel::TRUST_REINFORCEMENT
            trust_map.reinforce_dimension(agent_id, domain: domain, dimension: dimension, amount: amt)
            entry = trust_map.get(agent_id, domain: domain)
            { agent_id: agent_id, domain: domain, dimension: dimension, composite: entry[:composite] }
          end

          def decay_trust(**)
            decayed = trust_map.decay_all
            { decayed: decayed }
          end

          def trusted_agents(domain: :general, min_trust: nil, **)
            min = min_trust || Helpers::TrustModel::TRUST_CONSIDER_THRESHOLD
            agents = trust_map.trusted_agents(domain: domain, min_trust: min)
            { agents: agents, count: agents.size }
          end

          def delegatable_agents(domain: :general, **)
            agents = trust_map.delegatable_agents(domain: domain)
            { agents: agents, count: agents.size }
          end

          def trust_status(**)
            { total_entries: trust_map.count }
          end

          private

          def trust_map
            @trust_map ||= Helpers::TrustMap.new
          end
        end
      end
    end
  end
end
