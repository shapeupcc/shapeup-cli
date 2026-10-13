# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Setup < Base
      SKILLS_DIR = File.expand_path("../../../skills", __dir__)
      SKILL_SOURCE = File.join(SKILLS_DIR, "shapeup", "SKILL.md")
      SKILL_NAMES = %w[ shapeup shapeup-connect ].freeze

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
          install_skills(File.join(Dir.home, ".#{agent}", "skills"), "~/.#{agent}/skills")
        end

        def install_project
          install_skills(File.join(".claude", "skills"), ".claude/skills")
        end

        def install_skills(base, display_base)
          SKILL_NAMES.each do |name|
            source = File.join(SKILLS_DIR, name, "SKILL.md")
            abort "SKILL.md not found at #{source}. Is the CLI installed correctly?" unless File.exist?(source)

            dir = File.join(base, name)
            FileUtils.mkdir_p(dir)
            dest = File.join(dir, "SKILL.md")

            puts "#{File.exist?(dest) ? "Updating" : "Installing"} #{display_base}/#{name}/SKILL.md"
            FileUtils.cp(source, dest)
          end

          puts "Done! Restart your agent session to pick up the skill."
          puts
          puts "The skill triggers on phrases like:"
          puts "  'my tasks', 'list pitches', 'cycle progress', 'shapeup', etc."
          puts
          puts "Your agent will use the ShapeUp CLI to handle these requests."
          puts
          puts "To let your ShapeUp agent pick up requests from issues, run /shapeup-connect."
        end
    end
  end
end
