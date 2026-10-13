# frozen_string_literal: true

require_relative "test_helper"

class ConnectTest < Minitest::Test
  AGENT = { "id" => 9, "name" => "bond", "owner" => { "id" => 1, "name" => "miles" } }.freeze

  def item(id, requester_id, requester_name)
    {
      "id" => id.to_s,
      "reason" => "mentioned",
      "issue" => { "id" => 42, "title" => "Date picker", "url" => "https://shapeup.cc/issues/42" },
      "request" => { "comment_id" => 7, "content" => "@bond please fix it" },
      "requester" => { "id" => requester_id, "name" => requester_name, "agent" => false },
      "reply_to" => { "issue_id" => 42, "comment_id" => 7 }
    }
  end

  def connect(argv, items)
    command = ShapeupCli::Commands::Connect.new(argv + [ "--once", "--org", "1" ])
    command.define_singleton_method(:call_tool) do |name, **|
      raise "unexpected tool #{name}" unless name == "list_inbox"
      { "content" => [ { "type" => "text", "text" => JSON.generate("agent" => AGENT, "items" => items, "count" => items.size) } ] }
    end

    out, _err = capture_io { command.execute }
    out.lines.map { |line| JSON.parse(line) }
  end

  def test_announces_itself_then_passes_on_the_owners_requests_oldest_first
    events = connect([], [ item(12, 1, "miles"), item(11, 1, "miles") ])

    assert_equal %w[ connected request request ], events.map { |e| e["type"] }
    assert_equal "bond", events.first["agent"]["name"]
    assert_equal "owner", events.first["trust"]
    assert_equal %w[ 11 12 ], events.drop(1).map { |e| e["id"] }
    assert_equal({ "issue_id" => 42, "comment_id" => 7 }, events.last["reply_to"])
  end

  def test_ignores_other_members_unless_trusted
    events = connect([], [ item(11, 5, "dana") ])
    assert_equal "ignored", events.last["type"]
    assert_match "dana is not trusted", events.last["why"]

    events = connect([ "--trust", "members" ], [ item(11, 5, "dana") ])
    assert_equal "request", events.last["type"]
  end

  def test_rejects_an_unknown_trust_level
    assert_raises(SystemExit) do
      capture_io { ShapeupCli::Commands::Connect.new([ "--trust", "everyone", "--once" ]).execute }
    end
  end
end
