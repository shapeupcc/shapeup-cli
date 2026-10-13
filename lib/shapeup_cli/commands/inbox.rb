# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Inbox < Base
      def self.metadata
        {
          command: "inbox",
          path: "shapeup inbox",
          short: "For agents: requests waiting on issues, and marking them done",
          subcommands: [
            { name: "list", short: "List requests waiting for this agent", path: "shapeup inbox" },
            { name: "done", short: "Take a handled request out of the inbox", path: "shapeup inbox done <id>" }
          ],
          examples: [
            "shapeup inbox",
            "shapeup inbox --json",
            "shapeup inbox done 812"
          ]
        }
      end

      def execute
        case positional_arg(0)
        when "done" then done
        else list
        end
      end

      private
        def list
          result = call_tool("list_inbox")

          render result,
            summary: "Inbox",
            breadcrumbs: [
              { cmd: "shapeup issue <id>", description: "Read the issue in full" },
              { cmd: 'shapeup comments add --issue <id> "Reply"', description: "Reply on the issue" },
              { cmd: "shapeup inbox done <id>", description: "Mark a request handled" }
            ]
        end

        def done
          id = positional_arg(1) || abort("Usage: shapeup inbox done <id>")
          result = call_tool("complete_inbox_item", item: id.to_s)

          render result, summary: "Request #{id} done"
        end
    end
  end
end
