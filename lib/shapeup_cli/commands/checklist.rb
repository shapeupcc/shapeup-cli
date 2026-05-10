# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Checklist < Base
      def self.metadata
        {
          command: "checklist",
          path: "shapeup checklist",
          short: "Manage the checklist on a pitch or issue",
          subcommands: [
            { name: "list", short: "List items (default)", path: "shapeup checklist --pitch <id>" },
            { name: "add", short: "Add an item", path: 'shapeup checklist add --pitch <id> "Item text"' },
            { name: "tick", short: "Mark an item complete", path: "shapeup checklist tick <item_id>" },
            { name: "untick", short: "Mark an item incomplete", path: "shapeup checklist untick <item_id>" },
            { name: "edit", short: "Rename an item", path: 'shapeup checklist edit <item_id> "New text"' },
            { name: "remove", short: "Delete an item", path: "shapeup checklist remove <item_id>" }
          ],
          flags: [
            { name: "pitch", type: "string", usage: "Pitch ID (for list/add)" },
            { name: "issue", type: "string", usage: "Issue ID (for list/add)" }
          ],
          examples: [
            "shapeup checklist --pitch 42",
            "shapeup checklist --issue 7",
            'shapeup checklist add --pitch 42 "Confirm Slack webhook"',
            "shapeup checklist tick 18",
            "shapeup checklist untick 18",
            'shapeup checklist edit 18 "Confirm Slack webhook secret rotation"',
            "shapeup checklist remove 18"
          ]
        }
      end

      def execute
        subcommand = positional_arg(0)

        case subcommand
        when "add"        then add
        when "tick"       then tick
        when "untick"     then untick
        when "edit"       then edit
        when "remove"     then remove
        when "list", nil  then list
        else list
        end
      end

      private
        def list
          type, id = resolve_target
          result = call_tool("list_checklist_items", checklistable_type: type, checklistable_id: id.to_s)

          render result,
            summary: "Checklist on #{type} ##{id}",
            breadcrumbs: [
              { cmd: "shapeup checklist add --#{type.downcase == 'package' ? 'pitch' : 'issue'} #{id} \"Item\"", description: "Add an item" },
              { cmd: "shapeup checklist tick <item_id>", description: "Tick an item" }
            ]
        end

        def add
          type, id = resolve_target
          text = positional_arg(1) || abort('Usage: shapeup checklist add --pitch <id> "Item text"')

          result = call_tool("create_checklist_item", checklistable_type: type, checklistable_id: id.to_s, content: text)

          render result,
            summary: "Item added to #{type} ##{id}",
            breadcrumbs: [
              { cmd: "shapeup checklist --#{type.downcase == 'package' ? 'pitch' : 'issue'} #{id}", description: "View checklist" }
            ]
        end

        def tick
          item_id = positional_arg(1) || abort("Usage: shapeup checklist tick <item_id>")

          result = call_tool("update_checklist_item", checklist_item: item_id.to_s, completed: true)

          render result, summary: "Item ##{item_id} ticked"
        end

        def untick
          item_id = positional_arg(1) || abort("Usage: shapeup checklist untick <item_id>")

          result = call_tool("update_checklist_item", checklist_item: item_id.to_s, completed: false)

          render result, summary: "Item ##{item_id} unticked"
        end

        def edit
          item_id = positional_arg(1) || abort('Usage: shapeup checklist edit <item_id> "New text"')
          text = positional_arg(2) || abort('Usage: shapeup checklist edit <item_id> "New text"')

          result = call_tool("update_checklist_item", checklist_item: item_id.to_s, content: text)

          render result, summary: "Item ##{item_id} updated"
        end

        def remove
          item_id = positional_arg(1) || abort("Usage: shapeup checklist remove <item_id>")

          result = call_tool("delete_checklist_item", checklist_item: item_id.to_s)

          render result, summary: "Item ##{item_id} removed"
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
