# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Cycle < Base
      def self.metadata
        {
          command: "cycle",
          path: "shapeup cycle",
          short: "List and show cycles",
          subcommands: [
            { name: "list", short: "List cycles (default)", path: "shapeup cycles" },
            { name: "show", short: "Show cycle details with pitches and progress", path: "shapeup cycle show <id>" }
          ],
          flags: [
            { name: "status", type: "string", usage: "Filter by status: active, past, future, all" }
          ],
          examples: [
            "shapeup cycles",
            "shapeup cycles --status active",
            "shapeup cycle show 12"
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "show"  then show
        when "list", nil then list
        else
          subcommand.match?(/\A\d+\z/) ? show(subcommand) : list
        end
      end

      private
        def list
          status = extract_option("--status")
          args = {}
          args[:status] = status if status

          result = call_tool("list_cycles", **args)

          render result,
            summary: "Cycles",
            breadcrumbs: [
              { cmd: "shapeup cycle show <id>", description: "View cycle details and progress" },
              { cmd: "shapeup cycles --status active", description: "Show active cycles only" }
            ]
        end

        def show(id = nil)
          id ||= positional_arg(1) || abort("Usage: shapeup cycle show <id>")

          result = call_tool("show_cycle", cycle: id.to_s)

          render result,
            summary: "Cycle ##{id}",
            breadcrumbs: [
              { cmd: "shapeup pitches list --cycle #{id}", description: "List pitches in this cycle" }
            ]
        end
    end
  end
end
