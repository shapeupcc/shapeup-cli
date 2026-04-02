# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Setup < Base
      SKILL_SOURCE = File.expand_path("../../../skills/shapeup/SKILL.md", __dir__)

      def self.metadata
        {
          command: "setup",
          path: "shapeup setup",
          short: "Install ShapeUp skills into an AI agent",
          subcommands: [
            { name: "claude", short: "Install skill into Claude Code (~/.claude/skills/)", path: "shapeup setup claude" },
            { name: "cursor", short: "Install skill into Cursor (.cursor/skills/)", path: "shapeup setup cursor" },
            { name: "project", short: "Install skill into current project (.claude/skills/)", path: "shapeup setup project" }
          ],
          flags: [],
          examples: [
            "shapeup setup claude",
            "shapeup setup project",
            "shapeup setup cursor"
          ]
        }
      end

      def execute
        target = positional_arg(0)

        case target
        when "claude"  then install_global("claude")
        when "cursor"  then install_global("cursor")
        when "project" then install_project
        else
          puts <<~HELP
            Usage: shapeup setup <target>

            Targets:
              claude    Install skill globally into ~/.claude/skills/
              cursor    Install skill globally into ~/.cursor/skills/
              project   Install skill into .claude/skills/ (current directory)

            This copies the ShapeUp SKILL.md so your AI agent knows how to
            use the ShapeUp CLI when triggered by relevant phrases.
          HELP
        end
      end

      private
        def install_global(agent)
          dir = File.join(Dir.home, ".#{agent}", "skills", "shapeup")
          install_skill(dir, "~/.#{agent}/skills/shapeup/")
        end

        def install_project
          dir = File.join(".claude", "skills", "shapeup")
          install_skill(dir, ".claude/skills/shapeup/")
        end

        def install_skill(dir, display_path)
          unless File.exist?(SKILL_SOURCE)
            abort "SKILL.md not found at #{SKILL_SOURCE}. Is the CLI installed correctly?"
          end

          FileUtils.mkdir_p(dir)
          dest = File.join(dir, "SKILL.md")

          if File.exist?(dest)
            puts "Updating #{display_path}SKILL.md"
          else
            puts "Installing #{display_path}SKILL.md"
          end

          FileUtils.cp(SKILL_SOURCE, dest)

          puts "Done! Restart your agent session to pick up the skill."
          puts
          puts "The skill triggers on phrases like:"
          puts "  'my tasks', 'list pitches', 'cycle progress', 'shapeup', etc."
          puts
          puts "Your agent will use the ShapeUp CLI to handle these requests."
        end
    end
  end
end
