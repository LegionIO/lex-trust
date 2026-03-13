# frozen_string_literal: true

require 'legion/extensions/trust/version'
require 'legion/extensions/trust/helpers/trust_model'
require 'legion/extensions/trust/helpers/trust_map'
require 'legion/extensions/trust/runners/trust'

module Legion
  module Extensions
    module Trust
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core
    end
  end
end
