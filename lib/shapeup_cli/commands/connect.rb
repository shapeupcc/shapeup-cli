# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Connect < Base
      DEFAULT_INTERVAL = 30
      TRUST_LEVELS = %w[ owner members ].freeze

      def self.metadata
        {
          command: "connect",
          path: "shapeup connect",
          short: "For agents: watch the inbox and print each new request as a line of JSON",
          flags: [
            { name: "interval", type: "integer", usage: "Seconds between checks (default: #{DEFAULT_INTERVAL})" },
            { name: "trust", type: "string", usage: "Whose requests to pass on: owner (default) or members" },
            { name: "once", type: "bool", usage: "Check once and exit" }
          ],
          examples: [
            "SHAPEUP_PROFILE=bond shapeup connect",
            "SHAPEUP_PROFILE=bond shapeup connect --trust members",
            "SHAPEUP_PROFILE=bond shapeup connect --once"
          ]
        }
      end

      def execute
        @interval = (extract_option("--interval") || DEFAULT_INTERVAL).to_i.clamp(5, 3600)
        @trust = extract_option("--trust") || "owner"
        abort "--trust must be one of: #{TRUST_LEVELS.join(", ")}" unless TRUST_LEVELS.include?(@trust)
        once = consume_flag("--once")

        $stdout.sync = true
        @handed_out = Set.new

        poll(announce: true)
        until once
          sleep @interval
          poll
        end
      end

      private
        def poll(announce: false)
          inbox = Output.extract_data(call_tool("list_inbox"))
          agent = inbox["agent"]

          emit(type: "connected", agent: agent, organisation_id: org_id.to_s, trust: @trust, interval: @interval) if announce

          inbox["items"].reverse_each do |item|
            next unless @handed_out.add?(item["id"])

            if trusted?(item["requester"], agent)
              emit(type: "request", **item.transform_keys(&:to_sym))
            else
              emit(type: "ignored", id: item["id"], requester: item["requester"], why: "#{item["requester"]["name"]} is not trusted (--trust #{@trust})")
            end
          end
        rescue Client::NetworkError, Client::RateLimitError => error
          emit(type: "error", message: error.message, retryable: true)
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
