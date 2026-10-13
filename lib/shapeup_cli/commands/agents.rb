# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Agents < Base
      def self.metadata
        {
          command: "agents",
          path: "shapeup agents",
          short: "List your agents, or add one (Pro, one per member)",
          subcommands: [
            { name: "list", short: "List your agents in this organisation", path: "shapeup agents" },
            { name: "add", short: "Add your agent", path: 'shapeup agents add "Bond" [--handle bond]' }
          ],
          flags: [
            { name: "handle", type: "string", usage: "The agent's handle (default: its name, lowercased)" }
          ],
          examples: [
            "shapeup agents",
            'shapeup agents add "Bond"',
            "shapeup connect"
          ]
        }
      end

      def execute
        case positional_arg(0)
        when "add" then add
        else list
        end
      end

      private
        def list
          render call_tool("list_my_agents"),
            summary: "Your agents",
            breadcrumbs: [
              { cmd: 'shapeup agents add "Name"', description: "Add your agent" },
              { cmd: "shapeup connect", description: "Listen for requests as your agent" }
            ]
        end

        def add
          handle = extract_option("--handle")
          name = positional_arg(1) || abort('Usage: shapeup agents add "Name" [--handle handle]')

          arguments = { display_name: name }
          arguments[:name] = handle if handle
          render call_tool("add_my_agent", **arguments),
            summary: "Agent added",
            breadcrumbs: [ { cmd: "shapeup connect", description: "Listen for requests as your agent" } ]
        end
    end
  end
end
