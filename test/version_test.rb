# frozen_string_literal: true

require_relative "test_helper"
require "json"

# VERSION lives in one Ruby file (lib/shapeup_cli/version.rb), referenced by
# the gemspec. plugin.json is plain JSON and can't reference it, so pin it
# here — a release bump must touch both.
class VersionTest < Minitest::Test
  def test_plugin_manifest_version_matches_the_gem
    manifest = JSON.parse(File.read(File.expand_path("../.claude-plugin/plugin.json", __dir__)))
    assert_equal ShapeupCli::VERSION, manifest["version"],
      "plugin.json version is out of sync with ShapeupCli::VERSION — bump both"
  end
end
