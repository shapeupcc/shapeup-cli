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
            { name: "create", short: "Create a new pitch", path: "shapeup pitches create \"Title\" --stream \"Name\"" },
            { name: "update", short: "Update a pitch's title, status, appetite, stream, or cycle", path: "shapeup pitches update <id> --status shaped" },
            { name: "extend", short: "Link a pitch as a continuation of a predecessor", path: "shapeup pitches extend <id> --predecessor <id>" },
            { name: "detach", short: "Remove a pitch's predecessor link", path: "shapeup pitches detach <id>" },
            { name: "delete", short: "Delete a pitch (must have no scopes)", path: "shapeup pitches delete <id>" },
            { name: "assign", short: "Assign a user", path: "shapeup pitches assign <id> [--user <id>]" },
            { name: "unassign", short: "Unassign a user", path: "shapeup pitches unassign <id> [--user <id>]" },
            { name: "help", short: "Show usage", path: "shapeup pitches help" }
          ],
          flags: [
            { name: "user", type: "string", usage: "User ID or 'me' (assign/unassign; defaults to me)" },
            { name: "status", type: "string", usage: "Filter by, or set, status: idea, framed, shaped" },
            { name: "cycle", type: "string", usage: "Filter by cycle ID (list), or assign to cycle ID (update)" },
            { name: "tag", type: "string", usage: "Filter by tag name" },
            { name: "limit", type: "integer", usage: "Limit number of results" },
            { name: "stream", type: "string", usage: "Stream name or ID (for create/update)" },
            { name: "appetite", type: "string", usage: "Appetite: unknown, small_batch, big_batch (create default: big_batch)" },
            { name: "cycle-id", type: "string", usage: "Assign to cycle ID (for create)" },
            { name: "title", type: "string", usage: "New title (for update)" },
            { name: "content", type: "string", usage: "New description (for update)" },
            { name: "predecessor", type: "string", usage: "Predecessor pitch ID (for extend)" },
            { name: "no-comments", type: "bool", usage: "Hide embedded comments on show (default: show)" },
            { name: "comments-limit", type: "integer", usage: "Max comments to embed on show (default: 10, max: 50)" }
          ],
          examples: [
            "shapeup pitches list",
            "shapeup pitches list --status shaped",
            "shapeup pitches list --cycle 5",
            "shapeup pitches list --tag q3-plan",
            "shapeup pitch 42",
            "shapeup pitch 42 --json",
            "shapeup pitches create \"Redesign Search\" --stream \"Platform\"",
            "shapeup pitches create \"Auth Overhaul\" --stream \"Platform\" --appetite small_batch",
            "shapeup pitches update 42 --status shaped",
            "shapeup pitches update 42 --title \"Redesign Search v2\" --appetite small_batch",
            "shapeup pitches update 42 --cycle 5",
            "shapeup pitches extend 42 --predecessor 30",
            "shapeup pitches detach 42",
            "shapeup pitches delete 42"
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "show"      then show
        when "create"    then create
        when "update"    then update
        when "extend"    then extend_pitch
        when "detach"    then detach
        when "delete"    then delete
        when "assign"    then assign_to("Package", "pitches")
        when "unassign"  then unassign_from("Package", "pitches")
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
          tag = extract_option("--tag")
          limit = extract_option("--limit")&.to_i
          args = {}
          args[:cycle] = cycle_id if cycle_id
          args[:tag] = tag if tag

          result = call_tool("list_packages", **args)
          data = Output.extract_data(result)
          packages = data.is_a?(Hash) ? (data["packages"] || []) : Array(data)

          # Client-side filtering
          packages = packages.select { |p| p["status"] == status } if status
          packages = packages.first(limit) if limit

          summary = "Pitches"
          summary += " (#{status})" if status
          summary += " in cycle #{cycle_id}" if cycle_id
          summary += " tagged #{tag}" if tag
          summary += " — #{packages.length} results"

          render_list(packages, summary)
        end

        def show(id = nil)
          id ||= positional_arg(1) || abort("Usage: shapeup pitches show <id>")

          result = call_tool("show_package", package: id.to_s, **comment_flags)

          render result,
            summary: "Pitch ##{id}",
            breadcrumbs: [
              { cmd: "shapeup scopes list --pitch #{id}", description: "List scopes" },
              { cmd: "shapeup scopes create --pitch #{id} \"Title\"", description: "Add a scope" },
              { cmd: "shapeup todo \"Task\" --pitch #{id}", description: "Add a task" },
              { cmd: "shapeup tasks list --pitch #{id}", description: "List all tasks" },
              { cmd: "shapeup pitch #{id} --no-comments", description: "Hide embedded comments" }
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

        def create
          title = positional_arg(1) || abort("Usage: shapeup pitches create \"Title\" --stream \"Name\"")
          stream = extract_option("--stream") || abort("Usage: shapeup pitches create \"Title\" --stream \"Name\"")
          appetite = extract_option("--appetite")
          cycle_id = extract_option("--cycle-id")

          args = { title: title, stream: stream }
          args[:appetite] = appetite if appetite
          args[:cycle] = cycle_id if cycle_id

          result = call_tool("create_package", **args)

          render result,
            summary: "Pitch created",
            breadcrumbs: [
              { cmd: "shapeup scopes create --pitch <id> \"Title\"", description: "Add a scope" },
              { cmd: "shapeup todo \"Task\" --pitch <id>", description: "Add a task" },
              { cmd: "shapeup pitch <id>", description: "View pitch details" }
            ]
        end

        def update
          id = positional_arg(1) || abort("Usage: shapeup pitches update <id> [--title \"...\"] [--status idea|framed|shaped] [--appetite ...] [--stream \"Name\"] [--content \"...\"] [--cycle <id>]")

          args = { package: id.to_s }
          args[:title] = extract_option("--title") if @remaining.include?("--title")
          args[:status] = extract_option("--status") if @remaining.include?("--status")
          args[:appetite] = extract_option("--appetite") if @remaining.include?("--appetite")
          args[:stream] = extract_option("--stream") if @remaining.include?("--stream")
          args[:content] = extract_option("--content") if @remaining.include?("--content")
          args[:cycle] = extract_option("--cycle") if @remaining.include?("--cycle")

          abort("Nothing to update. Pass at least one of --title, --status, --appetite, --stream, --content, --cycle") if args.size == 1

          result = call_tool("update_package", **args)

          render result,
            summary: "Pitch ##{id} updated",
            breadcrumbs: [
              { cmd: "shapeup pitch #{id}", description: "View pitch details" }
            ]
        end

        def extend_pitch
          id = positional_arg(1) || abort("Usage: shapeup pitches extend <id> --predecessor <id>")
          predecessor = extract_option("--predecessor") || abort("Usage: shapeup pitches extend <id> --predecessor <id>")

          result = call_tool("extend_package", package: id.to_s, predecessor: predecessor.to_s)

          render result,
            summary: "Pitch ##{id} now extends ##{predecessor}",
            breadcrumbs: [
              { cmd: "shapeup pitch #{id}", description: "View pitch details" },
              { cmd: "shapeup pitches detach #{id}", description: "Remove the predecessor link" }
            ]
        end

        def detach
          id = positional_arg(1) || abort("Usage: shapeup pitches detach <id>")

          result = call_tool("detach_package", package: id.to_s)

          render result,
            summary: "Pitch ##{id} detached from its predecessor",
            breadcrumbs: [
              { cmd: "shapeup pitch #{id}", description: "View pitch details" }
            ]
        end

        def delete
          yes = assume_yes?
          id = positional_arg(1) || abort("Usage: shapeup pitches delete <id> [--yes]")
          confirm_destructive!("Delete pitch ##{id}", yes)

          result = call_tool("delete_package", package: id.to_s)

          render result,
            summary: "Pitch ##{id} deleted",
            breadcrumbs: [
              { cmd: "shapeup pitches list", description: "List remaining pitches" }
            ]
        end

        def help
          puts <<~HELP
            Usage: shapeup pitches <subcommand> [options]

            Subcommands:
              list              List pitches (default)
              show <id>         Show pitch details
              create "Title"    Create a new pitch
              help              This help

            Filters (list):
              --status <s>      Filter by status: idea, framed, shaped
              --cycle <id>      Filter by cycle
              --limit <n>       Limit results

            Options (create):
              --stream <name>   Stream name or ID (required)
              --appetite <a>    unknown, small_batch, big_batch (default: big_batch)
              --cycle-id <id>   Assign to a cycle

            Output:
              --json            JSON envelope with breadcrumbs
              --md              Markdown table
              --agent           Raw data only

            Examples:
              shapeup pitches list
              shapeup pitches list --status shaped
              shapeup pitch 42
              shapeup pitches create "Redesign Search" --stream "Platform"
              shapeup pitches create "Auth Overhaul" --stream "Platform" --appetite small_batch
          HELP
        end
    end
  end
end
