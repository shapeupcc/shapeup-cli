# frozen_string_literal: true

module ShapeupCli
  module Commands
    class Login
      def self.run(args)
        new(args).run
      end

      def initialize(args)
        @host = Config.host
        @profile_name = nil
        @requested_org = nil

        args.each_with_index do |arg, i|
          case arg
          when "--host" then @host = args[i + 1]
          when /\A--host=(.+)\z/ then @host = $1
          when "--profile" then @profile_name = args[i + 1]
          when /\A--profile=(.+)\z/ then @profile_name = $1
          when "--org" then @requested_org = args[i + 1]
          when /\A--org=(.+)\z/ then @requested_org = $1
          end
        end
      end

      def run
        token = ShapeupCli::Auth.login(host: @host)["access_token"]
        orgs = fetch_organisations(token)
        org = choose_organisation(orgs)

        profile_name = @profile_name || (org ? slug(org["name"]) : slug(URI.parse(@host).host))
        Config.save_profile(profile_name, token: token, host: @host, organisation_id: org&.dig("id"), display_name: org&.dig("name") || profile_name)
        Config.switch_profile(profile_name)

        if org
          puts "\nProfile '#{profile_name}' created and set as default."
          puts "  org: #{org["name"]} (#{org["id"]})"
          puts "  host: #{@host}"
          puts "\nTo add another profile, run 'shapeup login' again."
          puts "To switch: 'shapeup auth switch <name>'"
        else
          puts "\nSigned in and saved to profile '#{profile_name}', but no organisation is set yet."
          puts "Choose one with: shapeup config set org <name>"
          list_organisations(orgs)
          exit EXIT_USAGE if @requested_org
        end
      end

      private
        def fetch_organisations(token)
          result = Client.new(host: @host, token: token).call_tool("list_organisations")
          data = Output.extract_data(result)
          data.is_a?(Hash) ? (data["organisations"] || []) : []
        end

        def choose_organisation(orgs)
          if @requested_org
            find_organisation(orgs, @requested_org)
          elsif orgs.length == 1
            orgs.first
          elsif orgs.any? && $stdin.tty?
            prompt_for_organisation(orgs)
          end
        end

        def find_organisation(orgs, value)
          orgs.find { |o| o["id"].to_s == value.to_s || o["name"].casecmp?(value) }.tap do |org|
            $stderr.puts "Organisation '#{value}' not found." unless org
          end
        end

        def prompt_for_organisation(orgs)
          puts "\nChoose an organisation for this profile:\n"
          list_organisations(orgs)
          print "\nEnter number (1-#{orgs.length}): "
          choice = $stdin.gets&.strip&.to_i
          orgs[choice - 1] if choice&.between?(1, orgs.length)
        end

        def list_organisations(orgs)
          orgs.each_with_index { |o, i| puts "  #{i + 1}) #{o["name"]} (#{o["id"]})" }
        end

        def slug(name)
          name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
        end
    end
  end
end
