# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Pitches < Base
      def self.metadata
        {
          command: "pitches",
          path: "shapeup pitches",
          short: "List and show pitches (packages)",
          subcommands: [
            { name: "list", short: "List pitches (default)", path: "shapeup pitches list" },
            { name: "show", short: "Show pitch details with scopes and tasks", path: "shapeup pitches show <id>" },
            { name: "help", short: "Show usage", path: "shapeup pitches help" }
          ],
          flags: [
            { name: "status", type: "string", usage: "Filter by status: idea, framed, shaped" },
            { name: "cycle", type: "string", usage: "Filter by cycle ID" },
            { name: "limit", type: "integer", usage: "Limit number of results" }
          ],
          examples: [
            "shapeup pitches list",
            "shapeup pitches list --status shaped",
            "shapeup pitches list --cycle 5",
            "shapeup pitch 42",
            "shapeup pitch 42 --json"
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "show"      then show
        when "list", nil then list
        when "help"      then help
        else
          subcommand.match?(/\A\d+\z/) ? show(subcommand) : list
        end
      end

      private
        def list
          cycle_id = extract_option("--cycle")
          status = extract_option("--status")
          limit = extract_option("--limit")&.to_i
          args = {}
          args[:cycle] = cycle_id if cycle_id

          result = call_tool("list_packages", **args)
          data = Output.extract_data(result)
          packages = data.is_a?(Hash) ? (data["packages"] || []) : Array(data)

          # Client-side filtering
          packages = packages.select { |p| p["status"] == status } if status
          packages = packages.first(limit) if limit

          summary = "Pitches"
          summary += " (#{status})" if status
          summary += " in cycle #{cycle_id}" if cycle_id
          summary += " — #{packages.length} results"

          render_list(packages, summary)
        end

        def show(id = nil)
          id ||= positional_arg(1) || abort("Usage: shapeup pitches show <id>")

          result = call_tool("show_package", package: id.to_s)

          render result,
            summary: "Pitch ##{id}",
            breadcrumbs: [
              { cmd: "shapeup scopes list --pitch #{id}", description: "List scopes" },
              { cmd: "shapeup scopes create --pitch #{id} \"Title\"", description: "Add a scope" },
              { cmd: "shapeup todo \"Task\" --pitch #{id}", description: "Add a task" },
              { cmd: "shapeup tasks list --pitch #{id}", description: "List all tasks" }
            ]
        end

        def render_list(packages, summary)
          # Build a simplified list for display
          items = packages.map do |p|
            {
              "id" => p["id"],
              "title" => p["title"],
              "status" => p["status"],
              "appetite" => p["appetite"],
              "cycle" => p["cycle"]
            }
          end

          Output.render(
            { "content" => [ { "type" => "text", "text" => JSON.generate(items) } ] },
            breadcrumbs: [
              { cmd: "shapeup pitch <id>", description: "View pitch details" },
              { cmd: "shapeup pitches list --status shaped", description: "Show shaped pitches" },
              { cmd: "shapeup pitches list --cycle <id>", description: "Filter by cycle" },
              { cmd: "shapeup pitches help", description: "Show usage" }
            ],
            mode: @mode,
            summary: summary
          )
        end

        def help
          puts <<~HELP
            Usage: shapeup pitches <subcommand> [options]

            Subcommands:
              list              List pitches (default)
              show <id>         Show pitch details
              help              This help

            Filters:
              --status <s>      Filter by status: idea, framed, shaped
              --cycle <id>      Filter by cycle
              --limit <n>       Limit results

            Output:
              --json            JSON envelope with breadcrumbs
              --md              Markdown table
              --agent           Raw data only

            Examples:
              shapeup pitches list
              shapeup pitches list --status shaped
              shapeup pitches list --cycle 5
              shapeup pitches list --status shaped --limit 10
              shapeup pitch 42
          HELP
        end
    end
  end
end
