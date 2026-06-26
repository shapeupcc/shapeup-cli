# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Tasks < Base
      def self.metadata
        {
          command: "tasks",
          path: "shapeup tasks",
          short: "Manage tasks within scopes and pitches",
          aliases: { "todo" => "tasks create", "done" => "tasks complete", "undone" => "tasks uncomplete" },
          subcommands: [
            { name: "list", short: "List tasks", path: "shapeup tasks list" },
            { name: "create", short: "Create a task", path: "shapeup todo \"Description\" --pitch <id>" },
            { name: "complete", short: "Mark task(s) as complete", path: "shapeup done <id> [<id>...]" },
            { name: "uncomplete", short: "Mark task as incomplete", path: "shapeup undone <id>" },
            { name: "update", short: "Edit a task's description or move it to a scope", path: "shapeup tasks update <id> --description \"New\"" },
            { name: "delete", short: "Delete a task", path: "shapeup tasks delete <id>" }
          ],
          flags: [
            { name: "pitch", type: "string", usage: "Pitch ID (required for create)" },
            { name: "scope", type: "string", usage: "Scope ID (filter, create target, or update target; use 'none' to unmap)" },
            { name: "assignee", type: "string", usage: "User ID or 'me' (for list)" },
            { name: "description", type: "string", usage: "New description (for update)" }
          ],
          examples: [
            "shapeup tasks list --pitch 42",
            "shapeup tasks list --assignee me",
            "shapeup todo \"Fix login bug\" --pitch 42 --scope 7",
            "shapeup done 123",
            "shapeup done 123 124 125",
            "shapeup undone 123",
            "shapeup tasks update 123 --description \"Fix login + signup bug\"",
            "shapeup tasks update 123 --scope 7",
            "shapeup tasks update 123 --scope none",
            "shapeup tasks delete 123"
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "create"     then create
        when "complete"   then complete
        when "uncomplete" then uncomplete
        when "update"     then update
        when "delete"     then delete
        when "list", nil  then list
        else list
        end
      end

      private
        def list
          scope_id = extract_option("--scope")
          pitch_id = extract_option("--pitch")
          assignee = extract_option("--assignee")

          args = {}
          args[:scope] = scope_id if scope_id
          args[:package] = pitch_id if pitch_id
          args[:assignee] = assignee if assignee

          result = call_tool("list_tasks", **args)

          render result,
            summary: "Tasks",
            breadcrumbs: [
              { cmd: "shapeup todo \"Description\" --pitch <id>", description: "Create a task" },
              { cmd: "shapeup done <id>", description: "Complete a task" }
            ]
        end

        def create
          pitch_id = extract_option("--pitch") || abort("Usage: shapeup todo \"Description\" --pitch <id> [--scope <id>]")
          scope_id = extract_option("--scope")
          description = positional_arg(1) || abort("Usage: shapeup todo \"Description\" --pitch <id>")

          args = { package: pitch_id.to_s, description: description }
          args[:scope] = scope_id if scope_id

          result = call_tool("create_task", **args)

          render result,
            summary: "Task created",
            breadcrumbs: [
              { cmd: "shapeup done <id>", description: "Mark as complete" },
              { cmd: "shapeup tasks list --pitch #{pitch_id}", description: "List all tasks" }
            ]
        end

        def complete
          ids = positional_args.drop(1) # drop "complete" subcommand
          ids = positional_args if ids.empty? # handle shortcut: shapeup done <id>

          abort("Usage: shapeup done <id> [<id>...]") if ids.empty?

          ids.each do |id|
            result = call_tool("complete_task", task: id.to_s)

            render result,
              summary: "Task ##{id} completed",
              breadcrumbs: [
                { cmd: "shapeup undone #{id}", description: "Mark incomplete again" },
                { cmd: "shapeup me", description: "Show remaining work" }
              ]
          end
        end

        def uncomplete
          id = positional_arg(1) || abort("Usage: shapeup undone <id>")

          result = call_tool("uncomplete_task", task: id.to_s)

          render result,
            summary: "Task ##{id} marked incomplete",
            breadcrumbs: [
              { cmd: "shapeup done #{id}", description: "Complete it again" }
            ]
        end

        def update
          id = positional_arg(1) || abort("Usage: shapeup tasks update <id> [--description \"New\"] [--scope <id>|none]")
          description = extract_option("--description")
          scope = extract_option("--scope")
          abort("Nothing to update. Pass --description \"...\" and/or --scope <id>|none") unless description || scope

          args = { task: id.to_s }
          args[:description] = description if description
          args[:scope] = scope if scope

          result = call_tool("update_task", **args)

          render result,
            summary: "Task ##{id} updated",
            breadcrumbs: [
              { cmd: "shapeup tasks list --pitch <id>", description: "List tasks" }
            ]
        end

        def delete
          yes = assume_yes?
          id = positional_arg(1) || abort("Usage: shapeup tasks delete <id> [--yes]")
          confirm_destructive!("Delete task ##{id}", yes)

          result = call_tool("delete_task", task: id.to_s)

          render result,
            summary: "Task ##{id} deleted",
            breadcrumbs: [
              { cmd: "shapeup tasks list --pitch <id>", description: "List remaining tasks" }
            ]
        end
    end
  end
end
