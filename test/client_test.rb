# frozen_string_literal: true

require_relative "test_helper"

class ClientTest < Minitest::Test
  Response = Struct.new(:code, :body)

  def setup
    @client = ShapeupCli::Client.new(host: "https://example.test", token: "tok")
  end

  def handle(code, body)
    @client.send(:handle_response, Response.new(code.to_s, body))
  end

  def test_success_returns_the_result
    assert_equal({ "ok" => true }, handle(200, JSON.generate(result: { ok: true })))
  end

  def test_server_error_with_html_body_raises_ApiError_not_a_parse_error
    error = assert_raises(ShapeupCli::Client::ApiError) do
      handle(500, "<html><body>502 Bad Gateway</body></html>")
    end
    refute_kind_of JSON::ParserError, error
    assert_match(/500/, error.message)
  end

  def test_empty_body_raises_a_clean_error
    assert_raises(ShapeupCli::Client::ApiError) { handle(200, "") }
  end

  def test_status_codes_map_to_typed_errors
    assert_raises(ShapeupCli::Client::AuthError) { handle(401, "") }
    assert_raises(ShapeupCli::Client::PermissionError) { handle(403, "") }
    assert_raises(ShapeupCli::Client::RateLimitError) { handle(429, "") }
  end

  def test_jsonrpc_error_maps_to_typed_error
    body = JSON.generate(error: { message: "Package not found (id: 9)" })
    assert_raises(ShapeupCli::Client::NotFoundError) { handle(200, body) }
  end

  def test_network_failures_become_ApiError
    assert_raises(ShapeupCli::Client::ApiError) do
      @client.send(:with_network_error_handling) { raise Net::OpenTimeout }
    end
    assert_raises(ShapeupCli::Client::ApiError) do
      @client.send(:with_network_error_handling) { raise Errno::ECONNREFUSED }
    end
  end
end
