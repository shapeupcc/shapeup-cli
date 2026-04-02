# frozen_string_literal: true

module ShapeupCli
  module Commands
    class ConfigCmd < Base
      def self.metadata
        {
          command: "config",
          path: "shapeup config",
          short: "Show and manage CLI configuration",
          subcommands: [
            { name: "show", short: "Show current config (default)", path: "shapeup config show" },
            { name: "set", short: "Set a config value", path: "shapeup config set <key> <value>" },
            { name: "init", short: "Create .shapeup/config.json for this directory", path: "shapeup config init <org>" }
          ],
          flags: [],
          notes: [
            "Config keys: org (organisation name or ID), host (ShapeUp URL)",
            "Resolution order: --org flag > .shapeup/config.json > ~/.config/shapeup/config.json"
          ],
          examples: [
            "shapeup config show",
            "shapeup config set org \"Acme Corp\"",
            "shapeup config init \"Acme Corp\""
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "set"  then set
        when "show" then show
        when "init" then init_project
        else show
        end
      end

      private
        def set
          key = positional_arg(1) || abort("Usage: shapeup config set <key> <value>")
          value = positional_arg(2) || abort("Usage: shapeup config set #{key} <value>")

          case key
          when "org"
            resolved = resolve_org_value(value)
            Config.save_config("organisation_id", resolved.to_s)
            puts "Default organisation set to #{resolved}"
          when "host"
            Config.save_config("host", value)
            puts "Host set to #{value}"
          else
            abort "Unknown config key: #{key}. Available: org, host"
          end
        end

        def show
          config = Config.load_config
          profile = Config.current_profile

          puts "Profile:"
          if profile
            puts "  active  #{profile["profile_name"]}"
            puts "  org     #{profile["name"]} (#{profile["organisation_id"]})"
            puts "  host    #{profile["host"]}"
            puts "  token   #{profile["token"][0..7]}..."
          else
            puts "  (not logged in)"
          end
          puts

          overrides = []
          overrides << "org=#{config["organisation_id"]}" if config["organisation_id"]
          overrides << "host=#{config["host"]}" if config["host"]
          if overrides.any?
            puts "Overrides:"
            puts "  #{overrides.join(", ")}"
            puts
          end

          puts "Files:"
          puts "  profiles  #{Config::PROFILES_FILE}"
          puts "  config    #{Config::CONFIG_FILE}"
          puts "  project   #{Config::PROJECT_CONFIG_NAME} #{find_project_display}"

          env_vars = []
          env_vars << "SHAPEUP_TOKEN" if ENV["SHAPEUP_TOKEN"]
          env_vars << "SHAPEUP_ORG" if ENV["SHAPEUP_ORG"]
          env_vars << "SHAPEUP_HOST" if ENV["SHAPEUP_HOST"]
          env_vars << "SHAPEUP_PROFILE" if ENV["SHAPEUP_PROFILE"]
          if env_vars.any?
            puts
            puts "Env vars active:"
            puts "  #{env_vars.join(", ")}"
          end
        end

        def find_project_display
          dir = Dir.pwd
          loop do
            candidate = File.join(dir, Config::PROJECT_CONFIG_NAME)
            return "(found: #{candidate})" if File.exist?(candidate)
            parent = File.dirname(dir)
            break if parent == dir
            dir = parent
          end
          "(not found)"
        end

        # Create .shapeup/config.json in the current directory
        def init_project
          org_value = positional_arg(1) || extract_option("--org") || @org_id
          abort("Usage: shapeup config init <org>") unless org_value

          resolved = resolve_org_value(org_value)

          FileUtils.mkdir_p(".shapeup")
          File.write(".shapeup/config.json", JSON.pretty_generate(organisation_id: resolved.to_s))
          puts "Created .shapeup/config.json (org: #{resolved})"
          puts "All commands in this directory will use this organisation by default."
        end

        def resolve_org_value(value)
          return value if value.to_s.match?(/\A\d+\z/)

          # Need to resolve name to ID
          result = client.call_tool("list_organisations")
          data = Output.extract_data(result)
          orgs = data.is_a?(Hash) ? (data["organisations"] || []) : Array(data)

          match = orgs.find { |o| o["name"]&.downcase == value.downcase }

          if match
            match["id"]
          else
            names = orgs.map { |o| "  #{o["id"]}  #{o["name"]}" }.join("\n")
            abort "Organisation '#{value}' not found. Available:\n#{names}"
          end
        end
    end
  end
end
