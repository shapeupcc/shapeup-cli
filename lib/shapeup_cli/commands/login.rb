# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Login
      def self.run(args)
        host = nil
        profile_name = nil
        args.each_with_index do |arg, i|
          case arg
          when "--host" then host = args[i + 1]
          when /\A--host=(.+)\z/ then host = $1
          when "--profile" then profile_name = args[i + 1]
          when /\A--profile=(.+)\z/ then profile_name = $1
          end
        end

        host ||= Config.host
        token_response = ShapeupCli::Auth.login(host: host)
        token = token_response["access_token"]

        # Fetch orgs to let user pick one for this profile
        client = Client.new(host: host, token: token)
        result = client.call_tool("list_organisations")
        data = Output.extract_data(result)
        orgs = data.is_a?(Hash) ? (data["organisations"] || []) : []

        if orgs.empty?
          puts "No organisations found."
          return
        end

        # If only one org, use it automatically
        org = if orgs.length == 1
          orgs.first
        else
          puts "\nChoose an organisation for this profile:\n"
          orgs.each_with_index do |o, i|
            puts "  #{i + 1}) #{o["name"]}"
          end
          print "\nEnter number (1-#{orgs.length}): "
          choice = $stdin.gets&.strip&.to_i
          orgs[choice - 1] if choice&.between?(1, orgs.length)
        end

        unless org
          puts "No organisation selected."
          return
        end

        # Generate profile name from org name (slug it)
        profile_name ||= org["name"].downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")

        Config.save_profile(
          profile_name,
          token: token,
          host: host,
          organisation_id: org["id"],
          display_name: org["name"]
        )

        # Also set as default
        Config.switch_profile(profile_name)

        puts "\nProfile '#{profile_name}' created and set as default."
        puts "  org: #{org["name"]} (#{org["id"]})"
        puts "  host: #{host}"
        puts "\nTo add another profile, run 'shapeup login' again."
        puts "To switch: 'shapeup auth switch <name>'"
      end
    end
  end
end
