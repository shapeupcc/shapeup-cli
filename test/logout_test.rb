# frozen_string_literal: true

require_relative "test_helper"

class LogoutTest < Minitest::Test
  PROFILES = {
    "you" => { "token" => "oauth-tok", "host" => "https://shapeup.cc", "revocable" => true },
    "bond" => { "token" => "agent-tok", "host" => "https://shapeup.cc", "revocable" => true },
    "pasted" => { "token" => "pasted-tok", "host" => "https://shapeup.cc" }
  }.freeze

  def setup
    @revoked = []
    @cleared = false
  end

  def test_logout_revokes_signed_in_and_agent_tokens_and_forgets_pasted_ones
    out = logout(PROFILES)

    assert_equal [ "oauth-tok", "agent-tok" ], @revoked
    assert @cleared
    assert_includes out, "Revoked 'you'"
    assert_includes out, "Forgot 'pasted' on this machine"
    assert_includes out, "Logged out."
  end

  def test_a_failed_revocation_is_reported_and_the_logout_still_happens
    out = logout(PROFILES.slice("you"), revoke: ->(**) { raise ShapeupCli::Client::ApiError, "HTTP 500" })

    assert @cleared
    assert_includes out, "Couldn't revoke 'you' on https://shapeup.cc (HTTP 500)"
  end

  def test_logging_out_with_nothing_stored
    out = logout({})

    refute @cleared
    assert_equal "Not logged in.\n", out
  end

  def test_auth_remove_revokes_before_deleting
    deleted = []
    out, _err = stubbing(ShapeupCli::Config, :profile, PROFILES["bond"]) do
      stubbing(ShapeupCli::Config, :delete_profile, ->(name) { deleted << name }) do
        stubbing(ShapeupCli::Auth, :revoke, ->(token:, **) { @revoked << token }) do
          capture_io { ShapeupCli::Commands::Auth.run([ "remove", "bond" ]) }
        end
      end
    end

    assert_equal [ "agent-tok" ], @revoked
    assert_equal [ "bond" ], deleted
    assert_includes out, "Revoked 'bond'"
  end

  private
    def logout(profiles, revoke: ->(token:, **) { @revoked << token })
      out, _err = stubbing(ShapeupCli::Config, :profiles, profiles) do
        stubbing(ShapeupCli::Config, :clear_credentials, -> { @cleared = true }) do
          stubbing(ShapeupCli::Auth, :revoke, revoke) do
            capture_io { ShapeupCli::Commands::Logout.run([]) }
          end
        end
      end
      out
    end

    def stubbing(object, method, value)
      original = object.method(method)
      object.define_singleton_method(method) { |*args, **kwargs, &block| value.respond_to?(:call) ? value.call(*args, **kwargs, &block) : value }
      yield
    ensure
      object.define_singleton_method(method, original)
    end
end
