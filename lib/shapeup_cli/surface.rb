# frozen_string_literal: true

module ShapeupCli
  # Serializes the entire CLI surface — commands, subcommands, flags — into
  # sorted lines, snapshotted in SURFACE.txt and gated by surface_test.rb so
  # no command or flag appears or disappears without a reviewed diff.
  module Surface
    TOP_LEVEL_COMMANDS = %w[ login logout commands help version ].freeze

    def self.lines
      lines = []

      TOP_LEVEL_COMMANDS.each { |name| lines << "CMD shapeup #{name}" }

      ShapeupCli.top_level_metadata[:shortcuts].each_key do |shortcut|
        lines << "CMD shapeup #{shortcut.split.first}"
      end

      ShapeupCli.top_level_metadata[:inherited_flags].each do |flag|
        lines << "FLAG shapeup --#{flag[:name]} #{flag[:type]}"
      end

      ShapeupCli::COMMAND_MAP.each do |name, klass|
        lines << "CMD shapeup #{name}"
        metadata = klass.metadata
        (metadata[:subcommands] || []).each do |sub|
          lines << "SUB shapeup #{name} #{sub[:name]}"
        end
        (metadata[:flags] || []).each do |flag|
          lines << "FLAG shapeup #{name} --#{flag[:name]} #{flag[:type]}"
        end
      end

      lines.uniq.sort
    end

    def self.render
      lines.join("\n") + "\n"
    end
  end
end
