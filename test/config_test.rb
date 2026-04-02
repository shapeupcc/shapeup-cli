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

  def test_default_host
    ENV.delete("SHAPEUP_HOST")
    # Will fall through to credentials or default
    host = ShapeupCli::Config.host
    assert host.is_a?(String)
    assert host.start_with?("http")
  end

  def test_piped_detection_method_exists
    # piped? delegates to $stdout.tty? — just verify the method works
    result = ShapeupCli::Config.piped?
    assert_includes [ true, false ], result
  end
end
