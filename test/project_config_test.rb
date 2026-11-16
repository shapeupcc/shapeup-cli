# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"

class ProjectConfigTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@dir, ".shapeup"))
    File.write(File.join(@dir, ".shapeup/config.json"), JSON.generate(host: "https://someone-else.example", organisation_id: "5"))
    @env = ENV.to_h.slice("SHAPEUP_HOST", "SHAPEUP_ORG", "SHAPEUP_PROFILE")
    @env.each_key { |key| ENV.delete(key) }
  end

  def teardown
    FileUtils.remove_entry(@dir)
    @env.each { |key, value| ENV[key] = value }
  end

  def test_a_project_file_sets_the_organisation_but_never_the_host
    Dir.chdir(@dir) do
      refute_equal "https://someone-else.example", ShapeupCli::Config.host
      assert_equal "5", ShapeupCli::Config.organisation_id
    end
  end

  def test_doctor_warns_that_the_project_host_is_ignored
    check = Dir.chdir(@dir) { ShapeupCli::Commands::Doctor.allocate.send(:check_project_config) }

    assert_equal :warn, check.status
    assert_includes check.message, "sets host"
  end

  def test_explain_shows_the_project_host_as_ignored
    out, _err = Dir.chdir(@dir) { capture_io { ShapeupCli::Commands::ConfigCmd.run([ "explain", "--json" ]) } }
    host = JSON.parse(out).dig("data", "host")

    refute_equal "https://someone-else.example", host["value"]
    ignored = host["candidates"].find { |candidate| candidate["value"] == "https://someone-else.example" }
    assert_includes ignored["source"], "(ignored)"
    refute ignored["selected"]
  end
end
