# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Tasks < Base
      def self.metadata
        {
          command: "tasks",
          path: "shapeup tasks",
          short: "Manage tasks within scopes and pitches",
          aliases: { "todo" => "tasks create", "done" => "tasks complete" },
          subcommands: [
            { name: "list", short: "List tasks", path: "shapeup tasks list" },
            { name: "create", short: "Create a task", path: "shapeup todo \"Description\" --pitch <id>" },
            { name: "complete", short: "Mark task(s) as complete", path: "shapeup done <id> [<id>...]" }
          ],
          flags: [
            { name: "pitch", type: "string", usage: "Pitch ID (required for create)" },
            { name: "scope", type: "string", usage: "Scope ID (optional filter or target)" },
            { name: "assignee", type: "string", usage: "User ID or 'me' (for list)" }
          ],
          examples: [
            "shapeup tasks list --pitch 42",
            "shapeup tasks list --assignee me",
            "shapeup todo \"Fix login bug\" --pitch 42 --scope 7",
            "shapeup done 123",
            "shapeup done 123 124 125"
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "create"   then create
        when "complete" then complete
        when "list", nil then list
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
                { cmd: "shapeup me", description: "Show remaining work" }
              ]
          end
        end
    end
  end
end
