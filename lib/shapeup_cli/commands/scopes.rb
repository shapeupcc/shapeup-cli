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
            { name: "show", short: "Show a scope with its tasks", path: "shapeup scopes show <id>" },
            { name: "create", short: "Create a new scope", path: "shapeup scopes create --pitch <id> \"Title\"" },
            { name: "update", short: "Update scope title or color", path: "shapeup scopes update <id> --title \"New\"" },
            { name: "position", short: "Update hill chart position (0-100)", path: "shapeup scopes position <id> <position>" },
            { name: "history", short: "Show hill chart trajectory", path: "shapeup scopes history <id>" },
            { name: "delete", short: "Delete a scope (must have no tasks or comments)", path: "shapeup scopes delete <id>" },
            { name: "assign", short: "Assign a user", path: "shapeup scopes assign <id> [--user <id>]" },
            { name: "unassign", short: "Unassign a user", path: "shapeup scopes unassign <id> [--user <id>]" }
          ],
          flags: [
            { name: "user", type: "string", usage: "User ID or 'me' (assign/unassign; defaults to me)" },
            { name: "pitch", type: "string", usage: "Pitch ID (required for list and create)" },
            { name: "title", type: "string", usage: "Scope title (for create/update)" },
            { name: "color", type: "string", usage: "Hex color code (for update)" }
          ],
          examples: [
            "shapeup scopes list --pitch 42",
            "shapeup scopes create --pitch 42 \"User onboarding\"",
            "shapeup scopes update 7 --title \"Revised onboarding\"",
            "shapeup scopes position 7 50",
            "shapeup scopes delete 7"
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "show"     then show
        when "create"   then create
        when "update"   then update
        when "position" then position
        when "history"  then history
        when "delete"   then delete
        when "assign"   then assign_to("Scope", "scopes")
        when "unassign" then unassign_from("Scope", "scopes")
        when "list", nil then list
        else list
        end
      end

      private
        def list
          pitch_id = extract_option("--pitch") || abort("Usage: shapeup scopes list --pitch <id>")

          result = call_tool("list_scopes", package: pitch_id.to_s)

          render result,
            summary: "Scopes for Pitch ##{pitch_id}",
            breadcrumbs: [
              { cmd: "shapeup scopes show <id>", description: "Show a scope with its tasks" },
              { cmd: "shapeup scopes create --pitch #{pitch_id} \"Title\"", description: "Add a scope" }
            ]
        end

        def show
          scope_id = positional_arg(1) || abort("Usage: shapeup scopes show <id>")

          result = call_tool("show_scope", scope: scope_id.to_s)

          render result,
            summary: "Scope ##{scope_id}",
            breadcrumbs: [
              { cmd: "shapeup scopes history #{scope_id}", description: "Hill chart trajectory" }
            ]
        end

        def history
          scope_id = positional_arg(1) || abort("Usage: shapeup scopes history <id>")

          result = call_tool("list_scope_history", scope: scope_id.to_s)

          render result,
            summary: "Scope ##{scope_id} history",
            breadcrumbs: [
              { cmd: "shapeup scopes position #{scope_id} <0-100>", description: "Update hill position" }
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

        def position
          scope_id = positional_arg(1) || abort("Usage: shapeup scopes position <id> <position>")
          pos = positional_arg(2) || abort("Usage: shapeup scopes position <id> <position>")

          result = call_tool("update_scope_position", scope: scope_id.to_s, position: pos.to_f)

          render result,
            summary: "Scope ##{scope_id} moved to position #{pos}",
            breadcrumbs: [
              { cmd: "shapeup scopes list --pitch <id>", description: "List scopes" }
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

        def delete
          yes = assume_yes?
          scope_id = positional_arg(1) || abort("Usage: shapeup scopes delete <id> [--yes]")
          confirm_destructive!("Delete scope ##{scope_id}", yes)

          result = call_tool("delete_scope", scope: scope_id.to_s)

          render result,
            summary: "Scope ##{scope_id} deleted",
            breadcrumbs: [
              { cmd: "shapeup scopes list --pitch <id>", description: "List remaining scopes" }
            ]
        end
    end
  end
end
