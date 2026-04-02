# frozen_string_literal: true

require_relative "test_helper"

class ExitCodesTest < Minitest::Test
  def test_exit_code_constants_defined
    assert_equal 0, ShapeupCli::EXIT_OK
    assert_equal 1, ShapeupCli::EXIT_USAGE
    assert_equal 2, ShapeupCli::EXIT_NOT_FOUND
    assert_equal 3, ShapeupCli::EXIT_AUTH
    assert_equal 4, ShapeupCli::EXIT_PERMISSION
    assert_equal 5, ShapeupCli::EXIT_API_ERROR
    assert_equal 6, ShapeupCli::EXIT_RATE_LIMIT
    assert_equal 130, ShapeupCli::EXIT_INTERRUPTED
  end

  def test_error_class_hierarchy
    assert ShapeupCli::Client::AuthError < ShapeupCli::Client::ApiError
    assert ShapeupCli::Client::NotFoundError < ShapeupCli::Client::ApiError
    assert ShapeupCli::Client::PermissionError < ShapeupCli::Client::ApiError
    assert ShapeupCli::Client::RateLimitError < ShapeupCli::Client::ApiError
  end
end
