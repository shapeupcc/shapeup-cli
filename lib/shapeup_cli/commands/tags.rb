# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Tags < Base
      def self.metadata
        {
          command: "tags",
          path: "shapeup tags",
          short: "List, add, and remove tags on pitches and issues",
          subcommands: [
            { name: "list", short: "List the org's tag vocabulary (default)", path: "shapeup tags" },
            { name: "add", short: "Tag a pitch or issue", path: "shapeup tags add --pitch <id> <name>" },
            { name: "remove", short: "Untag a pitch or issue", path: "shapeup tags remove --pitch <id> <name>" }
          ],
          flags: [
            { name: "pitch", type: "string", usage: "Pitch ID (for add/remove)" },
            { name: "issue", type: "string", usage: "Issue ID (for add/remove)" }
          ],
          examples: [
            "shapeup tags",
            "shapeup tags add --pitch 42 q3-plan",
            "shapeup tags add --issue 7 needs-design",
            "shapeup tags remove --pitch 42 q3-plan",
            "shapeup pitches list --tag q3-plan"
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "add"        then add
        when "remove"     then remove
        when "list", nil  then list
        else list
        end
      end

      private
        def list
          result = call_tool("list_tags")

          render result,
            summary: "Tags",
            breadcrumbs: [
              { cmd: "shapeup tags add --pitch <id> <name>", description: "Tag a pitch" },
              { cmd: "shapeup pitches list --tag <name>", description: "Filter pitches by tag" }
            ]
        end

        def add
          type, id = resolve_target
          name = positional_arg(1) || abort("Usage: shapeup tags add --pitch <id> <name>")

          result = call_tool("add_tag", taggable_type: type, taggable_id: id.to_s, name: name)

          render result, summary: "Tagged #{type} ##{id}"
        end

        def remove
          type, id = resolve_target
          name = positional_arg(1) || abort("Usage: shapeup tags remove --pitch <id> <name>")

          result = call_tool("remove_tag", taggable_type: type, taggable_id: id.to_s, name: name)

          render result, summary: "Untagged #{type} ##{id}"
        end

        def resolve_target
          pitch = extract_option("--pitch")
          issue = extract_option("--issue")

          if pitch
            [ "Package", pitch ]
          elsif issue
            [ "Issue", issue ]
          else
            abort("Specify a target: --pitch <id> or --issue <id>")
          end
        end
    end
  end
end
