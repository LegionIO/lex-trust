# frozen_string_literal: true

require 'spec_helper'
require 'sequel'
require 'tmpdir'

RSpec.describe 'lex-trust local SQLite persistence' do
  let(:db_path) { File.join(Dir.tmpdir, "trust_test_#{Process.pid}_#{rand(9999)}.db") }
  let(:db) { Sequel.sqlite(db_path) }

  before do
    db.create_table(:trust_entries) do
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

    stub_const('Legion::Data::Local', Module.new do
      def self.connected?
        true
      end

      def self.connection
        @_connection
      end

      def self._set_connection(conn)
        @_connection = conn
      end
    end)

    Legion::Data::Local._set_connection(db)
  end

  after do
    db.disconnect
    FileUtils.rm_f(db_path)
  end

  describe 'save_to_local' do
    it 'writes an entry to the database' do
      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      map.record_interaction('agent-001', positive: true)
      map.save_to_local

      row = db[:trust_entries].where(agent_id: 'agent-001', domain: 'general').first
      expect(row).not_to be_nil
      expect(row[:agent_id]).to eq('agent-001')
      expect(row[:domain]).to eq('general')
      expect(row[:positive_count]).to eq(1)
      expect(row[:interaction_count]).to eq(1)
    end

    it 'updates an existing row on second save' do
      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      map.record_interaction('agent-001', positive: true)
      map.save_to_local

      map.record_interaction('agent-001', positive: false)
      map.save_to_local

      rows = db[:trust_entries].where(agent_id: 'agent-001', domain: 'general').all
      expect(rows.size).to eq(1)
      expect(rows.first[:negative_count]).to eq(1)
      expect(rows.first[:interaction_count]).to eq(2)
    end

    it 'persists composite score' do
      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      map.record_interaction('agent-001', positive: true)
      map.save_to_local

      row = db[:trust_entries].where(agent_id: 'agent-001', domain: 'general').first
      expect(row[:composite]).to be > 0.3
    end

    it 'persists all four dimension scores' do
      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      map.record_interaction('agent-001', positive: true)
      map.save_to_local

      row = db[:trust_entries].where(agent_id: 'agent-001', domain: 'general').first
      expect(row[:reliability]).to be > 0.3
      expect(row[:competence]).to be > 0.3
      expect(row[:integrity]).to be > 0.3
      expect(row[:benevolence]).to be > 0.3
    end

    it 'persists entries for multiple agents' do
      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      map.record_interaction('agent-a', positive: true)
      map.record_interaction('agent-b', positive: false)
      map.save_to_local

      expect(db[:trust_entries].count).to eq(2)
    end

    it 'persists entries for multiple domains of the same agent' do
      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      map.record_interaction('agent-001', positive: true, domain: :code)
      map.record_interaction('agent-001', positive: false, domain: :ops)
      map.save_to_local

      expect(db[:trust_entries].where(agent_id: 'agent-001').count).to eq(2)
    end

    it 'removes DB rows for entries removed from memory' do
      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      map.get_or_create('agent-a')
      map.get_or_create('agent-b')
      map.save_to_local

      expect(db[:trust_entries].count).to eq(2)

      # Simulate removal: build new map with only agent-a, then save
      map2 = Legion::Extensions::Trust::Helpers::TrustMap.new
      map2.save_to_local # loaded agent-a and agent-b from DB, both still in memory
      expect(db[:trust_entries].count).to eq(2) # nothing deleted yet

      # Remove agent-b from memory then save
      map2.entries.delete_if { |k, _| k.start_with?('agent-b') }
      map2.save_to_local

      expect(db[:trust_entries].count).to eq(1)
      expect(db[:trust_entries].first[:agent_id]).to eq('agent-a')
    end
  end

  describe 'load_from_local' do
    it 'restores entries from the database on initialize' do
      db[:trust_entries].insert(
        agent_id:          'agent-001',
        domain:            'general',
        reliability:       0.45,
        competence:        0.45,
        integrity:         0.45,
        benevolence:       0.45,
        composite:         0.45,
        interaction_count: 3,
        positive_count:    3,
        negative_count:    0,
        created_at:        Time.now.utc
      )

      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      entry = map.get('agent-001')
      expect(entry).not_to be_nil
      expect(entry[:composite]).to be_within(0.0001).of(0.45)
      expect(entry[:interaction_count]).to eq(3)
      expect(entry[:positive_count]).to eq(3)
    end

    it 'restores domain as a symbol' do
      db[:trust_entries].insert(
        agent_id:          'agent-001',
        domain:            'code',
        reliability:       0.3,
        competence:        0.3,
        integrity:         0.3,
        benevolence:       0.3,
        composite:         0.3,
        interaction_count: 0,
        positive_count:    0,
        negative_count:    0,
        created_at:        Time.now.utc
      )

      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      entry = map.get('agent-001', domain: :code)
      expect(entry).not_to be_nil
      expect(entry[:domain]).to eq(:code)
    end

    it 'restores all four dimension values' do
      db[:trust_entries].insert(
        agent_id:          'agent-001',
        domain:            'general',
        reliability:       0.6,
        competence:        0.5,
        integrity:         0.4,
        benevolence:       0.3,
        composite:         0.45,
        interaction_count: 0,
        positive_count:    0,
        negative_count:    0,
        created_at:        Time.now.utc
      )

      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      entry = map.get('agent-001')
      expect(entry[:dimensions][:reliability]).to be_within(0.0001).of(0.6)
      expect(entry[:dimensions][:competence]).to be_within(0.0001).of(0.5)
      expect(entry[:dimensions][:integrity]).to be_within(0.0001).of(0.4)
      expect(entry[:dimensions][:benevolence]).to be_within(0.0001).of(0.3)
    end

    it 'restores multiple entries' do
      db[:trust_entries].insert(
        agent_id: 'agent-a', domain: 'general',
        reliability: 0.3, competence: 0.3, integrity: 0.3, benevolence: 0.3,
        composite: 0.3, interaction_count: 0, positive_count: 0, negative_count: 0,
        created_at: Time.now.utc
      )
      db[:trust_entries].insert(
        agent_id: 'agent-b', domain: 'ops',
        reliability: 0.3, competence: 0.3, integrity: 0.3, benevolence: 0.3,
        composite: 0.3, interaction_count: 0, positive_count: 0, negative_count: 0,
        created_at: Time.now.utc
      )

      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      expect(map.count).to eq(2)
    end

    it 'allows normal operations on restored entries' do
      db[:trust_entries].insert(
        agent_id:          'agent-001',
        domain:            'general',
        reliability:       0.4,
        competence:        0.4,
        integrity:         0.4,
        benevolence:       0.4,
        composite:         0.4,
        interaction_count: 2,
        positive_count:    2,
        negative_count:    0,
        created_at:        Time.now.utc
      )

      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      map.record_interaction('agent-001', positive: true)
      entry = map.get('agent-001')
      expect(entry[:interaction_count]).to eq(3)
      expect(entry[:positive_count]).to eq(3)
    end
  end

  describe 'round-trip persistence' do
    it 'saves and restores trust score across instances' do
      map1 = Legion::Extensions::Trust::Helpers::TrustMap.new
      5.times { map1.record_interaction('agent-001', positive: true) }
      composite_before = map1.get('agent-001')[:composite]
      map1.save_to_local

      map2 = Legion::Extensions::Trust::Helpers::TrustMap.new
      expect(map2.get('agent-001')[:composite]).to be_within(0.0001).of(composite_before)
    end

    it 'round-trips interaction counts accurately' do
      map1 = Legion::Extensions::Trust::Helpers::TrustMap.new
      3.times { map1.record_interaction('agent-001', positive: true) }
      2.times { map1.record_interaction('agent-001', positive: false) }
      map1.save_to_local

      map2 = Legion::Extensions::Trust::Helpers::TrustMap.new
      entry = map2.get('agent-001')
      expect(entry[:interaction_count]).to eq(5)
      expect(entry[:positive_count]).to eq(3)
      expect(entry[:negative_count]).to eq(2)
    end

    it 'round-trips multiple agents independently' do
      map1 = Legion::Extensions::Trust::Helpers::TrustMap.new
      5.times { map1.record_interaction('agent-high', positive: true) }
      map1.record_interaction('agent-low', positive: false)
      map1.save_to_local

      map2 = Legion::Extensions::Trust::Helpers::TrustMap.new
      expect(map2.get('agent-high')[:composite]).to be > map2.get('agent-low')[:composite]
    end

    it 'round-trips domain-scoped entries independently' do
      map1 = Legion::Extensions::Trust::Helpers::TrustMap.new
      5.times { map1.record_interaction('agent-001', positive: true, domain: :code) }
      map1.record_interaction('agent-001', positive: false, domain: :ops)
      map1.save_to_local

      map2 = Legion::Extensions::Trust::Helpers::TrustMap.new
      code_entry = map2.get('agent-001', domain: :code)
      ops_entry  = map2.get('agent-001', domain: :ops)
      expect(code_entry[:composite]).to be > ops_entry[:composite]
    end

    it 'trusted_agents works correctly after round-trip' do
      map1 = Legion::Extensions::Trust::Helpers::TrustMap.new
      5.times { map1.record_interaction('agent-001', positive: true) }
      map1.save_to_local

      map2 = Legion::Extensions::Trust::Helpers::TrustMap.new
      trusted = map2.trusted_agents
      expect(trusted).not_to be_empty
      expect(trusted.first[:agent_id]).to eq('agent-001')
    end
  end

  describe 'graceful no-op when Legion::Data::Local is unavailable' do
    before do
      hide_const('Legion::Data::Local')
    end

    it 'initialize completes without raising' do
      expect { Legion::Extensions::Trust::Helpers::TrustMap.new }.not_to raise_error
    end

    it 'save_to_local does nothing without raising' do
      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      map.record_interaction('agent-001', positive: true)
      expect { map.save_to_local }.not_to raise_error
    end

    it 'starts with empty in-memory state' do
      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      expect(map.count).to eq(0)
    end

    it 'operates normally in memory when DB unavailable' do
      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      map.record_interaction('agent-001', positive: true)
      expect(map.get('agent-001')[:positive_count]).to eq(1)
    end
  end

  describe 'graceful no-op when Legion::Data::Local is defined but not connected' do
    before do
      stub_const('Legion::Data::Local', Module.new do
        def self.connected?
          false
        end
      end)
    end

    it 'initialize completes without raising' do
      expect { Legion::Extensions::Trust::Helpers::TrustMap.new }.not_to raise_error
    end

    it 'save_to_local does nothing without raising' do
      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      map.record_interaction('agent-001', positive: true)
      expect { map.save_to_local }.not_to raise_error
    end

    it 'starts with empty in-memory state' do
      map = Legion::Extensions::Trust::Helpers::TrustMap.new
      expect(map.count).to eq(0)
    end
  end
end
