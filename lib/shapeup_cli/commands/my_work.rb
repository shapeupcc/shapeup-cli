# frozen_string_literal: true

module ShapeupCli
  module Commands
    class MyWork < Base
      def self.metadata
        {
          command: "my-work",
          path: "shapeup me",
          short: "Show all pitches, scopes, and tasks assigned to you",
          aliases: { "me" => "my-work" },
          flags: [
            { name: "user", type: "string", usage: "User ID to show work for (default: me)" }
          ],
          examples: [
            "shapeup me",
            "shapeup me --json",
            "shapeup my-work --user 5"
          ]
        }
      end

      def execute
        assignee = extract_option("--user") || "me"

        result = call_tool("show_my_work", assignee: assignee)

        render result,
          summary: assignee == "me" ? "My Work" : "Work for #{assignee}",
          breadcrumbs: [
            { cmd: "shapeup pitch <id>", description: "View pitch details" },
            { cmd: "shapeup done <id>", description: "Complete a task" },
            { cmd: "shapeup tasks list --assignee me", description: "List just my tasks" }
          ]
      end
    end
  end
end
