# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "fileutils"
require "securerandom"
require "digest"
require "base64"
require "socket"

require_relative "shapeup_cli/version"
require_relative "shapeup_cli/config"
require_relative "shapeup_cli/auth"
require_relative "shapeup_cli/client"
require_relative "shapeup_cli/output"
require_relative "shapeup_cli/commands"

module ShapeupCli
  DEFAULT_HOST = "https://shapeup.cc"

  # Exit codes, matching the rubric shared by the Basecamp-family CLIs so
  # agents that know one CLI can read all of them.
  EXIT_OK          = 0
  EXIT_USAGE       = 1
  EXIT_NOT_FOUND   = 2
  EXIT_AUTH        = 3
  EXIT_PERMISSION  = 4
  EXIT_RATE_LIMIT  = 5
  EXIT_NETWORK     = 6
  EXIT_API_ERROR   = 7
  EXIT_AMBIGUOUS   = 8
  EXIT_INTERRUPTED = 130

  COMMAND_MAP = {
    "orgs"      => Commands::Orgs,
    "pitches"   => Commands::Pitches,
    "cycle"     => Commands::Cycle,
    "streams"   => Commands::Streams,
    "scopes"    => Commands::Scopes,
    "tasks"     => Commands::Tasks,
    "issues"    => Commands::Issues,
    "my-work"   => Commands::MyWork,
    "search"    => Commands::Search,
    "auth"      => Commands::Auth,
    "config"    => Commands::ConfigCmd,
    "doctor"    => Commands::Doctor,
    "setup"     => Commands::Setup,
    "comments"  => Commands::Comments,
    "checklist" => Commands::Checklist,
    "tags"      => Commands::Tags
  }.freeze

  def self.run(argv)
    args = argv.dup
    @machine_output = args.intersect?(%w[ --json --agent --quiet -q ]) || !$stdout.tty?

    # Top-level: shapeup --agent --help
    if args.include?("--agent") && args.include?("--help")
      command = (args - [ "--agent", "--help" ]).first
      if command && COMMAND_MAP[command]
        puts JSON.pretty_generate(COMMAND_MAP[command].metadata)
      else
        puts JSON.pretty_generate(top_level_metadata)
      end
      return
    end

    command = args.shift

    case command
    when "login"          then Commands::Login.run(args)
    when "logout"         then Commands::Logout.run(args)
    when "auth"           then Commands::Auth.run(args)
    when "orgs"           then Commands::Orgs.run(args)
    when "pitches"        then Commands::Pitches.run(args)
    when "pitch"          then Commands::Pitches.run([ "show" ] + args)
    when "cycle"          then Commands::Cycle.run(args)
    when "cycles"         then Commands::Cycle.run([ "list" ] + args)
    when "streams"        then Commands::Streams.run(args)
    when "scopes"         then Commands::Scopes.run(args)
    when "tasks"          then Commands::Tasks.run(args)
    when "todo"           then Commands::Tasks.run([ "create" ] + args)
    when "done"           then Commands::Tasks.run([ "complete" ] + args)
    when "undone"         then Commands::Tasks.run([ "uncomplete" ] + args)
    when "issues"         then Commands::Issues.run(args)
    when "issue"          then Commands::Issues.run([ "show" ] + args)
    when "watching"       then Commands::Issues.run([ "watching" ] + args)
    when "comments"       then Commands::Comments.run(args)
    when "checklist"      then Commands::Checklist.run(args)
    when "tags"           then Commands::Tags.run(args)
    when "my-work", "me"  then Commands::MyWork.run(args)
    when "search"         then Commands::Search.run(args)
    when "config"         then Commands::ConfigCmd.run(args)
    when "doctor"         then Commands::Doctor.run(args)
    when "setup"          then Commands::Setup.run(args)
    when "commands"       then Commands.list_commands
    when "version", "-v", "--version"
      puts "shapeup #{VERSION}"
    when "help", "-h", "--help", nil
      Commands.help
    else
      $stderr.puts "Unknown command: #{command}"
      $stderr.puts "Run 'shapeup help' for usage"
      exit EXIT_USAGE
    end
  rescue Client::AuthError
    fail_with "Not authenticated.", code: "auth_required", exit_code: EXIT_AUTH,
      retryable: false, hint: "Run 'shapeup login' or set SHAPEUP_TOKEN"
  rescue Client::NotFoundError => e
    fail_with "Not found: #{e.message}", code: "not_found", exit_code: EXIT_NOT_FOUND, retryable: false
  rescue Client::PermissionError => e
    fail_with "Access denied: #{e.message}", code: "forbidden", exit_code: EXIT_PERMISSION, retryable: false
  rescue Client::RateLimitError
    fail_with "Rate limited.", code: "rate_limit", exit_code: EXIT_RATE_LIMIT,
      retryable: true, hint: "Wait a moment and retry"
  rescue Client::NetworkError => e
    fail_with e.message, code: "network", exit_code: EXIT_NETWORK,
      retryable: true, hint: "Check your connection and 'shapeup config show'"
  rescue Client::ApiError => e
    fail_with "Error: #{e.message}", code: "api_error", exit_code: EXIT_API_ERROR, retryable: false
  rescue Interrupt
    $stderr.puts "\nAborted."
    exit EXIT_INTERRUPTED
  end

  # Errors reach machine consumers as a JSON envelope on stdout with a
  # `retryable` verdict, and humans as plain text on stderr. `retryable: false`
  # means "no known reason a retry helps", not proof of permanence.
  def self.fail_with(message, code:, exit_code:, retryable:, hint: nil)
    if @machine_output
      envelope = { ok: false, error: message, code: code, retryable: retryable }
      envelope[:hint] = hint if hint
      puts JSON.generate(envelope)
    else
      $stderr.puts message
      $stderr.puts hint if hint
    end
    exit exit_code
  end

  def self.top_level_metadata
    {
      command: "shapeup",
      version: VERSION,
      short: "Manage ShapeUp pitches, scopes, tasks, issues, and cycles from the terminal",
      commands: COMMAND_MAP.map { |name, klass| { name: name, **klass.metadata.slice(:short, :path) } },
      shortcuts: {
        "pitch <id>" => "pitches show <id>",
        "cycles" => "cycle list",
        "todo \"...\"" => "tasks create \"...\"",
        "done <id>" => "tasks complete <id>",
        "undone <id>" => "tasks uncomplete <id>",
        "issue <id>" => "issues show <id>",
        "watching" => "issues watching",
        "me" => "my-work"
      },
      inherited_flags: [
        { name: "org", type: "string", usage: "Organisation ID or name" },
        { name: "json", type: "bool", usage: "Full JSON envelope with breadcrumbs" },
        { name: "md", type: "bool", usage: "Markdown output" },
        { name: "agent", type: "bool", usage: "Raw JSON data only (for AI agents)" }
      ]
    }
  end
end
