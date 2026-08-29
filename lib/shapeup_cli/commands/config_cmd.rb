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
            { name: "explain", short: "Trace where each setting's value comes from", path: "shapeup config explain" },
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
        when "set"     then set
        when "show"    then show
        when "explain" then explain
        when "init"    then init_project
        else show
        end
      end

      private
        def set
          key = positional_arg(1) || abort("Usage: shapeup config set <key> <value>")
          value = positional_arg(2) || abort("Usage: shapeup config set #{key} <value>")

          case key
          when "org"
            resolved = resolve_org(value)
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

        # Trace every setting through its full precedence chain, showing each
        # candidate and which one won. Token values are never printed.
        def explain
          settings = {
            "profile" => profile_candidates,
            "org" => org_candidates,
            "host" => host_candidates,
            "token" => token_candidates
          }

          if @mode == :styled || @mode == :markdown
            settings.each { |name, candidates| print_setting(name, candidates) }
          else
            data = settings.transform_values do |candidates|
              selected = candidates.find { |c| c[:selected] }
              { value: selected&.dig(:value), source: selected&.dig(:source), candidates: candidates }
            end
            render data
          end
        end

        def profile_candidates
          select_first [
            { source: "SHAPEUP_PROFILE env", value: ENV["SHAPEUP_PROFILE"] },
            { source: "profiles.json default", value: Config.saved_default_profile }
          ]
        end

        def org_candidates
          select_first [
            { source: "--org flag", value: @org_id },
            { source: "SHAPEUP_ORG env", value: ENV["SHAPEUP_ORG"] },
            { source: project_config_source, value: Config.project_config["organisation_id"] },
            { source: "~/.config/shapeup/config.json", value: Config.global_config["organisation_id"] },
            { source: "profile '#{Config.current_profile_name}'", value: Config.current_profile&.dig("organisation_id") }
          ]
        end

        def host_candidates
          select_first [
            { source: "SHAPEUP_HOST env", value: ENV["SHAPEUP_HOST"] },
            { source: project_config_source, value: Config.project_config["host"] },
            { source: "~/.config/shapeup/config.json", value: Config.global_config["host"] },
            { source: "profile '#{Config.current_profile_name}'", value: Config.current_profile&.dig("host") },
            { source: "built-in default", value: ShapeupCli::DEFAULT_HOST }
          ]
        end

        def token_candidates
          select_first [
            { source: "SHAPEUP_TOKEN env", value: ENV["SHAPEUP_TOKEN"] && "configured in environment" },
            { source: "profile '#{Config.current_profile_name}'", value: Config.current_profile&.dig("token") && "configured in profile" }
          ]
        end

        def project_config_source
          Config.project_config_path || Config::PROJECT_CONFIG_NAME
        end

        def select_first(candidates)
          winner = candidates.find { |c| !c[:value].nil? && c[:value] != "" }
          candidates.each { |c| c[:selected] = c.equal?(winner) }
        end

        def print_setting(name, candidates)
          puts name
          width = candidates.map { |c| c[:source].length }.max
          candidates.each do |c|
            marker = c[:selected] ? "  <- selected" : ""
            value = c[:value].nil? ? "(unset)" : c[:value]
            puts "  #{c[:source].ljust(width)}  #{value}#{marker}"
          end
          puts
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

          resolved = resolve_org(org_value)

          FileUtils.mkdir_p(".shapeup")
          File.write(".shapeup/config.json", JSON.pretty_generate(organisation_id: resolved.to_s))
          puts "Created .shapeup/config.json (org: #{resolved})"
          puts "All commands in this directory will use this organisation by default."
        end
    end
  end
end
