# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"

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

  def fake_client(responses)
    calls = []
    client = Object.new
    client.define_singleton_method(:calls) { calls }
    client.define_singleton_method(:call_tool) do |name, **args|
      calls << [ name, args ]
      payload = responses.fetch(name) { raise "unexpected tool #{name}" }
      { "content" => [ { "type" => "text", "text" => JSON.generate(payload) } ] }
    end
    client
  end

  def connect(argv, client)
    command = ShapeupCli::Commands::Connect.new(argv + [ "--once", "--org", "1" ])
    command.define_singleton_method(:client) { client }

    out, _err = capture_io { command.execute }
    out.lines.map { |line| JSON.parse(line) }
  end

  def as_agent(items)
    fake_client(
      "list_my_agents" => { "signed_in_as_agent" => true, "agents" => [], "can_add" => false },
      "list_inbox" => { "agent" => AGENT, "items" => items, "count" => items.size }
    )
  end

  def test_announces_itself_then_passes_on_the_owners_requests_oldest_first
    events = connect([], as_agent([ item(12, 1, "miles"), item(11, 1, "miles") ]))

    assert_equal %w[ connected request request ], events.map { |e| e["type"] }
    assert_equal "bond", events.first["agent"]["name"]
    assert_equal "owner", events.first["trust"]
    assert_equal %w[ 11 12 ], events.drop(1).map { |e| e["id"] }
    assert_equal({ "issue_id" => 42, "comment_id" => 7 }, events.last["reply_to"])
  end

  def test_ignores_other_members_unless_trusted
    events = connect([], as_agent([ item(11, 5, "dana") ]))
    assert_equal "ignored", events.last["type"]
    assert_match "dana is not trusted", events.last["why"]

    events = connect([ "--trust", "members" ], as_agent([ item(11, 5, "dana") ]))
    assert_equal "request", events.last["type"]
  end

  def test_signed_in_as_yourself_it_sets_up_your_agent_and_listens_as_it
    you = fake_client(
      "list_my_agents" => { "signed_in_as_agent" => false, "agents" => [ { "id" => 9, "name" => "bond", "display_name" => "Bond" } ], "can_add" => false },
      "issue_my_agent_token" => { "agent" => { "id" => 9, "name" => "bond" }, "token" => "agent-tok" }
    )
    agent = as_agent([ item(11, 1, "miles") ])
    saved = []

    events = stubbing(ShapeupCli::Config, :save_profile, ->(name, **profile) { saved << [ name, profile ] }) do
      stubbing(ShapeupCli::Client, :new, ->(**) { agent }) do
        connect([], you)
      end
    end

    assert_equal 1, saved.size
    name, profile = saved.first
    assert_equal [ "bond", "agent-tok", "1" ], [ name, profile[:token], profile[:organisation_id] ]
    assert_equal "bond", events.first["profile"]
    assert_equal %w[ connected request ], events.map { |e| e["type"] }
  end

  def test_signed_in_as_yourself_without_an_agent_says_how_to_add_one
    you = fake_client("list_my_agents" => { "signed_in_as_agent" => false, "agents" => [], "can_add" => true })
    command = ShapeupCli::Commands::Connect.new([ "--once", "--org", "1" ])
    command.define_singleton_method(:client) { you }

    out, _err = capture_io do
      assert_equal ShapeupCli::EXIT_USAGE, assert_raises(SystemExit) { command.execute }.status
    end
    assert_match 'shapeup agents add \"Name\"', out
  end

  def test_help_prints_usage_instead_of_connecting
    connect = ShapeupCli::Commands::Connect
    original = connect.instance_method(:execute)
    connect.define_method(:execute) { raise "--help started connecting" }

    out, _err = capture_io { connect.run([ "--help" ]) }

    assert_match "shapeup connect: Listen for requests", out
    assert_match "--trust", out
  ensure
    connect.define_method(:execute, original)
  end

def test_rides_out_dropped_connections_and_announces_itself_once_through
  client = as_agent([ item(11, 1, "miles") ])
  dropped = Set.new
  reliable = client.method(:call_tool)
  client.define_singleton_method(:call_tool) do |name, **args|
    raise ShapeupCli::Client::NetworkError, "Couldn't reach (Errno::ECONNRESET)." if dropped.add?(name)
    reliable.call(name, **args)
  end

  command = ShapeupCli::Commands::Connect.new([ "--org", "1" ])
  command.define_singleton_method(:client) { client }
  pauses = []
  command.define_singleton_method(:pause) { |seconds| pauses << seconds; throw :stop if pauses.size == 3 }

  out, _err = capture_io { catch(:stop) { command.execute } }
  events = out.lines.map { |line| JSON.parse(line) }

  assert_equal %w[ error error connected request ], events.map { |e| e["type"] }
  assert events.first(2).all? { |e| e["retryable"] }
  assert_equal 5, events.first["retrying_in"]
  assert_equal [ 5, 30, 30 ], pauses
end

def test_once_gives_up_when_it_cannot_sign_in
  client = Object.new
  client.define_singleton_method(:call_tool) { |*, **| raise ShapeupCli::Client::NetworkError, "Couldn't reach" }

  assert_raises(ShapeupCli::Client::NetworkError) { connect([], client) }
end

def test_until_request_stops_once_a_request_is_passed_on
  events, pauses = run_until_request([ "--until-request", "--fresh" ], as_agent([ item(11, 1, "miles") ]))

  assert_equal %w[ connected request ], events.map { |e| e["type"] }
  assert_empty pauses
end

def test_until_request_remembers_what_it_handed_out_until_fresh
  inbox = as_agent([ item(11, 1, "miles") ])
  run_until_request([ "--until-request", "--fresh" ], inbox)

  events, pauses = run_until_request([ "--until-request" ], inbox)
  assert_equal %w[ connected ], events.map { |e| e["type"] }
  assert_equal [ 30 ], pauses

  events, _ = run_until_request([ "--until-request", "--fresh" ], inbox)
  assert_equal %w[ connected request ], events.map { |e| e["type"] }
end

def test_until_request_forgets_requests_that_have_left_the_inbox
  run_until_request([ "--until-request", "--fresh" ], as_agent([ item(11, 1, "miles") ]))
  run_until_request([ "--until-request" ], as_agent([]))

  assert_equal [], JSON.parse(File.read(handed_out_file))
end

  def test_rejects_an_unknown_trust_level
    assert_raises(SystemExit) do
      capture_io { ShapeupCli::Commands::Connect.new([ "--trust", "everyone", "--once" ]).execute }
    end
  end

private
  def run_until_request(argv, client)
    command = ShapeupCli::Commands::Connect.new(argv + [ "--org", "1" ])
    command.define_singleton_method(:client) { client }
    file = handed_out_file
    command.define_singleton_method(:handed_out_path) { |_agent| file }
    pauses = []
    command.define_singleton_method(:pause) { |seconds| pauses << seconds; throw :stop }

    out, _err = capture_io { catch(:stop) { command.execute } }
    [ out.lines.map { |line| JSON.parse(line) }, pauses ]
  end

  def handed_out_file
    @handed_out_file ||= File.join(Dir.mktmpdir, "connect", "bond.json")
  end

    def stubbing(object, method, value)
      original = object.method(method)
      object.define_singleton_method(method) { |*args, **kwargs, &block| value.respond_to?(:call) ? value.call(*args, **kwargs, &block) : value }
      yield
    ensure
      object.define_singleton_method(method, original)
    end
end
