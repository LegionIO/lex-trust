# lex-trust

Emergent domain-specific trust modeling for brain-modeled agentic AI. Tracks multidimensional trust scores per agent-domain pair with reinforcement, decay, and delegation thresholds.

## Overview

`lex-trust` implements the agent's model of trust in other agents. Trust is not a single number — it is measured across four dimensions (reliability, competence, integrity, benevolence), is domain-specific, and emerges from observed interactions rather than being assigned. Negative interactions have a larger impact than positive ones (asymmetric update).

## Trust Dimensions

| Dimension | Description |
|-----------|-------------|
| `reliability` | Does the agent do what it says? |
| `competence` | Does the agent achieve good outcomes? |
| `integrity` | Does the agent act with honesty? |
| `benevolence` | Does the agent act in good faith? |

The composite score is the mean of all four dimensions.

## Trust Thresholds

| Threshold | Value | Meaning |
|-----------|-------|---------|
| Starting trust | 0.3 | Neutral starting point for new agents |
| Consider threshold | 0.3 | Minimum to include agent input |
| Delegate threshold | 0.7 | Minimum to delegate actions |
| Decay rate | 0.005/cycle | Trust decays without interaction |
| Reinforcement | +0.05/positive | Per positive interaction |
| Penalty | -0.15/negative | Per negative interaction (asymmetric) |

## Installation

Add to your Gemfile:

```ruby
gem 'lex-trust'
```

## Usage

### Recording Interactions

```ruby
require 'legion/extensions/trust'

# Record a positive interaction (increments all 4 dimensions by 0.05)
result = Legion::Extensions::Trust::Runners::Trust.record_trust_interaction(
  agent_id: "agent-42",
  positive: true,
  domain: :task_execution
)
# => { agent_id: "agent-42", domain: :task_execution, positive: true,
#      composite: 0.35, interactions: 1 }

# Record a negative interaction (decrements all 4 dimensions by 0.15)
Legion::Extensions::Trust::Runners::Trust.record_trust_interaction(
  agent_id: "agent-42",
  positive: false,
  domain: :task_execution
)
```

### Querying Trust

```ruby
# Get trust entry for specific agent/domain
Legion::Extensions::Trust::Runners::Trust.get_trust(agent_id: "agent-42", domain: :task_execution)

# List all agents above consider threshold
Legion::Extensions::Trust::Runners::Trust.trusted_agents(domain: :task_execution)

# List agents above delegate threshold (0.7)
Legion::Extensions::Trust::Runners::Trust.delegatable_agents(domain: :task_execution)
```

### Reinforcing Specific Dimensions

```ruby
# Reinforce a single trust dimension
Legion::Extensions::Trust::Runners::Trust.reinforce_trust_dimension(
  agent_id: "agent-42",
  dimension: :reliability,
  domain: :task_execution,
  amount: 0.05
)
```

### Decay

```ruby
# Apply decay to all trust entries (called periodically)
Legion::Extensions::Trust::Runners::Trust.decay_trust
# => { decayed: 3 }  (number of entries updated)
```

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
