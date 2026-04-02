# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "fileutils"
require "securerandom"
require "digest"
require "base64"
require "socket"

require_relative "shapeup_cli/config"
require_relative "shapeup_cli/auth"
require_relative "shapeup_cli/client"
require_relative "shapeup_cli/output"
require_relative "shapeup_cli/commands"

module ShapeupCli
  VERSION = "0.2.0"
  DEFAULT_HOST = "https://shapeup.cc"

  # Exit codes (matching ShapeUp/ShapeUp conventions)
  EXIT_OK          = 0
  EXIT_USAGE       = 1
  EXIT_NOT_FOUND   = 2
  EXIT_AUTH         = 3
  EXIT_PERMISSION  = 4
  EXIT_API_ERROR   = 5
  EXIT_RATE_LIMIT  = 6
  EXIT_INTERRUPTED = 130

  COMMAND_MAP = {
    "orgs"    => Commands::Orgs,
    "pitches" => Commands::Pitches,
    "cycle"   => Commands::Cycle,
    "scopes"  => Commands::Scopes,
    "tasks"   => Commands::Tasks,
    "issues"  => Commands::Issues,
    "my-work" => Commands::MyWork,
    "search"  => Commands::Search,
    "auth"    => Commands::Auth,
    "config"  => Commands::ConfigCmd,
    "setup"   => Commands::Setup,
    "comments" => Commands::Comments
  }.freeze

  def self.run(argv)
    args = argv.dup

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
    when "pitch"          then Commands::Pitches.run(["show"] + args)
    when "cycle"          then Commands::Cycle.run(args)
    when "cycles"         then Commands::Cycle.run(["list"] + args)
    when "scopes"         then Commands::Scopes.run(args)
    when "tasks"          then Commands::Tasks.run(args)
    when "todo"           then Commands::Tasks.run(["create"] + args)
    when "done"           then Commands::Tasks.run(["complete"] + args)
    when "issues"         then Commands::Issues.run(args)
    when "issue"          then Commands::Issues.run(["show"] + args)
    when "watching"       then Commands::Issues.run(["watching"] + args)
    when "comments"       then Commands::Comments.run(args)
    when "my-work", "me"  then Commands::MyWork.run(args)
    when "search"         then Commands::Search.run(args)
    when "config"         then Commands::ConfigCmd.run(args)
    when "setup"          then Commands::Setup.run(args)
    when "commands"       then Commands.list_commands
    when "version", "-v", "--version"
      puts "shapeup #{VERSION}"
    when "help", "-h", "--help", nil
      Commands.help
    else
      $stderr.puts "Unknown command: #{command}"
      $stderr.puts "Run 'shapeup help' for usage"
      exit 1
    end
  rescue Client::AuthError => e
    $stderr.puts "Not authenticated. Run 'shapeup login' first."
    exit EXIT_AUTH
  rescue Client::NotFoundError => e
    $stderr.puts "Not found: #{e.message}"
    exit EXIT_NOT_FOUND
  rescue Client::PermissionError => e
    $stderr.puts "Access denied: #{e.message}"
    exit EXIT_PERMISSION
  rescue Client::RateLimitError => e
    $stderr.puts "Rate limited — please wait and try again."
    exit EXIT_RATE_LIMIT
  rescue Client::ApiError => e
    $stderr.puts "Error: #{e.message}"
    exit EXIT_API_ERROR
  rescue Interrupt
    $stderr.puts "\nAborted."
    exit EXIT_INTERRUPTED
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
