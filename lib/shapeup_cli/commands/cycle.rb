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
            { name: "show", short: "Show cycle details with pitches and progress", path: "shapeup cycle show <id>" },
            { name: "create", short: "Create a cycle", path: "shapeup cycle create \"Title\" --start <date> --end <date>" },
            { name: "edit", short: "Update a cycle's title or dates", path: "shapeup cycle edit <id> --title \"New\"" },
            { name: "delete", short: "Delete a cycle (only if it has no pitches)", path: "shapeup cycle delete <id>" }
          ],
          flags: [
            { name: "status", type: "string", usage: "Filter by status: active, past, future, all" },
            { name: "title", type: "string", usage: "Cycle title (create/edit)" },
            { name: "start", type: "string", usage: "Start date YYYY-MM-DD (create/edit)" },
            { name: "end", type: "string", usage: "End date YYYY-MM-DD (create/edit)" }
          ],
          examples: [
            "shapeup cycles",
            "shapeup cycles --status active",
            "shapeup cycle show 12",
            "shapeup cycle create \"Cycle 13\" --start 2026-08-03 --end 2026-09-11",
            "shapeup cycle edit 12 --title \"Renamed\"",
            "shapeup cycle delete 12"
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "show"   then show
        when "create" then create
        when "edit"   then edit
        when "delete" then delete
        when "list", nil then list
        else
          subcommand.match?(/\A\d+\z/) ? show(subcommand) : list
        end
      end

      private
        def create
          title = positional_arg(1) || abort("Usage: shapeup cycle create \"Title\" --start <date> --end <date>")
          start_date = extract_option("--start") || abort("Missing --start <YYYY-MM-DD>")
          end_date = extract_option("--end") || abort("Missing --end <YYYY-MM-DD>")

          result = call_tool("create_cycle", title: title, start_date: start_date, end_date: end_date)

          render result,
            summary: "Cycle created",
            breadcrumbs: [ { cmd: "shapeup cycle show <id>", description: "View the cycle" } ]
        end

        def edit
          id = positional_arg(1) || abort("Usage: shapeup cycle edit <id> [--title ..] [--start ..] [--end ..]")
          args = { cycle: id.to_s }
          args[:title] = extract_option("--title") if @remaining.include?("--title")
          args[:start_date] = extract_option("--start") if @remaining.include?("--start")
          args[:end_date] = extract_option("--end") if @remaining.include?("--end")

          result = call_tool("update_cycle", **args)

          render result, summary: "Cycle ##{id} updated"
        end

        def delete
          yes = assume_yes?
          id = positional_arg(1) || abort("Usage: shapeup cycle delete <id> [--yes]")
          confirm_destructive!("Delete cycle ##{id}", yes)

          result = call_tool("delete_cycle", cycle: id.to_s)

          render result, summary: "Cycle ##{id} deleted"
        end

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
