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
            { name: "add", short: "Add a comment", path: 'shapeup comments add --issue <id> "Comment text"' },
            { name: "edit", short: "Edit your own comment", path: 'shapeup comments edit <comment_id> "New text"' },
            { name: "remove", short: "Delete your own comment", path: "shapeup comments remove <comment_id>" },
            { name: "react", short: "React to a comment with an emoji", path: "shapeup comments react <comment_id> <emoji>" }
          ],
          flags: [
            { name: "issue", type: "string", usage: "Issue ID" },
            { name: "pitch", type: "string", usage: "Pitch ID" },
            { name: "scope", type: "string", usage: "Scope ID" },
            { name: "task", type: "string", usage: "Task ID" },
            { name: "parent", type: "string", usage: "Comment ID to reply under" }
          ],
          examples: [
            "shapeup comments list --issue 42",
            'shapeup comments add --issue 42 "Investigated — this is a CSS issue in the navbar"',
            "shapeup comments list --pitch 10",
            'shapeup comments add --pitch 10 "Shaped and ready for betting"',
            'shapeup comments edit 88 "Updated: this is a navbar z-index issue"',
            "shapeup comments remove 88"
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "add"    then add
        when "edit"   then edit
        when "remove" then remove
        when "react"  then react
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
          parent = extract_option("--parent")
          text = positional_arg(1) || abort('Usage: shapeup comments add --issue <id> [--parent <comment_id>] "Comment text"')

          arguments = { commentable_type: type, commentable_id: id.to_s, content: text }
          arguments[:parent_id] = parent.to_s if parent
          result = call_tool("create_comment", **arguments)

          render result,
            summary: "Comment added to #{type} ##{id}",
            breadcrumbs: [
              { cmd: "shapeup comments list --#{type.downcase} #{id}", description: "View all comments" }
            ]
        end

        def edit
          comment_id = positional_arg(1) || abort('Usage: shapeup comments edit <comment_id> "New text"')
          text = positional_arg(2) || abort('Usage: shapeup comments edit <comment_id> "New text"')

          result = call_tool("update_comment", comment_id: comment_id.to_s, content: text)

          render result, summary: "Comment ##{comment_id} updated"
        end

        def remove
          yes = assume_yes?
          comment_id = positional_arg(1) || abort("Usage: shapeup comments remove <comment_id> [--yes]")
          confirm_destructive!("Delete comment ##{comment_id}", yes)

          result = call_tool("delete_comment", comment_id: comment_id.to_s)

          render result, summary: "Comment ##{comment_id} deleted"
        end

        def react
          comment_id = positional_arg(1) || abort("Usage: shapeup comments react <comment_id> <emoji>")
          emoji = positional_arg(2) || abort("Usage: shapeup comments react <comment_id> <emoji>")

          result = call_tool("add_reaction", comment_id: comment_id.to_s, emoji: emoji)

          render result, summary: "Reacted #{emoji} to comment ##{comment_id}"
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
