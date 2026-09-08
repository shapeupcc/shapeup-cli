# frozen_string_literal: true

require_relative "test_helper"

class LoginTest < Minitest::Test
  ORGS = [ { "id" => 1, "name" => "Acme" }, { "id" => 2, "name" => "Beta Corp" } ].freeze

  def setup
    @saved = []
  end

  def test_non_interactive_login_with_several_orgs_keeps_the_token
    out, _err = login([], orgs: ORGS, tty: false)

    assert_equal 1, @saved.length
    name, profile = @saved.first
    assert_equal "shapeup-cc", name
    assert_equal "tok", profile[:token]
    assert_nil profile[:organisation_id]
    assert_includes out, "no organisation is set yet"
    assert_includes out, "shapeup config set org"
  end

  def test_org_flag_selects_by_name_case_insensitively
    login([ "--org", "beta corp" ], orgs: ORGS, tty: false)

    name, profile = @saved.first
    assert_equal "beta-corp", name
    assert_equal 2, profile[:organisation_id]
  end

  def test_org_flag_selects_by_id
    login([ "--org=1" ], orgs: ORGS, tty: false)

    assert_equal "acme", @saved.first.first
  end

  def test_unknown_org_flag_still_saves_the_token_and_exits_usage
    _out, err = login([ "--org", "Nope" ], orgs: ORGS, tty: false)

    assert_equal ShapeupCli::EXIT_USAGE, @status
    assert_includes err, "Organisation 'Nope' not found"
    assert_equal "tok", @saved.first.last[:token]
  end

  def test_single_org_is_chosen_automatically
    login([], orgs: [ ORGS.first ], tty: false)

    assert_equal 1, @saved.first.last[:organisation_id]
  end

  def test_an_invalid_interactive_choice_still_saves_the_token
    stubbing($stdin, :gets, "9\n") do
      login([], orgs: ORGS, tty: true)
    end

    _name, profile = @saved.first
    assert_equal "tok", profile[:token]
    assert_nil profile[:organisation_id]
  end

  private
    def login(args, orgs:, tty:)
      client = Object.new
      client.define_singleton_method(:call_tool) { |*| { "content" => [ { "type" => "text", "text" => JSON.generate("organisations" => orgs) } ] } }

      saved = @saved
      stubbing(ShapeupCli::Auth, :login, { "access_token" => "tok" }) do
        stubbing(ShapeupCli::Client, :new, client) do
          stubbing(ShapeupCli::Config, :host, "https://shapeup.cc") do
            stubbing(ShapeupCli::Config, :save_profile, ->(name, **profile) { saved << [ name, profile ] }) do
              stubbing(ShapeupCli::Config, :switch_profile, nil) do
                stubbing($stdin, :tty?, tty) do
                  capture_io do
                    ShapeupCli::Commands::Login.run(args)
                  rescue SystemExit => e
                    @status = e.status
                  end
                end
              end
            end
          end
        end
      end
    end

    def stubbing(object, method, value)
      original = object.method(method)
      object.define_singleton_method(method) { |*args, **kwargs, &block| value.respond_to?(:call) ? value.call(*args, **kwargs, &block) : value }
      yield
    ensure
      object.define_singleton_method(method, original)
    end
end
