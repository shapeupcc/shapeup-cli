# frozen_string_literal: true

require_relative "test_helper"

class ExitCodesTest < Minitest::Test
  def test_exit_codes_match_the_shared_basecamp_family_rubric
    assert_equal 0, ShapeupCli::EXIT_OK
    assert_equal 1, ShapeupCli::EXIT_USAGE
    assert_equal 2, ShapeupCli::EXIT_NOT_FOUND
    assert_equal 3, ShapeupCli::EXIT_AUTH
    assert_equal 4, ShapeupCli::EXIT_PERMISSION
    assert_equal 5, ShapeupCli::EXIT_RATE_LIMIT
    assert_equal 6, ShapeupCli::EXIT_NETWORK
    assert_equal 7, ShapeupCli::EXIT_API_ERROR
    assert_equal 8, ShapeupCli::EXIT_AMBIGUOUS
    assert_equal 130, ShapeupCli::EXIT_INTERRUPTED
  end

  def test_error_class_hierarchy
    assert ShapeupCli::Client::AuthError < ShapeupCli::Client::ApiError
    assert ShapeupCli::Client::NotFoundError < ShapeupCli::Client::ApiError
    assert ShapeupCli::Client::PermissionError < ShapeupCli::Client::ApiError
    assert ShapeupCli::Client::RateLimitError < ShapeupCli::Client::ApiError
    assert ShapeupCli::Client::NetworkError < ShapeupCli::Client::ApiError
  end

  def test_machine_output_gets_a_retryable_error_envelope
    envelope = capture_failure(machine: true) do
      ShapeupCli.fail_with "Rate limited.", code: "rate_limit", exit_code: 5, retryable: true, hint: "Wait"
    end

    assert_equal false, envelope["ok"]
    assert_equal "rate_limit", envelope["code"]
    assert_equal true, envelope["retryable"]
    assert_equal "Wait", envelope["hint"]
  end

  def test_human_output_gets_plain_text_on_stderr
    out, err, status = run_failure(machine: false) do
      ShapeupCli.fail_with "Not found: pitch 9", code: "not_found", exit_code: 2, retryable: false
    end

    assert_empty out
    assert_includes err, "Not found: pitch 9"
    assert_equal 2, status
  end

  private
    def capture_failure(machine:, &block)
      out, _err, _status = run_failure(machine: machine, &block)
      JSON.parse(out)
    end

    def run_failure(machine:)
      ShapeupCli.instance_variable_set(:@machine_output, machine)
      out, err = capture_io do
        yield
        flunk "expected fail_with to exit"
      rescue SystemExit => e
        @status = e.status
      end
      [ out, err, @status ]
    end
end
