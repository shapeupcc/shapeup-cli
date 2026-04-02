# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Comments < Base
      def self.metadata
        {
          command: "comments",
          path: "shapeup comments",
          short: "List and add comments on issues, pitches, scopes, and tasks",
          subcommands: [
            { name: "list", short: "List comments", path: "shapeup comments list --issue <id>" },
            { name: "add", short: "Add a comment", path: 'shapeup comments add --issue <id> "Comment text"' }
          ],
          flags: [
            { name: "issue", type: "string", usage: "Issue ID" },
            { name: "pitch", type: "string", usage: "Pitch ID" },
            { name: "scope", type: "string", usage: "Scope ID" },
            { name: "task", type: "string", usage: "Task ID" }
          ],
          examples: [
            "shapeup comments list --issue 42",
            'shapeup comments add --issue 42 "Investigated — this is a CSS issue in the navbar"',
            "shapeup comments list --pitch 10",
            'shapeup comments add --pitch 10 "Shaped and ready for betting"'
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "add"    then add
        when "list", nil then list
        else list
        end
      end

      private

        def list
          type, id = resolve_commentable
          result = call_tool("list_comments", commentable_type: type, commentable_id: id.to_s)

          render result,
            summary: "Comments on #{type} ##{id}",
            breadcrumbs: [
              { cmd: "shapeup comments add --#{type.downcase} #{id} \"Your comment\"", description: "Add a comment" }
            ]
        end

        def add
          type, id = resolve_commentable
          text = positional_arg(1) || abort('Usage: shapeup comments add --issue <id> "Comment text"')

          result = call_tool("create_comment", commentable_type: type, commentable_id: id.to_s, content: text)

          render result,
            summary: "Comment added to #{type} ##{id}",
            breadcrumbs: [
              { cmd: "shapeup comments list --#{type.downcase} #{id}", description: "View all comments" }
            ]
        end

        def resolve_commentable
          issue = extract_option("--issue")
          pitch = extract_option("--pitch")
          scope = extract_option("--scope")
          task = extract_option("--task")

          if issue
            [ "Issue", issue ]
          elsif pitch
            [ "Package", pitch ]
          elsif scope
            [ "Scope", scope ]
          elsif task
            [ "Task", task ]
          else
            abort("Specify a target: --issue <id>, --pitch <id>, --scope <id>, or --task <id>")
          end
        end
    end
  end
end
