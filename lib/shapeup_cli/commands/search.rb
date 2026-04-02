# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Search < Base
      def self.metadata
        {
          command: "search",
          path: "shapeup search",
          short: "Search across pitches, scopes, tasks, tickets, and users",
          flags: [],
          examples: [
            "shapeup search \"onboarding\"",
            "shapeup search \"login bug\" --json"
          ]
        }
      end

      def execute
        query = positional_arg(0) || abort("Usage: shapeup search \"query\"")

        result = call_tool("search", query: query)

        render result,
          summary: "Search: #{query}",
          breadcrumbs: [
            { cmd: "shapeup pitch <id>", description: "View a pitch" },
            { cmd: "shapeup cycle show <id>", description: "View a cycle" }
          ]
      end
    end
  end
end
