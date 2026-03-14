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
              Legion::Logging.debug "[trust] get agent=#{agent_id} domain=#{domain} composite=#{entry[:composite].round(2)}"
              { found: true, trust: entry }
            else
              Legion::Logging.debug "[trust] get agent=#{agent_id} domain=#{domain} not found"
              { found: false, agent_id: agent_id, domain: domain }
            end
          end

          def record_trust_interaction(agent_id:, positive:, domain: :general, **)
            entry = trust_map.record_interaction(agent_id, domain: domain, positive: positive)
            Legion::Logging.info "[trust] interaction: agent=#{agent_id} domain=#{domain} positive=#{positive} composite=#{entry[:composite].round(2)} total=#{entry[:interaction_count]}"
            {
              agent_id:     agent_id,
              domain:       domain,
              positive:     positive,
              composite:    entry[:composite],
              interactions: entry[:interaction_count]
            }
          end

          def reinforce_trust_dimension(agent_id:, dimension:, domain: :general, amount: nil, **)
            amt = amount || Helpers::TrustModel::TRUST_REINFORCEMENT
            trust_map.reinforce_dimension(agent_id, domain: domain, dimension: dimension, amount: amt)
            entry = trust_map.get(agent_id, domain: domain)
            Legion::Logging.debug "[trust] reinforce: agent=#{agent_id} dimension=#{dimension} amount=#{amt} composite=#{entry[:composite].round(2)}"
            { agent_id: agent_id, domain: domain, dimension: dimension, composite: entry[:composite] }
          end

          def decay_trust(**)
            decayed = trust_map.decay_all
            Legion::Logging.debug "[trust] decay cycle: entries_updated=#{decayed}"
            { decayed: decayed }
          end

          def trusted_agents(domain: :general, min_trust: nil, **)
            min = min_trust || Helpers::TrustModel::TRUST_CONSIDER_THRESHOLD
            agents = trust_map.trusted_agents(domain: domain, min_trust: min)
            Legion::Logging.debug "[trust] trusted agents: domain=#{domain} min=#{min} count=#{agents.size}"
            { agents: agents, count: agents.size }
          end

          def delegatable_agents(domain: :general, **)
            agents = trust_map.delegatable_agents(domain: domain)
            Legion::Logging.debug "[trust] delegatable agents: domain=#{domain} count=#{agents.size}"
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
