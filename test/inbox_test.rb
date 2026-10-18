# frozen_string_literal: true

require_relative "test_helper"

class InboxTest < Minitest::Test
  def test_start_passes_the_item_and_status_to_the_server
    calls = inbox([ "start", "812", "--status", "Taking screenshots" ])

    assert_equal [ [ "start_inbox_item", { organisation: "1", item: "812", status: "Taking screenshots" } ] ], calls
  end

  def test_start_without_a_status_keeps_the_current_one
    calls = inbox([ "start", "812" ])

    assert_equal [ [ "start_inbox_item", { organisation: "1", item: "812" } ] ], calls
  end

  private
    def inbox(argv)
      calls = []
      client = Object.new
      client.define_singleton_method(:call_tool) do |name, **args|
        calls << [ name, args ]
        { "content" => [ { "type" => "text", "text" => "{}" } ] }
      end

      command = ShapeupCli::Commands::Inbox.new(argv + [ "--org", "1", "--json" ])
      command.define_singleton_method(:client) { client }
      capture_io { command.execute }
      calls
    end
end
