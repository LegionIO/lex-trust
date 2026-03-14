# lex-trust

**Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## Purpose

Emergent domain-specific trust modeling for the LegionIO cognitive architecture. Maintains multidimensional trust scores per agent-domain pair, with asymmetric positive/negative reinforcement, periodic decay, and domain-scoped delegation thresholds.

## Gem Info

- **Gem name**: `lex-trust`
- **Version**: `0.1.0`
- **Module**: `Legion::Extensions::Trust`
- **Ruby**: `>= 3.4`
- **License**: MIT

## File Structure

```
lib/legion/extensions/trust/
  version.rb
  helpers/
    trust_model.rb  # TRUST_DIMENSIONS, thresholds, new_trust_entry, composite_score, clamp
    trust_map.rb    # TrustMap class - keyed by "agent_id:domain", CRUD + decay
  runners/
    trust.rb        # get_trust, record_trust_interaction, reinforce_trust_dimension,
                    # decay_trust, trusted_agents, delegatable_agents, trust_status
spec/
  legion/extensions/trust/
    runners/
      trust_spec.rb
    client_spec.rb
```

## Key Constants (Helpers::TrustModel)

```ruby
TRUST_DIMENSIONS         = %i[reliability competence integrity benevolence]
TRUST_CONSIDER_THRESHOLD = 0.3
TRUST_DELEGATE_THRESHOLD = 0.7
TRUST_DECAY_RATE         = 0.005   # per decay_all call
TRUST_REINFORCEMENT      = 0.05    # per positive interaction (all 4 dims)
TRUST_PENALTY            = 0.15    # per negative interaction (all 4 dims) - asymmetric
NEUTRAL_TRUST            = 0.3     # starting value for new entries
```

## TrustMap Key Scheme

Entries are stored as `"#{agent_id}:#{domain}"`. The `get_or_create` method uses this key, so the same agent can have independent trust profiles per domain.

## Composite Score

`TrustModel.composite_score(dimensions)` returns the arithmetic mean of all four dimension values. No weighting — all dimensions are equal.

## Record Interaction Logic

`TrustMap#record_interaction` uses `get_or_create`, increments interaction counts, then applies `TRUST_REINFORCEMENT` or `TRUST_PENALTY` uniformly across all four dimensions. After updating, it recomputes the composite score.

`reinforce_trust_dimension` allows targeted reinforcement of a single dimension.

## Decay

`decay_all` decrements every entry's every dimension by `TRUST_DECAY_RATE` (floors at 0.0). Recomputes composite. Returns count of entries updated. Intended to be called periodically by the scheduler.

## Integration Points

- **lex-mesh**: mesh routing considers trust when selecting delivery targets (`TRUST_CONSIDER_THRESHOLD = 0.3` referenced in lex-mesh topology)
- **lex-tick**: trust data influences `action_selection` phase decisions
- **lex-governance**: governance proposals can affect trust profiles directly

## Development Notes

- Trust entries are created lazily via `get_or_create` — calling `get_trust` for an unknown agent returns `{ found: false }` without creating an entry
- The `min_trust:` parameter in `trusted_agents` defaults to `TRUST_CONSIDER_THRESHOLD`
- `delegatable_agents` is just `trusted_agents` with `min_trust: TRUST_DELEGATE_THRESHOLD`
