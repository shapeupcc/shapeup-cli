# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Logout
      def self.run(_args)
        Config.clear_credentials
        puts "Logged out."
      end
    end
  end
end
