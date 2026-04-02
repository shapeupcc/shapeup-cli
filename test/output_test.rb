# frozen_string_literal: true

require_relative "test_helper"

class OutputTest < Minitest::Test
  # --- parse_mode ---

  def test_explicit_flag_overrides_tty_detection
    # Regardless of TTY state, explicit flags always win
    mode, remaining = ShapeupCli::Output.parse_mode(%w[pitches list --json])
    assert_equal :json, mode
    assert_equal %w[pitches list], remaining
  end

  def test_json_flag
    mode, remaining = ShapeupCli::Output.parse_mode(%w[pitches list --json])
    assert_equal :json, mode
    assert_equal %w[pitches list], remaining
  end

  def test_md_flag
    mode, _ = ShapeupCli::Output.parse_mode(%w[--md])
    assert_equal :markdown, mode
  end

  def test_short_md_flag
    mode, _ = ShapeupCli::Output.parse_mode(%w[-m])
    assert_equal :markdown, mode
  end

  def test_agent_flag
    mode, _ = ShapeupCli::Output.parse_mode(%w[--agent])
    assert_equal :agent, mode
  end

  def test_quiet_flag
    mode, _ = ShapeupCli::Output.parse_mode(%w[--quiet])
    assert_equal :agent, mode
  end

  def test_short_quiet_flag
    mode, _ = ShapeupCli::Output.parse_mode(%w[-q])
    assert_equal :agent, mode
  end

  def test_ids_only_flag
    mode, _ = ShapeupCli::Output.parse_mode(%w[--ids-only])
    assert_equal :ids_only, mode
  end

  def test_flags_stripped_from_remaining
    _, remaining = ShapeupCli::Output.parse_mode(%w[pitches list --json --org 42])
    assert_equal %w[pitches list --org 42], remaining
  end

  # --- extract_data ---

  def test_extract_data_from_mcp_result
    result = { "content" => [ { "type" => "text", "text" => '{"id":1}' } ] }
    assert_equal({ "id" => 1 }, ShapeupCli::Output.extract_data(result))
  end

  def test_extract_data_from_plain_hash
    result = { "id" => 1, "title" => "Test" }
    assert_equal result, ShapeupCli::Output.extract_data(result)
  end

  def test_extract_data_from_non_json_text
    result = { "content" => [ { "type" => "text", "text" => "plain text" } ] }
    assert_equal "plain text", ShapeupCli::Output.extract_data(result)
  end

  def test_extract_data_passes_through_non_hash
    assert_equal "hello", ShapeupCli::Output.extract_data("hello")
    assert_equal [ 1, 2 ], ShapeupCli::Output.extract_data([ 1, 2 ])
  end

  # --- render output modes ---

  def test_render_json_envelope
    data = [ { "id" => 1, "title" => "Test" } ]
    result = { "content" => [ { "type" => "text", "text" => JSON.generate(data) } ] }
    breadcrumbs = [ { cmd: "shapeup pitch 1", description: "View pitch" } ]

    output = capture_io do
      ShapeupCli::Output.render(result, breadcrumbs: breadcrumbs, mode: :json, summary: "Pitches")
    end.first

    parsed = JSON.parse(output)
    assert_equal true, parsed["ok"]
    assert_equal data, parsed["data"]
    assert_equal "Pitches", parsed["summary"]
    assert_equal 1, parsed["breadcrumbs"].length
  end

  def test_render_agent_mode_no_envelope
    data = { "id" => 1 }
    result = { "content" => [ { "type" => "text", "text" => JSON.generate(data) } ] }

    output = capture_io do
      ShapeupCli::Output.render(result, mode: :agent)
    end.first

    parsed = JSON.parse(output)
    assert_equal 1, parsed["id"]
    assert_nil parsed["ok"] # no envelope
  end

  def test_render_ids_only
    data = [ { "id" => 10 }, { "id" => 20 }, { "id" => 30 } ]
    result = { "content" => [ { "type" => "text", "text" => JSON.generate(data) } ] }

    output = capture_io do
      ShapeupCli::Output.render(result, mode: :ids_only)
    end.first

    assert_equal "10\n20\n30\n", output
  end

  def test_render_ids_only_from_nested_hash
    data = { "packages" => [ { "id" => 1 }, { "id" => 2 } ] }
    result = { "content" => [ { "type" => "text", "text" => JSON.generate(data) } ] }

    output = capture_io do
      ShapeupCli::Output.render(result, mode: :ids_only)
    end.first

    assert_equal "1\n2\n", output
  end
end
