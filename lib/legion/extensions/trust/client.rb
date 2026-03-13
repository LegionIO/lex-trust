# frozen_string_literal: true

require 'legion/extensions/trust/helpers/trust_model'
require 'legion/extensions/trust/helpers/trust_map'
require 'legion/extensions/trust/runners/trust'

module Legion
  module Extensions
    module Trust
      class Client
        include Runners::Trust

        def initialize(**)
          @trust_map = Helpers::TrustMap.new
        end

        private

        attr_reader :trust_map
      end
    end
  end
end
