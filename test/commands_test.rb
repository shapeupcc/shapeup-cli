# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

# Covers the new write/delete commands and, especially, the confirmation
# guard on destructive actions. Commands are exercised without touching the
# network by stubbing #call_tool (and #render) on the instance, so we assert
# on the MCP tool name + arguments each command produces.
class CommandsTest < Minitest::Test
  include ShapeupCli::Commands

  # --- helpers -------------------------------------------------------------

  # Run a command's execute, capturing every call_tool(name, **args) it makes.
  # Returns the array of [name, args] tuples. No network, no real rendering.
  def capture_calls(klass, argv)
    inst = klass.new(argv)
    calls = []
    inst.define_singleton_method(:call_tool) do |name, **args|
      calls << [ name, args ]
      { "content" => [ { "type" => "text", "text" => "{}" } ] }
    end
    inst.define_singleton_method(:render) { |*_, **__| nil }
    capture_io { inst.execute }
    calls
  end

  # Swap $stdin for a fake with a controllable tty? and canned input.
  def with_stdin(tty:, input: "")
    fake = StringIO.new(input)
    fake.define_singleton_method(:tty?) { tty }
    old = $stdin
    $stdin = fake
    yield
  ensure
    $stdin = old
  end

  def base_instance(argv = [])
    ShapeupCli::Commands::Orgs.new(argv)
  end

  # --- confirmation flag parsing ------------------------------------------

  def test_assume_yes_consumes_long_flag
    inst = base_instance(%w[delete 5 --yes])
    assert_equal true, inst.send(:assume_yes?)
    refute_includes inst.instance_variable_get(:@remaining), "--yes"
  end

  def test_assume_yes_consumes_short_flag
    inst = base_instance(%w[delete 5 -y])
    assert_equal true, inst.send(:assume_yes?)
    refute_includes inst.instance_variable_get(:@remaining), "-y"
  end

  def test_assume_yes_false_when_absent
    inst = base_instance(%w[delete 5])
    assert_equal false, inst.send(:assume_yes?)
  end

  # --- confirm_destructive! behaviour -------------------------------------

  def test_confirm_bypassed_when_assume_yes
    inst = base_instance
    with_stdin(tty: true, input: "n\n") do # would decline, but bypass wins
      inst.send(:confirm_destructive!, "Delete pitch #1", true)
    end
    # no SystemExit raised == pass
  end

  def test_confirm_refuses_without_tty_and_without_yes
    inst = base_instance
    with_stdin(tty: false) do
      err = capture_io do
        assert_raises(SystemExit) { inst.send(:confirm_destructive!, "Delete pitch #1", false) }
      end.last
      assert_match(/Refusing to Delete pitch #1/, err)
      assert_match(/--yes/, err)
    end
  end

  def test_confirm_proceeds_on_tty_with_y
    inst = base_instance
    with_stdin(tty: true, input: "y\n") do
      capture_io { inst.send(:confirm_destructive!, "Delete pitch #1", false) }
    end
  end

  def test_confirm_proceeds_on_tty_with_yes
    inst = base_instance
    with_stdin(tty: true, input: "yes\n") do
      capture_io { inst.send(:confirm_destructive!, "Delete pitch #1", false) }
    end
  end

  def test_confirm_aborts_on_tty_with_no
    inst = base_instance
    with_stdin(tty: true, input: "n\n") do
      capture_io do
        assert_raises(SystemExit) { inst.send(:confirm_destructive!, "Delete pitch #1", false) }
      end
    end
  end

  def test_confirm_aborts_on_tty_with_empty_default
    inst = base_instance
    with_stdin(tty: true, input: "\n") do
      capture_io do
        assert_raises(SystemExit) { inst.send(:confirm_destructive!, "Delete pitch #1", false) }
      end
    end
  end

  # --- deletes are actually guarded ---------------------------------------

  def assert_delete_guarded(klass, argv_without_yes)
    inst = klass.new(argv_without_yes)
    called = false
    inst.define_singleton_method(:call_tool) { |*_a, **_k| called = true; {} }
    inst.define_singleton_method(:render) { |*_, **__| nil }
    with_stdin(tty: false) do
      capture_io { assert_raises(SystemExit) { inst.execute } }
    end
    refute called, "#{klass}##{argv_without_yes.first} must not hit the API without confirmation"
  end

  def test_pitches_delete_guarded
    assert_delete_guarded(ShapeupCli::Commands::Pitches, %w[delete 7])
  end

  def test_scopes_delete_guarded
    assert_delete_guarded(ShapeupCli::Commands::Scopes, %w[delete 7])
  end

  def test_tasks_delete_guarded
    assert_delete_guarded(ShapeupCli::Commands::Tasks, %w[delete 7])
  end

  def test_issues_delete_guarded
    assert_delete_guarded(ShapeupCli::Commands::Issues, %w[delete 7])
  end

  def test_comments_remove_guarded
    assert_delete_guarded(ShapeupCli::Commands::Comments, %w[remove 7])
  end

  # --- deletes call the right tool when confirmed (--yes) ------------------

  def test_pitches_delete_calls_tool_with_yes
    calls = capture_calls(ShapeupCli::Commands::Pitches, %w[delete 7 --yes])
    assert_equal [ [ "delete_package", { package: "7" } ] ], calls
  end

  def test_scopes_delete_calls_tool_with_yes
    calls = capture_calls(ShapeupCli::Commands::Scopes, %w[delete 7 --yes])
    assert_equal [ [ "delete_scope", { scope: "7" } ] ], calls
  end

  def test_tasks_delete_calls_tool_with_yes
    calls = capture_calls(ShapeupCli::Commands::Tasks, %w[delete 7 -y])
    assert_equal [ [ "delete_task", { task: "7" } ] ], calls
  end

  def test_issues_delete_calls_tool_with_yes
    calls = capture_calls(ShapeupCli::Commands::Issues, %w[delete 7 --yes])
    assert_equal [ [ "delete_issue", { issue: "7" } ] ], calls
  end

  def test_comments_remove_calls_tool_with_yes
    calls = capture_calls(ShapeupCli::Commands::Comments, %w[remove 7 --yes])
    assert_equal [ [ "delete_comment", { comment_id: "7" } ] ], calls
  end

  # --- new non-destructive commands ---------------------------------------

  def test_tasks_uncomplete
    calls = capture_calls(ShapeupCli::Commands::Tasks, %w[uncomplete 9])
    assert_equal [ [ "uncomplete_task", { task: "9" } ] ], calls
  end

  def test_tasks_update_description_and_scope
    calls = capture_calls(ShapeupCli::Commands::Tasks, ["update", "9", "--description", "New text", "--scope", "3"])
    assert_equal [ [ "update_task", { task: "9", description: "New text", scope: "3" } ] ], calls
  end

  def test_tasks_update_unmap_scope
    calls = capture_calls(ShapeupCli::Commands::Tasks, %w[update 9 --scope none])
    assert_equal [ [ "update_task", { task: "9", scope: "none" } ] ], calls
  end

  def test_tasks_update_requires_a_field
    inst = ShapeupCli::Commands::Tasks.new(%w[update 9])
    inst.define_singleton_method(:call_tool) { |*_a, **_k| flunk "should not call API" }
    capture_io { assert_raises(SystemExit) { inst.execute } }
  end

  def test_pitches_update
    calls = capture_calls(ShapeupCli::Commands::Pitches, ["update", "42", "--status", "shaped", "--appetite", "small_batch"])
    assert_equal [ [ "update_package", { package: "42", status: "shaped", appetite: "small_batch" } ] ], calls
  end

  def test_pitches_update_requires_a_field
    inst = ShapeupCli::Commands::Pitches.new(%w[update 42])
    inst.define_singleton_method(:call_tool) { |*_a, **_k| flunk "should not call API" }
    capture_io { assert_raises(SystemExit) { inst.execute } }
  end

  def test_pitches_extend
    calls = capture_calls(ShapeupCli::Commands::Pitches, %w[extend 42 --predecessor 30])
    assert_equal [ [ "extend_package", { package: "42", predecessor: "30" } ] ], calls
  end

  def test_pitches_extend_requires_predecessor
    inst = ShapeupCli::Commands::Pitches.new(%w[extend 42])
    inst.define_singleton_method(:call_tool) { |*_a, **_k| flunk "should not call API" }
    capture_io { assert_raises(SystemExit) { inst.execute } }
  end

  def test_pitches_detach
    calls = capture_calls(ShapeupCli::Commands::Pitches, %w[detach 42])
    assert_equal [ [ "detach_package", { package: "42" } ] ], calls
  end

  def test_comments_edit
    calls = capture_calls(ShapeupCli::Commands::Comments, ["edit", "88", "Updated text"])
    assert_equal [ [ "update_comment", { comment_id: "88", content: "Updated text" } ] ], calls
  end

  def test_streams_list
    calls = capture_calls(ShapeupCli::Commands::Streams, %w[list])
    assert_equal [ [ "list_streams", {} ] ], calls
  end

  def test_streams_list_all
    calls = capture_calls(ShapeupCli::Commands::Streams, %w[list --all])
    assert_equal [ [ "list_streams", { include_archived: true } ] ], calls
  end

  def test_streams_show
    calls = capture_calls(ShapeupCli::Commands::Streams, %w[show 3])
    assert_equal [ [ "show_stream", { stream: "3" } ] ], calls
  end

  def test_streams_bare_id_shows
    calls = capture_calls(ShapeupCli::Commands::Streams, %w[3])
    assert_equal [ [ "show_stream", { stream: "3" } ] ], calls
  end

  # --- metadata integrity for new subcommands -----------------------------

  def test_streams_in_command_map
    assert_equal ShapeupCli::Commands::Streams, ShapeupCli::COMMAND_MAP["streams"]
  end

  def test_new_subcommands_present_in_metadata
    pitch_subs = ShapeupCli::Commands::Pitches.metadata[:subcommands].map { |s| s[:name] }
    assert (%w[update extend detach delete] - pitch_subs).empty?, "pitches missing subcommands: #{pitch_subs}"

    task_subs = ShapeupCli::Commands::Tasks.metadata[:subcommands].map { |s| s[:name] }
    assert (%w[uncomplete update delete] - task_subs).empty?, "tasks missing subcommands: #{task_subs}"

    scope_subs = ShapeupCli::Commands::Scopes.metadata[:subcommands].map { |s| s[:name] }
    assert_includes scope_subs, "delete"

    comment_subs = ShapeupCli::Commands::Comments.metadata[:subcommands].map { |s| s[:name] }
    assert (%w[edit remove] - comment_subs).empty?, "comments missing subcommands: #{comment_subs}"
  end
end
