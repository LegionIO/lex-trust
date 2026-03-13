# frozen_string_literal: true

require_relative 'lib/legion/extensions/trust/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-trust'
  spec.version       = Legion::Extensions::Trust::VERSION
  spec.authors       = ['Esity']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'LEX Trust'
  spec.description   = 'Emergent domain-specific trust modeling for brain-modeled agentic AI'
  spec.homepage      = 'https://github.com/LegionIO/lex-trust'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/LegionIO/lex-trust'
  spec.metadata['documentation_uri'] = 'https://github.com/LegionIO/lex-trust'
  spec.metadata['changelog_uri'] = 'https://github.com/LegionIO/lex-trust'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/LegionIO/lex-trust/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir.glob('{lib,spec}/**/*') + %w[lex-trust.gemspec Gemfile]
  end
  spec.require_paths = ['lib']
end
