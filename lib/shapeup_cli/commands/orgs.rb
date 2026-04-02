# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Orgs < Base
      def self.metadata
        {
          command: "orgs",
          path: "shapeup orgs",
          short: "List organisations you have access to",
          flags: [],
          examples: [
            "shapeup orgs",
            "shapeup orgs --json"
          ]
        }
      end

      def execute
        result = client.call_tool("list_organisations")

        render result,
          summary: "Organisations",
          breadcrumbs: [
            { cmd: "shapeup pitches list --org <id>", description: "List pitches for an org" },
            { cmd: "shapeup cycles --org <id>", description: "List cycles for an org" }
          ]
      end

      private
        # Override: orgs doesn't need an org_id
        def org_id = nil
    end
  end
end
