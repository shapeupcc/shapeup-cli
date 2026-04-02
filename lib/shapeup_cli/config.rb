# frozen_string_literal: true

module ShapeupCli
  module Config
    CONFIG_DIR = File.join(Dir.home, ".config", "shapeup")
    PROFILES_FILE = File.join(CONFIG_DIR, "profiles.json")
    CONFIG_FILE = File.join(CONFIG_DIR, "config.json")

    # Project-level config — walks up from current directory
    PROJECT_CONFIG_NAME = ".shapeup/config.json"

    def self.ensure_config_dir
      FileUtils.mkdir_p(CONFIG_DIR)
    end

    # --- Profiles ---
    #
    # profiles.json stores named profiles:
    # {
    #   "default": "compass-labs",
    #   "profiles": {
    #     "acme-corp":   { "token": "...", "host": "https://shapeup.cc", "organisation_id": "2", "name": "Acme Corp" },
    #     "side-project": { "token": "...", "host": "https://shapeup.cc", "organisation_id": "5", "name": "Side Project" }
    #   }
    # }

    def self.save_profile(name, token:, host:, organisation_id:, display_name: nil)
      ensure_config_dir
      data = load_profiles_raw
      data["profiles"] ||= {}
      data["profiles"][name] = {
        "token" => token,
        "host" => host,
        "organisation_id" => organisation_id.to_s,
        "name" => display_name || name
      }
      # Set as default if it's the first profile
      data["default"] ||= name
      File.write(PROFILES_FILE, JSON.pretty_generate(data))
      File.chmod(0600, PROFILES_FILE)
    end

    def self.switch_profile(name)
      data = load_profiles_raw
      unless data.dig("profiles", name)
        available = (data["profiles"] || {}).keys
        abort "Profile '#{name}' not found. Available: #{available.join(", ")}"
      end
      data["default"] = name
      File.write(PROFILES_FILE, JSON.pretty_generate(data))
    end

    def self.delete_profile(name)
      data = load_profiles_raw
      data["profiles"]&.delete(name)
      data["default"] = data["profiles"]&.keys&.first if data["default"] == name
      File.write(PROFILES_FILE, JSON.pretty_generate(data))
    end

    def self.list_profiles
      data = load_profiles_raw
      default = data["default"]
      (data["profiles"] || {}).map do |key, profile|
        { name: key, display_name: profile["name"], organisation_id: profile["organisation_id"],
          host: profile["host"], default: key == default }
      end
    end

    def self.current_profile
      data = load_profiles_raw
      name = ENV["SHAPEUP_PROFILE"] || data["default"]
      return nil unless name
      profile = data.dig("profiles", name)
      return nil unless profile
      profile.merge("profile_name" => name)
    end

    def self.clear_credentials
      File.delete(PROFILES_FILE) if File.exist?(PROFILES_FILE)
    end

    # --- Config (defaults) ---

    def self.save_config(key, value)
      ensure_config_dir
      data = load_config_raw
      data[key] = value
      File.write(CONFIG_FILE, JSON.pretty_generate(data))
    end

    def self.load_config
      data = load_config_raw

      # Merge project-level config (walks up directory tree, takes precedence)
      if (project_config = find_project_config)
        project = JSON.parse(File.read(project_config)) rescue {}
        data.merge!(project)
      end

      data
    end

    # Resolution order: env var > project config > global config > profile > default
    def self.host
      ENV["SHAPEUP_HOST"] || load_config["host"] || current_profile&.dig("host") || ShapeupCli::DEFAULT_HOST
    end

    def self.organisation_id
      ENV["SHAPEUP_ORG"] || load_config["organisation_id"] || current_profile&.dig("organisation_id")&.then { |v| v.empty? ? nil : v }
    end

    def self.token
      ENV["SHAPEUP_TOKEN"] || current_profile&.dig("token")
    end

    # --- Pipe detection ---

    def self.piped?
      !$stdout.tty?
    end

    # --- Auth status (for plugin hook) ---

    def self.authenticated?
      !!token
    end

    def self.current_profile_name
      ENV["SHAPEUP_PROFILE"] || load_profiles_raw["default"]
    end

    private_class_method def self.load_profiles_raw
      return {} unless File.exist?(PROFILES_FILE)
      JSON.parse(File.read(PROFILES_FILE)) rescue {}
    end

    private_class_method def self.load_config_raw
      return {} unless File.exist?(CONFIG_FILE)
      JSON.parse(File.read(CONFIG_FILE)) rescue {}
    end

    # Walk up from current directory looking for .shapeup/config.json
    private_class_method def self.find_project_config
      dir = Dir.pwd
      loop do
        candidate = File.join(dir, PROJECT_CONFIG_NAME)
        return candidate if File.exist?(candidate)
        parent = File.dirname(dir)
        break if parent == dir # reached root
        dir = parent
      end
      nil
    end
  end
end
