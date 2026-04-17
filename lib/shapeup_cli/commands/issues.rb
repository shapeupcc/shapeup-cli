# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Issues < Base
      def self.metadata
        {
          command: "issues",
          path: "shapeup issues",
          short: "Manage issues on the kanban board",
          aliases: { "issue" => "issues show", "watching" => "issues watching" },
          subcommands: [
            { name: "list", short: "List active issues", path: "shapeup issues" },
            { name: "show", short: "Show issue details", path: "shapeup issue <id>" },
            { name: "create", short: "Create an issue", path: "shapeup issues create \"Title\" --stream <id>" },
            { name: "update", short: "Update an issue", path: "shapeup issues update <id> --title \"New title\"" },
            { name: "move", short: "Move to a kanban column", path: "shapeup issues move <id> --column <id>" },
            { name: "done", short: "Mark issue as done", path: "shapeup issues done <id>" },
            { name: "close", short: "Close issue (won't fix)", path: "shapeup issues close <id>" },
            { name: "reopen", short: "Reopen a done/closed issue", path: "shapeup issues reopen <id>" },
            { name: "icebox", short: "Move issue to icebox", path: "shapeup issues icebox <id>" },
            { name: "defrost", short: "Restore issue from icebox", path: "shapeup issues defrost <id>" },
            { name: "assign", short: "Assign a user to an issue", path: "shapeup issues assign <id> [--user <id>]" },
            { name: "unassign", short: "Unassign a user from an issue", path: "shapeup issues unassign <id> [--user <id>]" },
            { name: "watch", short: "Watch an issue", path: "shapeup issues watch <id>" },
            { name: "unwatch", short: "Stop watching an issue", path: "shapeup issues unwatch <id>" },
            { name: "watching", short: "List issues you are watching", path: "shapeup watching" },
            { name: "delete", short: "Delete an issue", path: "shapeup issues delete <id>" }
          ],
          flags: [
            { name: "stream", type: "string", usage: "Stream ID (required for create, optional filter for list)" },
            { name: "column", type: "string", usage: "Kanban column ID (for move or filter)" },
            { name: "kind", type: "string", usage: "Filter by kind: bug, request, all" },
            { name: "assignee", type: "string", usage: "User ID or 'me' (for list)" },
            { name: "user", type: "string", usage: "User ID or 'me' (for assign/unassign, defaults to 'me')" },
            { name: "tag", type: "string", usage: "Filter by tag name (for list)" },
            { name: "all", type: "bool", usage: "Include done/closed issues (hidden by default)" },
            { name: "content", type: "string", usage: "Issue content/description" },
            { name: "title", type: "string", usage: "Issue title (for update)" },
            { name: "archived", type: "bool", usage: "Include iceboxed issues in list" },
            { name: "no-comments", type: "bool", usage: "Hide embedded comments on show (default: show)" },
            { name: "comments-limit", type: "integer", usage: "Max comments to embed on show (default: 10, max: 50)" }
          ],
          examples: [
            "shapeup issues",
            "shapeup issues --tag seo",
            "shapeup issues --assignee me",
            "shapeup issues --column 3",
            "shapeup issues --all",
            "shapeup issues --stream 3 --kind bug",
            "shapeup issue 42",
            "shapeup issues create \"Fix checkout\" --stream 3 --content \"The button is broken\"",
            "shapeup issues move 42 --column 5",
            "shapeup issues done 42",
            "shapeup issues close 42",
            "shapeup issues reopen 42",
            "shapeup issues icebox 42",
            "shapeup issues defrost 42",
            "shapeup issues assign 42",
            "shapeup issues assign 42 --user 7",
            "shapeup issues unassign 42",
            "shapeup issues watch 42",
            "shapeup watching"
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "show"     then show
        when "create"   then create
        when "update"   then update
        when "move"     then move
        when "done"     then mark_done
        when "close"    then close
        when "reopen"   then reopen
        when "icebox"   then icebox
        when "defrost"  then defrost
        when "assign"   then assign
        when "unassign" then unassign
        when "watch"    then watch
        when "unwatch"  then unwatch
        when "watching" then watching
        when "delete"   then delete
        when "list", nil then list
        else
          # Bare numeric arg = show
          if subcommand&.match?(/\A\d+\z/)
            @remaining.unshift(subcommand)
            show
          else
            list
          end
        end
      end

      private

        def list
          stream = extract_option("--stream")
          column = extract_option("--column")
          kind = extract_option("--kind")
          assignee = extract_option("--assignee")
          tag = extract_option("--tag")
          show_all = @remaining.delete("--all")

          args = {}
          args[:stream] = stream if stream
          args[:kanban_column] = column if column
          args[:kind] = kind if kind
          args[:assignee] = assignee if assignee
          args[:tag] = tag if tag
          args[:include_closed] = true if show_all
          args[:include_archived] = true if @remaining.delete("--archived")

          result = call_tool("list_issues", **args)

          render result,
            summary: "Issues",
            breadcrumbs: [
              { cmd: "shapeup issue <id>", description: "View issue details" },
              { cmd: "shapeup issues create \"Title\" --stream <id>", description: "Create an issue" }
            ]
        end

        def show
          id = positional_arg(1) || positional_arg(0) || abort("Usage: shapeup issue <id>")
          result = call_tool("show_issue", issue: id.to_s, **comment_flags)

          render result,
            summary: "Issue ##{id}",
            breadcrumbs: [
              { cmd: "shapeup issues move #{id} --column <id>", description: "Move to column" },
              { cmd: "shapeup issues icebox #{id}", description: "Move to icebox" },
              { cmd: "shapeup issues watch #{id}", description: "Watch this issue" },
              { cmd: "shapeup issue #{id} --no-comments", description: "Hide embedded comments" }
            ]
        end

        def create
          stream_id = extract_option("--stream") || abort("Usage: shapeup issues create \"Title\" --stream <id> [--content \"...\"] [--kind bug|request]")
          content = extract_option("--content")
          kind = extract_option("--kind")
          column = extract_option("--column")
          title = positional_arg(1) || abort("Usage: shapeup issues create \"Title\" --stream <id>")

          args = { stream: stream_id.to_s, title: title, content: content || title }
          args[:kind] = kind if kind
          args[:kanban_column] = column if column

          result = call_tool("create_issue", **args)

          render result,
            summary: "Issue created",
            breadcrumbs: [
              { cmd: "shapeup issues", description: "List all issues" },
              { cmd: "shapeup issue <id>", description: "View the issue" }
            ]
        end

        def update
          id = positional_arg(1) || abort("Usage: shapeup issues update <id> [--title \"...\"] [--content \"...\"] [--kind bug|request]")
          title = extract_option("--title")
          content = extract_option("--content")
          kind = extract_option("--kind")

          args = { issue: id.to_s }
          args[:title] = title if title
          args[:content] = content if content
          args[:kind] = kind if kind

          result = call_tool("update_issue", **args)

          render result,
            summary: "Issue ##{id} updated",
            breadcrumbs: [
              { cmd: "shapeup issue #{id}", description: "View issue" }
            ]
        end

        def move
          id = positional_arg(1) || abort("Usage: shapeup issues move <id> --column <id>")
          column_id = extract_option("--column") || abort("Usage: shapeup issues move <id> --column <id>")

          result = call_tool("move_issue", issue: id.to_s, kanban_column: column_id.to_s)

          render result,
            summary: "Issue ##{id} moved",
            breadcrumbs: [
              { cmd: "shapeup issue #{id}", description: "View issue" },
              { cmd: "shapeup issues", description: "List all issues" }
            ]
        end

        def icebox
          id = positional_arg(1) || abort("Usage: shapeup issues icebox <id>")

          result = call_tool("archive_issue", issue: id.to_s)

          render result,
            summary: "Issue ##{id} iceboxed",
            breadcrumbs: [
              { cmd: "shapeup issues defrost #{id}", description: "Defrost this issue" },
              { cmd: "shapeup issues --archived", description: "List iceboxed issues" }
            ]
        end

        def mark_done
          id = positional_arg(1) || abort("Usage: shapeup issues done <id>")

          result = call_tool("close_issue", issue: id.to_s, resolution: "done")

          render result,
            summary: "Issue ##{id} done",
            breadcrumbs: [
              { cmd: "shapeup issues reopen #{id}", description: "Reopen this issue" },
              { cmd: "shapeup issues", description: "List open issues" }
            ]
        end

        def close
          id = positional_arg(1) || abort("Usage: shapeup issues close <id>")

          result = call_tool("close_issue", issue: id.to_s, resolution: "closed")

          render result,
            summary: "Issue ##{id} closed",
            breadcrumbs: [
              { cmd: "shapeup issues reopen #{id}", description: "Reopen this issue" },
              { cmd: "shapeup issues", description: "List open issues" }
            ]
        end

        def reopen
          id = positional_arg(1) || abort("Usage: shapeup issues reopen <id>")

          result = call_tool("reopen_issue", issue: id.to_s)

          render result,
            summary: "Issue ##{id} reopened",
            breadcrumbs: [
              { cmd: "shapeup issue #{id}", description: "View issue" },
              { cmd: "shapeup issues", description: "List all issues" }
            ]
        end

        def defrost
          id = positional_arg(1) || abort("Usage: shapeup issues defrost <id>")

          result = call_tool("unarchive_issue", issue: id.to_s)

          render result,
            summary: "Issue ##{id} defrosted",
            breadcrumbs: [
              { cmd: "shapeup issue #{id}", description: "View issue" },
              { cmd: "shapeup issues", description: "List all issues" }
            ]
        end

        def assign
          id = positional_arg(1) || abort("Usage: shapeup issues assign <id> [--user <id>]")
          user_id = extract_option("--user") || "me"

          result = call_tool("assign_user", assignable_type: "Issue", assignable_id: id.to_s, user_id: user_id.to_s)

          render result,
            summary: "Assigned to issue ##{id}",
            breadcrumbs: [
              { cmd: "shapeup issues unassign #{id}", description: "Unassign from issue" },
              { cmd: "shapeup issue #{id}", description: "View issue" }
            ]
        end

        def unassign
          id = positional_arg(1) || abort("Usage: shapeup issues unassign <id> [--user <id>]")
          user_id = extract_option("--user") || "me"

          result = call_tool("unassign_user", assignable_type: "Issue", assignable_id: id.to_s, user_id: user_id.to_s)

          render result,
            summary: "Unassigned from issue ##{id}",
            breadcrumbs: [
              { cmd: "shapeup issues assign #{id}", description: "Assign to issue" },
              { cmd: "shapeup issue #{id}", description: "View issue" }
            ]
        end

        def watch
          id = positional_arg(1) || abort("Usage: shapeup issues watch <id>")

          result = call_tool("watch_issue", issue: id.to_s)

          render result,
            summary: "Watching issue ##{id}",
            breadcrumbs: [
              { cmd: "shapeup watching", description: "List watched issues" },
              { cmd: "shapeup issues unwatch #{id}", description: "Stop watching" }
            ]
        end

        def unwatch
          id = positional_arg(1) || abort("Usage: shapeup issues unwatch <id>")

          result = call_tool("unwatch_issue", issue: id.to_s)

          render result,
            summary: "Unwatched issue ##{id}",
            breadcrumbs: [
              { cmd: "shapeup watching", description: "List watched issues" }
            ]
        end

        def watching
          result = call_tool("list_watched_issues")

          render result,
            summary: "Watched Issues",
            breadcrumbs: [
              { cmd: "shapeup issue <id>", description: "View issue details" },
              { cmd: "shapeup issues unwatch <id>", description: "Stop watching" }
            ]
        end

        def delete
          id = positional_arg(1) || abort("Usage: shapeup issues delete <id>")

          result = call_tool("delete_issue", issue: id.to_s)

          render result,
            summary: "Issue ##{id} deleted",
            breadcrumbs: [
              { cmd: "shapeup issues", description: "List remaining issues" }
            ]
        end
    end
  end
end
