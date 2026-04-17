# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Base
      def self.run(args)
        instance = new(args)
        if instance.agent_help?
          puts JSON.pretty_generate(instance.class.metadata)
        else
          instance.execute
        end
      end

      # Override in subclasses to define structured command metadata
      def self.metadata
        { command: name.split("::").last.downcase, description: "No metadata defined" }
      end

      def initialize(args)
        @mode, remaining = Output.parse_mode(args)
        @agent_help = @mode == :agent && remaining.include?("--help")
        remaining.delete("--help") if @agent_help
        @org_id, @remaining = extract_flags(remaining)
      end

      def agent_help?
        @agent_help
      end

      private
        def client
          @client ||= Client.new
        end

        def org_id
          resolve_org(@org_id || Config.organisation_id || abort("No organisation set. Run 'shapeup orgs' to see available orgs, then pass --org <id> or --org <name>."))
        end

        def call_tool(name, **args)
          client.call_tool(name, organisation: org_id.to_s, **args)
        end

        # Accept org ID (numeric) or name (string) — resolve name to ID via list_organisations
        def resolve_org(value)
          return value if value.to_s.match?(/\A\d+\z/)

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

        def render(result, breadcrumbs: [], summary: nil)
          Output.render(result, breadcrumbs: breadcrumbs, mode: @mode, summary: summary)
        end

        def extract_flags(args)
          org = nil
          remaining = []
          skip_next = false

          args.each_with_index do |arg, i|
            if skip_next
              skip_next = false
              next
            end

            case arg
            when "--org"
              org = args[i + 1]
              skip_next = true
            when /\A--org=(.+)\z/
              org = $1
            else
              remaining << arg
            end
          end

          [ org, remaining ]
        end

        # Parse --flag value pairs from remaining args
        def extract_option(flag)
          idx = @remaining.index(flag)
          return nil unless idx
          value = @remaining[idx + 1]
          @remaining.delete_at(idx + 1)
          @remaining.delete_at(idx)
          value
        end

        # Get the first positional arg (not a flag)
        def positional_arg(position = 0)
          positionals = @remaining.reject { |a| a.start_with?("--") }
          positionals[position]
        end

        # Get all positional args
        def positional_args
          @remaining.reject { |a| a.start_with?("--") }
        end

        # Presence-only boolean flag. Returns true if present, removes from @remaining.
        def consume_flag(flag)
          !!@remaining.delete(flag)
        end

        # Parse --comments/--no-comments + --comments-limit N into MCP args.
        def comment_flags
          args = {}
          args[:include_comments] = false if consume_flag("--no-comments")
          consume_flag("--comments") # explicit opt-in, no-op since default is true
          if (limit = extract_option("--comments-limit"))
            args[:comments_limit] = limit.to_i
          end
          args
        end
    end
  end
end
