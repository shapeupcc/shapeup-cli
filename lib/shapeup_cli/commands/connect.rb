# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Connect < Base
      DEFAULT_INTERVAL = 30
      TRUST_LEVELS = %w[ owner members ].freeze
      RETRY_DELAYS = [ 5, 10, 20, 40, 80, 120 ].freeze

      def self.metadata
        {
          command: "connect",
          path: "shapeup connect",
          short: "Listen for requests as your agent, printing each one as a line of JSON",
          flags: [
            { name: "as", type: "string", usage: "Which of your agents, by handle (default: your only one)" },
            { name: "interval", type: "integer", usage: "Seconds between checks (default: #{DEFAULT_INTERVAL})" },
            { name: "trust", type: "string", usage: "Whose requests to pass on: owner (default) or members" },
            { name: "once", type: "bool", usage: "Check once and exit" },
            { name: "until-request", type: "bool", usage: "Exit after the first check that passes on a request, remembering what was handed out" },
            { name: "fresh", type: "bool", usage: "With --until-request, forget what earlier runs handed out" }
          ],
          examples: [
            "shapeup connect",
            "shapeup connect --as bond --trust members",
            "SHAPEUP_PROFILE=bond shapeup connect --once",
            "shapeup connect --until-request --fresh"
          ]
        }
      end

      def execute
        handle = extract_option("--as")
        @interval = (extract_option("--interval") || DEFAULT_INTERVAL).to_i.clamp(5, 3600)
        @trust = extract_option("--trust") || "owner"
        abort "--trust must be one of: #{TRUST_LEVELS.join(", ")}" unless TRUST_LEVELS.include?(@trust)
        once = consume_flag("--once")
        @until_request = consume_flag("--until-request")
        @fresh = consume_flag("--fresh")

        $stdout.sync = true
        @profile, @agent_client = keep_trying(forever: !once) { sign_in_as_agent(handle) }

        poll
        until once || @requested
          pause @interval
          poll
        end
      end

      private
        def keep_trying(forever:)
          attempt = 0
          begin
            yield
          rescue Client::NetworkError, Client::RateLimitError => error
            raise unless forever

            delay = RETRY_DELAYS[attempt] || RETRY_DELAYS.last
            emit(type: "error", message: error.message, retryable: true, retrying_in: delay)
            pause delay
            attempt += 1
            retry
          end
        end

        def pause(seconds)
          sleep seconds
        end

        def sign_in_as_agent(handle)
          mine = Output.extract_data(call_tool("list_my_agents"))
          return [ ENV["SHAPEUP_PROFILE"], client ] if mine["signed_in_as_agent"]

          agent = choose_agent(mine["agents"], handle, can_add: mine["can_add"])
          token = Output.extract_data(call_tool("issue_my_agent_token", agent: agent["id"].to_s))["token"]
          Config.save_profile(agent["name"], token: token, host: Config.host, organisation_id: org_id.to_s, display_name: agent["display_name"])

          [ agent["name"], Client.new(host: Config.host, token: token) ]
        end

        def choose_agent(agents, handle, can_add:)
          if handle
            agents.find { |agent| agent["name"] == handle.delete_prefix("@") } or fail_with_agents("You have no agent called @#{handle} here.", agents)
          elsif agents.one?
            agents.first
          elsif agents.none?
            fail_with_agents(can_add ? 'You don\'t have an agent here yet. Add one with: shapeup agents add "Name"' : "Agents need a Pro organisation where you're a member.", agents)
          else
            fail_with_agents("You have several agents here. Pick one with --as <handle>.", agents)
          end
        end

        def fail_with_agents(message, agents)
          emit(type: "error", message: message, retryable: false, agents: agents.map { |agent| agent["name"] })
          exit EXIT_USAGE
        end

        def poll
          inbox = Output.extract_data(@agent_client.call_tool("list_inbox", organisation: org_id.to_s))
          agent = inbox["agent"]

          announce(agent) unless @connected
          @handed_out ||= Set.new(@until_request && !@fresh ? read_handed_out(agent) : [])

          inbox["items"].reverse_each do |item|
            next unless @handed_out.add?(item["id"])

            if trusted?(item["requester"], agent)
              emit(type: "request", **item.transform_keys(&:to_sym))
              @requested = @until_request
            else
              emit(type: "ignored", id: item["id"], requester: item["requester"], why: "#{item["requester"]["name"]} is not trusted (--trust #{@trust})")
            end
          end

          write_handed_out(agent, inbox["items"].map { |item| item["id"] }) if @until_request
        rescue Client::NetworkError, Client::RateLimitError => error
          emit(type: "error", message: error.message, retryable: true)
        end

        def handed_out_path(agent)
          File.join(Config::CONFIG_DIR, "connect", "#{agent["name"]}.json")
        end

        def read_handed_out(agent)
          JSON.parse(File.read(handed_out_path(agent)))
        rescue Errno::ENOENT, JSON::ParserError
          []
        end

        def write_handed_out(agent, waiting)
          @handed_out &= waiting
          FileUtils.mkdir_p(File.dirname(handed_out_path(agent)))
          File.write(handed_out_path(agent), JSON.generate(@handed_out.to_a))
        end

        def announce(agent)
          emit(type: "connected", agent: agent, profile: @profile, organisation_id: org_id.to_s, trust: @trust, interval: @interval)
          @connected = true
        end

        def trusted?(requester, agent)
          @trust == "members" || requester["id"] == agent.dig("owner", "id")
        end

        def emit(**event)
          puts JSON.generate(event)
        end
    end
  end
end
