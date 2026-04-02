# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Auth < Base
      def self.metadata
        {
          command: "auth",
          path: "shapeup auth",
          short: "Manage authentication profiles",
          subcommands: [
            { name: "status", short: "Check authentication status", path: "shapeup auth status" },
            { name: "list", short: "List configured profiles", path: "shapeup auth list" },
            { name: "switch", short: "Switch active profile", path: "shapeup auth switch <name>" },
            { name: "remove", short: "Remove a profile", path: "shapeup auth remove <name>" }
          ],
          flags: [],
          notes: [
            "Use 'shapeup login' to create a new profile via OAuth",
            "SHAPEUP_PROFILE env var overrides the default profile"
          ],
          examples: [
            "shapeup auth status",
            "shapeup auth list",
            "shapeup auth switch compass-labs",
            "shapeup auth remove old-profile"
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "status"      then status
        when "list"        then list
        when "switch"      then switch_profile
        when "remove"      then remove
        when "help", nil   then help
        else help
        end
      end

      private
        def status
          profile = Config.current_profile

          if profile
            data = {
              "authenticated" => true,
              "profile" => profile["profile_name"],
              "organisation" => profile["name"],
              "organisation_id" => profile["organisation_id"],
              "host" => profile["host"]
            }
          else
            data = { "authenticated" => false }
          end

          if @mode == :json || @mode == :agent
            Output.render(
              { "content" => [ { "type" => "text", "text" => JSON.generate(data) } ] },
              mode: @mode,
              summary: "Auth Status"
            )
          else
            if profile
              puts "Authenticated"
              puts "  profile   #{profile["profile_name"]}"
              puts "  org       #{profile["name"]}"
              puts "  host      #{profile["host"]}"
            else
              puts "Not authenticated. Run 'shapeup login' to connect."
            end
          end
        end

        def list
          profiles = Config.list_profiles

          if profiles.empty?
            puts "No profiles configured. Run 'shapeup login' to create one."
            return
          end

          profiles.each do |p|
            marker = p[:default] ? "*" : " "
            puts "  #{marker} #{p[:name].ljust(20)} #{p[:display_name]} (org: #{p[:organisation_id]})"
          end
          puts
          puts "  * = active profile"
        end

        def switch_profile
          name = positional_arg(1) || abort("Usage: shapeup auth switch <profile-name>")
          Config.switch_profile(name)
          puts "Switched to profile: #{name}"
        end

        def remove
          name = positional_arg(1) || abort("Usage: shapeup auth remove <profile-name>")
          Config.delete_profile(name)
          puts "Removed profile: #{name}"
        end

        def help
          puts <<~HELP
            Usage: shapeup auth <subcommand>

            Subcommands:
              status        Check if authenticated
              list          List all profiles
              switch <name> Switch active profile
              remove <name> Remove a profile

            Profiles store separate tokens and org defaults. Create profiles
            with 'shapeup login', then switch between them.

            Override with SHAPEUP_PROFILE env var.
          HELP
        end

        # Override: auth doesn't need an org_id
        def org_id = nil
    end
  end
end
