# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Doctor < Base
      Check = Struct.new(:name, :status, :message, :hint, keyword_init: true)

      def self.metadata
        {
          command: "doctor",
          path: "shapeup doctor",
          short: "Diagnose CLI setup: config, auth, connectivity, and agent skills",
          subcommands: [],
          flags: [],
          notes: [
            "Each check reports pass, warn, fail, or skip with a fix hint",
            "Exits 0 when nothing failed, 1 otherwise"
          ],
          examples: [ "shapeup doctor", "shapeup doctor --json" ]
        }
      end

      def execute
        checks = [
          check_cli_version,
          check_ruby_version,
          check_config_dir,
          check_profiles_file,
          check_config_file,
          check_project_config,
          check_token,
          check_host_url,
          check_api_reachable,
          check_auth,
          check_org_access,
          check_claude_skills,
          check_agent,
          check_connector
        ]

        report(checks)
        exit 1 if checks.any? { |c| c.status == :fail }
      end

      private
        def check_cli_version
          pass "cli", "shapeup #{VERSION}"
        end

        def check_ruby_version
          pass "ruby", RUBY_VERSION
        end

        def check_config_dir
          if File.directory?(Config::CONFIG_DIR)
            File.writable?(Config::CONFIG_DIR) ?
              pass("config dir", Config::CONFIG_DIR) :
              fail!("config dir", "#{Config::CONFIG_DIR} is not writable")
          else
            warn! "config dir", "#{Config::CONFIG_DIR} does not exist yet", hint: "shapeup login"
          end
        end

        def check_profiles_file
          return warn!("profiles", "no profiles saved", hint: "shapeup login") unless File.exist?(Config::PROFILES_FILE)

          data = JSON.parse(File.read(Config::PROFILES_FILE))
          names = (data["profiles"] || {}).keys
          pass "profiles", "#{names.length} saved (default: #{data["default"] || "none"})"
        rescue JSON::ParserError
          fail! "profiles", "#{Config::PROFILES_FILE} is not valid JSON", hint: "shapeup logout"
        end

        def check_config_file
          return pass("global config", "(none)") unless File.exist?(Config::CONFIG_FILE)

          JSON.parse(File.read(Config::CONFIG_FILE))
          pass "global config", Config::CONFIG_FILE
        rescue JSON::ParserError
          fail! "global config", "#{Config::CONFIG_FILE} is not valid JSON"
        end

        def check_project_config
          path = Config.project_config_path
          return skip("project config", "none found") unless path

          JSON.parse(File.read(path))
          pass "project config", path
        rescue JSON::ParserError
          fail! "project config", "#{path} is not valid JSON"
        end

        def check_token
          if ENV["SHAPEUP_TOKEN"]
            pass "token", "from SHAPEUP_TOKEN"
          elsif Config.current_profile&.dig("token")
            pass "token", "from profile '#{Config.current_profile_name}'"
          else
            fail! "token", "no credentials found", hint: "shapeup login"
          end
        end

        def check_host_url
          uri = URI.parse(Config.host)
          if uri.is_a?(URI::HTTP) && uri.host
            pass "host", Config.host
          else
            fail! "host", "#{Config.host.inspect} is not a valid URL", hint: "shapeup config set host <url>"
          end
        rescue URI::InvalidURIError
          fail! "host", "#{Config.host.inspect} is not a valid URL", hint: "shapeup config set host <url>"
        end

        def check_api_reachable
          uri = URI.parse("#{Config.host}/up")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = uri.scheme == "https"
          http.open_timeout = 5
          http.read_timeout = 5
          response = http.get(uri.path)

          response.code.to_i < 500 ?
            pass("server", "#{Config.host} reachable") :
            fail!("server", "#{Config.host} responded with HTTP #{response.code}")
        rescue StandardError => e
          fail! "server", "couldn't reach #{Config.host} (#{e.class})", hint: "shapeup config explain"
        end

        def check_auth
          return skip("auth", "no token to test") unless Config.token

          result = Output.extract_data(client.call_tool("list_organisations"))
          @organisations = result.is_a?(Hash) ? (result["organisations"] || []) : Array(result)
          pass "auth", "signed in, #{@organisations.length} organisation(s)"
        rescue Client::AuthError
          fail! "auth", "token was rejected", hint: "shapeup login"
        rescue Client::ApiError => e
          fail! "auth", e.message
        end

        def check_org_access
          return skip("org", "auth not verified") unless @organisations

          org = Config.organisation_id
          return warn!("org", "no default organisation set", hint: "shapeup config set org <name>") unless org

          if @organisations.any? { |o| o["id"].to_s == org.to_s }
            pass "org", "##{org} accessible"
          else
            fail! "org", "##{org} is not among your organisations", hint: "shapeup orgs"
          end
        end

        def check_claude_skills
          states = Setup::SKILL_NAMES.to_h do |name|
            installed = File.join(Dir.home, ".claude", "skills", name, "SKILL.md")
            current = File.exist?(installed) && File.read(installed) == File.read(File.join(Setup::SKILLS_DIR, name, "SKILL.md"))
            [ name, File.exist?(installed) ? (current ? :current : :stale) : :missing ]
          end

          if states.values.all?(:current)
            pass "claude skills", "#{states.keys.join(", ")} installed and current"
          else
            behind = states.reject { |_, state| state == :current }.map { |name, state| "#{name} #{state == :missing ? "not installed" : "stale"}" }
            warn! "claude skills", behind.join(", "), hint: "shapeup setup claude"
          end
        end

        def check_agent
          return skip("agent", "auth not verified") unless @organisations && Config.organisation_id

          mine = Output.extract_data(client.call_tool("list_my_agents", organisation: Config.organisation_id.to_s))
          return pass("agent", "signed in as an agent") if mine["signed_in_as_agent"]

          @agent = mine["agents"].first
          return skip("agent", mine["can_add"] ? "you have no agent here" : "agents need a Pro organisation where you're a member") unless @agent

          handle = @agent["name"]
          profile = Config.profile(handle)
          return warn!("agent", "@#{handle} isn't connected on this computer yet", hint: "/shapeup-connect in Claude Code") unless profile&.dig("token")

          Client.new(host: profile["host"] || Config.host, token: profile["token"])
            .call_tool("list_inbox", organisation: (profile["organisation_id"] || Config.organisation_id).to_s)
          @connected_agent = handle
          pass "agent", "@#{handle} signs in with profile '#{handle}'"
        rescue Client::AuthError
          fail! "agent", "@#{handle}'s saved token was rejected", hint: "/shapeup-connect in Claude Code"
        rescue Client::ApiError => e
          fail! "agent", e.message
        end

        def check_connector
          return skip("connector", "no connected agent to listen for") unless @connected_agent

          if connector_running_for?(@connected_agent)
            pass "connector", "listening as @#{@connected_agent} on this computer"
          else
            warn! "connector", "not listening as @#{@connected_agent} on this computer", hint: "/shapeup-connect in Claude Code"
          end
        rescue Errno::ENOENT
          skip "connector", "can't check for running processes here"
        end

        def connector_running_for?(handle)
          commands = IO.popen([ "pgrep", "-lf", "shapeup connect" ], err: File::NULL, &:readlines)
          commands.any? { |command| command.match?(/--as @?#{Regexp.escape(handle)}\b/) || !command.include?("--as") }
        end

        def pass(name, message) = Check.new(name: name, status: :pass, message: message)
        def warn!(name, message, hint: nil) = Check.new(name: name, status: :warn, message: message, hint: hint)
        def fail!(name, message, hint: nil) = Check.new(name: name, status: :fail, message: message, hint: hint)
        def skip(name, message) = Check.new(name: name, status: :skip, message: message)

        STATUS_MARKS = { pass: "ok", warn: "!!", fail: "XX", skip: "--" }.freeze

        def report(checks)
          counts = checks.group_by(&:status).transform_values(&:length)
          summary = "#{counts.fetch(:pass, 0)} passed, #{counts.fetch(:warn, 0)} warnings, #{counts.fetch(:fail, 0)} failed, #{counts.fetch(:skip, 0)} skipped"
          breadcrumbs = checks.select { |c| c.hint }.map { |c| { cmd: c.hint, description: "fix: #{c.name}" } }

          if @mode == :styled
            width = checks.map { |c| c.name.length }.max
            checks.each do |c|
              line = "  #{STATUS_MARKS[c.status]}  #{c.name.ljust(width)}  #{c.message}"
              line += "  (#{c.hint})" if c.hint
              puts line
            end
            puts
            puts summary
            if breadcrumbs.any?
              puts
              puts "Next:"
              breadcrumbs.each { |b| puts "  #{b[:cmd]}  # #{b[:description]}" }
            end
          else
            render({ "checks" => checks.map { |c| c.to_h.compact }, "summary" => counts },
              breadcrumbs: breadcrumbs, summary: summary)
          end
        end
    end
  end
end
