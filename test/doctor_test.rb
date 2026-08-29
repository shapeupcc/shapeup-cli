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
end
