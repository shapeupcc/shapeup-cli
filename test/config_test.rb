# frozen_string_literal: true

require_relative "test_helper"

class ConfigTest < Minitest::Test
  def test_env_var_token_takes_priority
    ENV["SHAPEUP_TOKEN"] = "env_token_123"
    assert_equal "env_token_123", ShapeupCli::Config.token
  ensure
    ENV.delete("SHAPEUP_TOKEN")
  end

  def test_env_var_org_takes_priority
    ENV["SHAPEUP_ORG"] = "99"
    assert_equal "99", ShapeupCli::Config.organisation_id
  ensure
    ENV.delete("SHAPEUP_ORG")
  end

  def test_env_var_host_takes_priority
    ENV["SHAPEUP_HOST"] = "https://custom.example.com"
    assert_equal "https://custom.example.com", ShapeupCli::Config.host
  ensure
    ENV.delete("SHAPEUP_HOST")
  end

  def test_a_profile_picked_with_shapeup_profile_beats_saved_config
    ENV["SHAPEUP_PROFILE"] = "bond"
    profile = { "host" => "http://localhost:3000", "organisation_id" => "1", "profile_name" => "bond" }

    stubbing(ShapeupCli::Config, :current_profile, profile) do
      stubbing(ShapeupCli::Config, :load_config, { "host" => "https://shapeup.cc", "organisation_id" => "7" }) do
        assert_equal "http://localhost:3000", ShapeupCli::Config.host
        assert_equal "1", ShapeupCli::Config.organisation_id
      end
    end
  ensure
    ENV.delete("SHAPEUP_PROFILE")
  end

  def stubbing(object, method, value)
    original = object.method(method)
    object.define_singleton_method(method) { |*| value }
    yield
  ensure
    object.define_singleton_method(method, original)
  end

  def test_default_host
    ENV.delete("SHAPEUP_HOST")
    # Will fall through to credentials or default
    host = ShapeupCli::Config.host
    assert host.is_a?(String)
    assert host.start_with?("http")
  end

  def test_explain_traces_precedence_with_env_override
    ENV["SHAPEUP_ORG"] = "99"

    out, _err = capture_io do
      ShapeupCli::Commands::ConfigCmd.run([ "explain", "--json" ])
    end
    org = JSON.parse(out).dig("data", "org")

    assert_equal "99", org["value"]
    assert_equal "SHAPEUP_ORG env", org["source"]
    selected = org["candidates"].select { |c| c["selected"] }
    assert_equal 1, selected.length
    assert_equal "SHAPEUP_ORG env", selected.first["source"]
  ensure
    ENV.delete("SHAPEUP_ORG")
  end

  def test_explain_never_prints_token_values
    ENV["SHAPEUP_TOKEN"] = "secret_token_value"

    out, _err = capture_io do
      ShapeupCli::Commands::ConfigCmd.run([ "explain", "--json" ])
    end

    refute_includes out, "secret_token_value"
    assert_equal "configured in environment", JSON.parse(out).dig("data", "token", "value")
  ensure
    ENV.delete("SHAPEUP_TOKEN")
  end

  def test_piped_detection_method_exists
    # piped? delegates to $stdout.tty? — just verify the method works
    result = ShapeupCli::Config.piped?
    assert_includes [ true, false ], result
  end
end
