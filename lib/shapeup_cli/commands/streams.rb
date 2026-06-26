# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Streams < Base
      def self.metadata
        {
          command: "streams",
          path: "shapeup streams",
          short: "List and show streams (product areas)",
          subcommands: [
            { name: "list", short: "List streams (default)", path: "shapeup streams list" },
            { name: "show", short: "Show stream details with pitches and issue counts", path: "shapeup streams show <id>" }
          ],
          flags: [
            { name: "all", type: "bool", usage: "Include archived streams (for list)" }
          ],
          examples: [
            "shapeup streams",
            "shapeup streams --all --json",
            "shapeup streams show 3"
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "show"      then show
        when "list", nil then list
        else
          subcommand.match?(/\A\d+\z/) ? show(subcommand) : list
        end
      end

      private
        def list
          args = {}
          args[:include_archived] = true if consume_flag("--all")

          result = call_tool("list_streams", **args)

          render result,
            summary: "Streams",
            breadcrumbs: [
              { cmd: "shapeup streams show <id>", description: "View stream details" },
              { cmd: "shapeup pitches create \"Title\" --stream \"Name\"", description: "Create a pitch in a stream" }
            ]
        end

        def show(id = nil)
          id ||= positional_arg(1) || abort("Usage: shapeup streams show <id>")

          result = call_tool("show_stream", stream: id.to_s)

          render result,
            summary: "Stream ##{id}",
            breadcrumbs: [
              { cmd: "shapeup pitches list --json", description: "List pitches" },
              { cmd: "shapeup issues --stream \"Name\"", description: "List issues in this stream" }
            ]
        end
    end
  end
end
