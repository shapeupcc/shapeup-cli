# frozen_string_literal: true

module ShapeupCli
  module Commands
    def self.help
      puts <<~HELP
        ShapeUp CLI — Manage pitches, scopes, tasks, and cycles from the terminal.

        Usage: shapeup <command> [options]

        Auth:
          login                     Authenticate via OAuth (creates a profile)
          logout                    Clear all credentials
          auth status               Check authentication status
          auth list                 List configured profiles
          auth switch <name>        Switch active profile
          auth remove <name>        Remove a profile

        Discovery:
          orgs                      List your organisations
          commands                  List all available commands

        Pitches:
          pitches list              List pitches (packages)
          pitches show <id>         Show pitch details with scopes and tasks
          pitch <id>                Shortcut for pitches show

        Cycles:
          cycles                    List all cycles
          cycle show <id>           Show cycle details with pitches and progress

        Scopes:
          scopes list --pitch <id>  List scopes for a pitch
          scopes create --pitch <id> "Title"
          scopes update <id> --title "New title"

        Tasks:
          tasks list --scope <id>   List tasks for a scope
          todo "Description" --pitch <id> [--scope <id>]
          done <id> [<id>...]       Mark task(s) as complete

        Issues:
          issues                    List open issues
          issues --all              Include done/closed
          issues --column triage    Filter by column name
          issues --assignee me      Issues assigned to me
          issues --assignee none    Unassigned issues
          issues --tag seo          Filter by tag
          issues --stream "Name"    Filter by stream name
          issues --kind bug         Filter by kind (bug/request)
          issue <id>                Show issue details
          issues create "Title" --stream "Name" [--content "..."]
          issues move <id> --column doing
          issues done <id>          Mark issue as done
          issues close <id>         Close issue (won't fix)
          issues reopen <id>        Reopen a done/closed issue
          issues icebox <id>        Move to icebox
          issues defrost <id>       Restore from icebox
          issues assign <id>        Assign yourself (or --user <id>)
          issues unassign <id>      Unassign yourself (or --user <id>)
          issues watch <id>         Watch an issue
          issues unwatch <id>       Stop watching
          watching                  List issues you are watching
          issues delete <id>        Delete an issue

        Comments:
          comments list --issue <id>           List comments on an issue
          comments list --pitch <id>           List comments on a pitch
          comments add --issue <id> "Text"     Add a comment to an issue
          comments add --pitch <id> "Text"     Add a comment to a pitch

        My Work:
          my-work, me               Show everything assigned to me

        Search:
          search "query"            Search across pitches, scopes, tasks, issues

        Config:
          config show               Show current config
          config set org "Name"     Set default organisation (name or ID)
          config set host <url>     Set ShapeUp host
          config init "Name"        Create .shapeup/config.json for this directory

        Setup:
          setup claude              Install skill into Claude Code
          setup cursor              Install skill into Cursor
          setup project             Install skill into current project

        Output modes (append to any command):
          --json                    Full JSON envelope with breadcrumbs
          --md                      Markdown tables
          --agent                   Raw JSON data only (for AI agents)
          --quiet, -q               Same as --agent
          --ids-only                Print only IDs (one per line)
          (piped output auto-switches to --json)

        Flags:
          --org <id|name>           Override default organisation
          --host <url>              Override ShapeUp host (default: https://shapeup.cc)

        Environment variables:
          SHAPEUP_TOKEN             Bearer token (skips OAuth, for CI/scripts)
          SHAPEUP_ORG               Default organisation ID
          SHAPEUP_HOST              API host URL

        Examples:
          shapeup login
          shapeup config set org "Compass Labs"
          shapeup pitches list --json
          shapeup pitch 42
          shapeup todo "Fix login bug" --pitch 42 --scope 7
          shapeup done 123 124 125
          shapeup me --md
      HELP
    end

    def self.list_commands
      puts <<~COMMANDS
        login          Authenticate (creates a profile)
        logout         Clear all credentials
        auth           Manage profiles (status, list, switch, remove)
        orgs           List organisations
        pitches        List/show pitches (list, show)
        pitch          Show a pitch (shortcut)
        cycles         List cycles
        cycle          Show cycle details (list, show)
        scopes         Manage scopes (list, create, update)
        tasks          Manage tasks (list, create, complete)
        todo           Create a task (shortcut)
        done           Complete task(s) (shortcut)
        issues         Manage issues (list, show, create, move, icebox, watch)
        issue          Show an issue (shortcut)
        watching       List watched issues (shortcut)
        comments       List and add comments (list, add)
        my-work / me   Show my assigned work
        search         Search everything
        config         Show/set config (set, show, init)
        setup          Install agent skills (claude, cursor, project)
        commands       This list
        help           Usage guide
        version        Show version
      COMMANDS
    end
  end
end

require_relative "commands/base"
require_relative "commands/login"
require_relative "commands/logout"
require_relative "commands/orgs"
require_relative "commands/pitches"
require_relative "commands/cycle"
require_relative "commands/scopes"
require_relative "commands/tasks"
require_relative "commands/issues"
require_relative "commands/my_work"
require_relative "commands/search"
require_relative "commands/auth"
require_relative "commands/config_cmd"
require_relative "commands/setup"
require_relative "commands/comments"
