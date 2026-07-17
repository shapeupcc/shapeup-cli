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
            { name: "show", short: "Show stream details with pitches and issue counts", path: "shapeup streams show <id>" },
            { name: "create", short: "Create a stream", path: "shapeup streams create \"Title\"" },
            { name: "edit", short: "Update a stream's title, description, or color", path: "shapeup streams edit <id> --title \"New\"" }
          ],
          flags: [
            { name: "all", type: "bool", usage: "Include archived streams (for list)" },
            { name: "title", type: "string", usage: "Stream title (create/edit)" },
            { name: "description", type: "string", usage: "Stream description (create/edit)" },
            { name: "color", type: "string", usage: "Hex color code (edit)" }
          ],
          examples: [
            "shapeup streams",
            "shapeup streams --all --json",
            "shapeup streams show 3",
            "shapeup streams create \"Platform\"",
            "shapeup streams edit 3 --title \"Platform & Infra\" --color \"#3b82f6\""
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "show"      then show
        when "create"    then create
        when "edit"      then edit
        when "list", nil then list
        else
          subcommand.match?(/\A\d+\z/) ? show(subcommand) : list
        end
      end

      private
        def create
          title = positional_arg(1) || abort("Usage: shapeup streams create \"Title\" [--description \"..\"]")
          args = { title: title }
          args[:description] = extract_option("--description") if @remaining.include?("--description")

          result = call_tool("create_stream", **args)

          render result,
            summary: "Stream created",
            breadcrumbs: [ { cmd: "shapeup streams edit <id> --color \"#3b82f6\"", description: "Set its colour" } ]
        end

        def edit
          id = positional_arg(1) || abort("Usage: shapeup streams edit <id> [--title ..] [--description ..] [--color ..]")
          args = { stream: id.to_s }
          args[:title] = extract_option("--title") if @remaining.include?("--title")
          args[:description] = extract_option("--description") if @remaining.include?("--description")
          args[:color] = extract_option("--color") if @remaining.include?("--color")

          result = call_tool("update_stream", **args)

          render result, summary: "Stream ##{id} updated"
        end

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
