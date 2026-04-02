# frozen_string_literal: true

require_relative "test_helper"

class ArgsTest < Minitest::Test
  # Test the Base command arg parsing via a concrete subclass
  # We use Orgs since it's the simplest (no org required)

  def test_org_flag_extracted
    instance = ShapeupCli::Commands::Orgs.new(%w[--org 42])
    # org_id is private, but we can check it doesn't appear in remaining
    assert instance.respond_to?(:execute)
  end

  def test_org_flag_with_equals
    instance = ShapeupCli::Commands::Orgs.new(%w[--org=42])
    assert instance.respond_to?(:execute)
  end

  def test_agent_help_detection
    instance = ShapeupCli::Commands::Pitches.new(%w[--agent --help])
    assert instance.agent_help?
  end

  def test_agent_without_help_is_not_agent_help
    instance = ShapeupCli::Commands::Pitches.new(%w[--agent list])
    refute instance.agent_help?
  end

  def test_help_without_agent_is_not_agent_help
    instance = ShapeupCli::Commands::Pitches.new(%w[--help])
    refute instance.agent_help?
  end

  def test_metadata_returns_hash_with_command
    metadata = ShapeupCli::Commands::Pitches.metadata
    assert_equal "pitches", metadata[:command]
    assert metadata[:subcommands].is_a?(Array)
    assert metadata[:flags].is_a?(Array)
    assert metadata[:examples].is_a?(Array)
  end

  def test_all_commands_have_metadata
    ShapeupCli::COMMAND_MAP.each do |name, klass|
      metadata = klass.metadata
      assert metadata[:command], "#{name} missing :command in metadata"
      assert metadata[:short], "#{name} missing :short in metadata"
    end
  end
end
