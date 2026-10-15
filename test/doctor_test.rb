# frozen_string_literal: true

require_relative "test_helper"

class DoctorTest < Minitest::Test
  def test_doctor_reports_structured_checks_and_fails_without_credentials
    ENV["SHAPEUP_PROFILE"] = "no-such-profile"
    ENV["SHAPEUP_HOST"] = "http://127.0.0.1:1"

    out, _err = capture_io do
      ShapeupCli::Commands::Doctor.run([ "--json" ])
      flunk "expected doctor to exit nonzero"
    rescue SystemExit => e
      assert_equal 1, e.status
    end

    data = JSON.parse(out)["data"]
    checks = data["checks"]

    assert checks.length >= 10
    assert(checks.all? { |c| %w[pass warn fail skip].include?(c["status"]) })

    by_name = checks.to_h { |c| [ c["name"], c ] }
    assert_equal "fail", by_name["token"]["status"]
    assert_equal "shapeup login", by_name["token"]["hint"]
    assert_equal "fail", by_name["server"]["status"]
    assert_equal "skip", by_name["auth"]["status"]
  ensure
    ENV.delete("SHAPEUP_PROFILE")
    ENV.delete("SHAPEUP_HOST")
  end

  def test_doctor_breadcrumbs_come_from_failing_checks
    ENV["SHAPEUP_PROFILE"] = "no-such-profile"
    ENV["SHAPEUP_HOST"] = "http://127.0.0.1:1"

    out, _err = capture_io do
      ShapeupCli::Commands::Doctor.run([ "--json" ])
    rescue SystemExit
    end

    breadcrumbs = JSON.parse(out)["breadcrumbs"]
    assert_includes breadcrumbs.map { |b| b["cmd"] }, "shapeup login"
  ensure
    ENV.delete("SHAPEUP_PROFILE")
    ENV.delete("SHAPEUP_HOST")
  end
  def test_agent_check_says_how_to_connect_an_agent_this_computer_has_never_used
    check = agent_check(agents: [ { "id" => 9, "name" => "bond" } ], profile: nil)

    assert_equal :warn, check.status
    assert_match "@bond isn't connected on this computer yet", check.message
    assert_equal "/shapeup-connect in Claude Code", check.hint
  end

  def test_agent_check_fails_when_the_saved_token_is_rejected
    rejecting = Object.new
    rejecting.define_singleton_method(:call_tool) { |*, **| raise ShapeupCli::Client::AuthError, "nope" }

    check = agent_check(agents: [ { "id" => 9, "name" => "bond" } ], profile: { "token" => "old" }, agent_client: rejecting)

    assert_equal :fail, check.status
    assert_match "@bond's saved token was rejected", check.message
  end

  def test_agent_check_passes_and_is_skipped_without_an_agent
    working = Object.new
    working.define_singleton_method(:call_tool) { |*, **| { "content" => [] } }

    assert_equal :pass, agent_check(agents: [ { "id" => 9, "name" => "bond" } ], profile: { "token" => "tok" }, agent_client: working).status
    assert_equal :skip, agent_check(agents: [], profile: nil).status
  end

  private
    def agent_check(agents:, profile:, agent_client: nil)
      doctor = ShapeupCli::Commands::Doctor.new([])
      you = Object.new
      you.define_singleton_method(:call_tool) do |*, **|
        { "content" => [ { "type" => "text", "text" => JSON.generate("signed_in_as_agent" => false, "agents" => agents, "can_add" => true) } ] }
      end
      doctor.define_singleton_method(:client) { you }
      doctor.instance_variable_set(:@organisations, [ { "id" => 1 } ])

      ENV["SHAPEUP_ORG"] = "1"
      with_stub(ShapeupCli::Config, :profile, profile) do
        with_stub(ShapeupCli::Client, :new, agent_client) { doctor.send(:check_agent) }
      end
    ensure
      ENV.delete("SHAPEUP_ORG")
    end

    def with_stub(object, method, value)
      original = object.method(method)
      object.define_singleton_method(method) { |*, **| value }
      yield
    ensure
      object.define_singleton_method(method, original)
    end
end
