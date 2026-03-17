# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:trust_entries) do
      primary_key :id
      String :agent_id, null: false
      String :domain, null: false
      Float :reliability, default: 0.3
      Float :competence, default: 0.3
      Float :integrity, default: 0.3
      Float :benevolence, default: 0.3
      Float :composite, default: 0.3
      Integer :interaction_count, default: 0
      Integer :positive_count, default: 0
      Integer :negative_count, default: 0
      DateTime :last_interaction
      DateTime :created_at, null: false
      unique %i[agent_id domain]
      index [:agent_id]
    end
  end
end
