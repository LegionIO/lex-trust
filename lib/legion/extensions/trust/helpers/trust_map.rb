# frozen_string_literal: true

module Legion
  module Extensions
    module Trust
      module Helpers
        class TrustMap
          attr_reader :entries

          def initialize
            @entries = {} # key: "agent_id:domain"
            load_from_local
          end

          def get(agent_id, domain: :general)
            @entries[key(agent_id, domain)]
          end

          def get_or_create(agent_id, domain: :general)
            @entries[key(agent_id, domain)] ||= TrustModel.new_trust_entry(agent_id: agent_id, domain: domain)
          end

          def record_interaction(agent_id, positive:, domain: :general)
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

          def reinforce_dimension(agent_id, dimension:, domain: :general, amount: TrustModel::TRUST_REINFORCEMENT)
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

          def save_to_local
            return unless defined?(Legion::Data::Local) && Legion::Data::Local.connected?

            dataset = Legion::Data::Local.connection[:trust_entries]

            @entries.each_value do |entry|
              row = {
                agent_id:          entry[:agent_id].to_s,
                domain:            entry[:domain].to_s,
                reliability:       entry[:dimensions][:reliability],
                competence:        entry[:dimensions][:competence],
                integrity:         entry[:dimensions][:integrity],
                benevolence:       entry[:dimensions][:benevolence],
                composite:         entry[:composite],
                interaction_count: entry[:interaction_count],
                positive_count:    entry[:positive_count],
                negative_count:    entry[:negative_count],
                last_interaction:  entry[:last_interaction],
                created_at:        entry[:created_at]
              }
              existing = dataset.where(agent_id: row[:agent_id], domain: row[:domain]).first
              if existing
                dataset.where(agent_id: row[:agent_id], domain: row[:domain])
                       .update(row.except(:agent_id, :domain))
              else
                dataset.insert(row)
              end
            end

            # Remove DB rows for entries no longer in memory
            memory_pairs = @entries.values.map { |e| [e[:agent_id].to_s, e[:domain].to_s] }
            dataset.each do |row|
              pair = [row[:agent_id], row[:domain]]
              dataset.where(agent_id: pair[0], domain: pair[1]).delete unless memory_pairs.include?(pair)
            end
          rescue StandardError => e
            Legion::Logging.warn "[trust] save_to_local failed: #{e.message}" if defined?(Legion::Logging)
          end

          def load_from_local
            return unless defined?(Legion::Data::Local) && Legion::Data::Local.connected?

            Legion::Data::Local.connection[:trust_entries].each do |row|
              agent_id   = row[:agent_id]
              domain_str = row[:domain]
              domain_val = domain_str.to_sym
              entry_key  = "#{agent_id}:#{domain_str}"
              @entries[entry_key] = {
                agent_id:          agent_id,
                domain:            domain_val,
                dimensions:        {
                  reliability: row[:reliability].to_f,
                  competence:  row[:competence].to_f,
                  integrity:   row[:integrity].to_f,
                  benevolence: row[:benevolence].to_f
                },
                composite:         row[:composite].to_f,
                interaction_count: row[:interaction_count].to_i,
                positive_count:    row[:positive_count].to_i,
                negative_count:    row[:negative_count].to_i,
                last_interaction:  row[:last_interaction],
                created_at:        row[:created_at]
              }
            end
          rescue StandardError => e
            Legion::Logging.warn "[trust] load_from_local failed: #{e.message}" if defined?(Legion::Logging)
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
