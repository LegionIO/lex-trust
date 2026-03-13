# frozen_string_literal: true

module Legion
  module Extensions
    module Trust
      module Helpers
        class TrustMap
          attr_reader :entries

          def initialize
            @entries = {} # key: "agent_id:domain"
          end

          def get(agent_id, domain: :general)
            @entries[key(agent_id, domain)]
          end

          def get_or_create(agent_id, domain: :general)
            @entries[key(agent_id, domain)] ||= TrustModel.new_trust_entry(agent_id: agent_id, domain: domain)
          end

          def record_interaction(agent_id, domain: :general, positive:)
            entry = get_or_create(agent_id, domain: domain)
            entry[:interaction_count] += 1
            entry[:last_interaction] = Time.now.utc

            if positive
              entry[:positive_count] += 1
              TrustModel::TRUST_DIMENSIONS.each do |dim|
                entry[:dimensions][dim] = TrustModel.clamp(entry[:dimensions][dim] + TrustModel::TRUST_REINFORCEMENT)
              end
            else
              entry[:negative_count] += 1
              TrustModel::TRUST_DIMENSIONS.each do |dim|
                entry[:dimensions][dim] = TrustModel.clamp(entry[:dimensions][dim] - TrustModel::TRUST_PENALTY)
              end
            end

            entry[:composite] = TrustModel.composite_score(entry[:dimensions])
            entry
          end

          def reinforce_dimension(agent_id, domain: :general, dimension:, amount: TrustModel::TRUST_REINFORCEMENT)
            entry = get_or_create(agent_id, domain: domain)
            return unless TrustModel::TRUST_DIMENSIONS.include?(dimension)

            entry[:dimensions][dimension] = TrustModel.clamp(entry[:dimensions][dimension] + amount)
            entry[:composite] = TrustModel.composite_score(entry[:dimensions])
          end

          def decay_all
            decayed = 0
            @entries.each_value do |entry|
              TrustModel::TRUST_DIMENSIONS.each do |dim|
                old = entry[:dimensions][dim]
                entry[:dimensions][dim] = TrustModel.clamp(old - TrustModel::TRUST_DECAY_RATE)
              end
              entry[:composite] = TrustModel.composite_score(entry[:dimensions])
              decayed += 1
            end
            decayed
          end

          def trusted_agents(domain: :general, min_trust: TrustModel::TRUST_CONSIDER_THRESHOLD)
            @entries.values
                    .select { |e| e[:domain] == domain && e[:composite] >= min_trust }
                    .sort_by { |e| -e[:composite] }
          end

          def delegatable_agents(domain: :general)
            trusted_agents(domain: domain, min_trust: TrustModel::TRUST_DELEGATE_THRESHOLD)
          end

          def count
            @entries.size
          end

          private

          def key(agent_id, domain)
            "#{agent_id}:#{domain}"
          end
        end
      end
    end
  end
end
