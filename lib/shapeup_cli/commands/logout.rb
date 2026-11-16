# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Logout
      def self.run(_args)
        profiles = Config.profiles
        return puts("Not logged in.") if profiles.empty?

        profiles.each { |name, profile| puts ShapeupCli::Auth.forget(name, profile) }
        Config.clear_credentials
        puts "Logged out."
      end
    end
  end
end
