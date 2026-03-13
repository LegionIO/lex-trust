# frozen_string_literal: true

module Legion
  module Extensions
    module Trust
      module Helpers
        module TrustModel
          # Trust is emergent, multidimensional, domain-specific (spec design-decisions-v5 #4)
          TRUST_DIMENSIONS = %i[reliability competence integrity benevolence].freeze

          # Thresholds
          TRUST_CONSIDER_THRESHOLD = 0.3  # minimum trust to consider agent's input
          TRUST_DELEGATE_THRESHOLD = 0.7  # minimum trust to delegate actions
          TRUST_DECAY_RATE         = 0.005 # per-cycle decay
          TRUST_REINFORCEMENT      = 0.05  # per positive interaction
          TRUST_PENALTY            = 0.15  # per negative interaction (asymmetric)
          NEUTRAL_TRUST            = 0.3   # starting trust for new agents

          module_function

          def new_trust_entry(agent_id:, domain: :general)
            {
              agent_id:          agent_id,
              domain:            domain,
              dimensions:        TRUST_DIMENSIONS.to_h { |d| [d, NEUTRAL_TRUST] },
              composite:         NEUTRAL_TRUST,
              interaction_count: 0,
              positive_count:    0,
              negative_count:    0,
              last_interaction:  nil,
              created_at:        Time.now.utc
            }
          end

          def composite_score(dimensions)
            return 0.0 if dimensions.empty?

            dimensions.values.sum / dimensions.size
          end

          def clamp(value, min = 0.0, max = 1.0)
            [[value, min].max, max].min
          end
        end
      end
    end
  end
end
