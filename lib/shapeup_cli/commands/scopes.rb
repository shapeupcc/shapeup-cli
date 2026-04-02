# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Scopes < Base
      def self.metadata
        {
          command: "scopes",
          path: "shapeup scopes",
          short: "Manage scopes within a pitch",
          subcommands: [
            { name: "list", short: "List scopes for a pitch", path: "shapeup scopes list --pitch <id>" },
            { name: "create", short: "Create a new scope", path: "shapeup scopes create --pitch <id> \"Title\"" },
            { name: "update", short: "Update scope title or color", path: "shapeup scopes update <id> --title \"New\"" }
          ],
          flags: [
            { name: "pitch", type: "string", usage: "Pitch ID (required for list and create)" },
            { name: "title", type: "string", usage: "Scope title (for create/update)" },
            { name: "color", type: "string", usage: "Hex color code (for update)" }
          ],
          examples: [
            "shapeup scopes list --pitch 42",
            "shapeup scopes create --pitch 42 \"User onboarding\"",
            "shapeup scopes update 7 --title \"Revised onboarding\""
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "create" then create
        when "update" then update
        when "list", nil then list
        else list
        end
      end

      private
        def list
          pitch_id = extract_option("--pitch") || abort("Usage: shapeup scopes list --pitch <id>")

          result = call_tool("show_package", package: pitch_id.to_s)

          render result,
            summary: "Scopes for Pitch ##{pitch_id}",
            breadcrumbs: [
              { cmd: "shapeup scopes create --pitch #{pitch_id} \"Title\"", description: "Add a scope" },
              { cmd: "shapeup tasks list --pitch #{pitch_id}", description: "List all tasks" }
            ]
        end

        def create
          pitch_id = extract_option("--pitch") || abort("Usage: shapeup scopes create --pitch <id> \"Title\"")
          title = positional_arg(1) || abort("Usage: shapeup scopes create --pitch <id> \"Title\"")

          result = call_tool("create_scope", package: pitch_id.to_s, title: title)

          render result,
            summary: "Scope created",
            breadcrumbs: [
              { cmd: "shapeup tasks list --scope <id>", description: "List tasks in this scope" },
              { cmd: "shapeup todo \"Task\" --pitch #{pitch_id} --scope <id>", description: "Add a task" }
            ]
        end

        def update
          scope_id = positional_arg(1) || abort("Usage: shapeup scopes update <id> [--title \"New\"] [--color #hex]")
          args = { scope: scope_id.to_s }
          args[:title] = extract_option("--title") if @remaining.include?("--title")
          args[:color] = extract_option("--color") if @remaining.include?("--color")

          result = call_tool("update_scope", **args)

          render result, summary: "Scope ##{scope_id} updated"
        end
    end
  end
end
