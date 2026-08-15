# frozen_string_literal: true

module ShapeupCli
  class Client
    class ApiError < StandardError; end
    class AuthError < ApiError; end
    class NotFoundError < ApiError; end
    class PermissionError < ApiError; end
    class RateLimitError < ApiError; end

    MCP_PROTOCOL_VERSION = "2025-06-18"

    def initialize(host: Config.host, token: Auth.token)
      raise AuthError, "Not authenticated" unless token
      @host = host
      @token = token
      @request_id = 0
    end

    # Call an MCP tool by name with arguments. The only method the CLI uses —
    # the MCP session/introspection/resource calls were never wired up.
    def call_tool(name, **arguments)
      call_method("tools/call", name: name, arguments: arguments)
    end

    private
      def call_method(method, **params)
        @request_id += 1

        uri = URI.parse("#{@host}/mcp")
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        request["Authorization"] = "Bearer #{@token}"
        request["MCP-Protocol-Version"] = MCP_PROTOCOL_VERSION
        request["X-Shapeup-Agent"] = agent_hint

        body = {
          jsonrpc: "2.0",
          id: @request_id,
          method: method
        }
        body[:params] = params unless params.empty?
        request.body = JSON.generate(body)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 5
        http.read_timeout = 30

        response = with_network_error_handling { http.request(request) }
        handle_response(response)
      end

      # Declare who is driving so the server can attribute agent work honestly
      # ("tapster and Claude") and keep human-typed commands attributed to the
      # human alone. Agent harnesses mark their sessions with an env var.
      AGENT_ENV_HINTS = { "CLAUDECODE" => "claude", "CODEX_THREAD_ID" => "codex" }.freeze

      def agent_hint
        AGENT_ENV_HINTS.each do |variable, hint|
          return hint unless ENV[variable].to_s.empty?
        end
        "none"
      end

      def with_network_error_handling
        yield
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise ApiError, "The server took too long to respond. Please try again."
      rescue SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::ETIMEDOUT => e
        raise ApiError, "Couldn't reach #{@host} (#{e.class}). Check your connection and 'shapeup config show'."
      end

      def handle_response(response)
        case response.code.to_i
        when 401 then raise AuthError, "Authentication failed — run 'shapeup login'"
        when 403 then raise PermissionError, "Check your subscription or permissions"
        when 429 then raise RateLimitError, "Too many requests — slow down and retry"
        when 200..299 then nil
        else raise ApiError, "The server returned an error (HTTP #{response.code})."
        end

        parsed = parse_json(response.body)

        if parsed["error"]
          message = parsed["error"]["message"] || "Unknown error"

          case message
          when /not found/i  then raise NotFoundError, message
          when /access/i     then raise PermissionError, message
          else raise ApiError, message
          end
        end

        parsed["result"]
      end

      def parse_json(body)
        JSON.parse(body.to_s)
      rescue JSON::ParserError
        raise ApiError, "The server returned an unreadable response."
      end
  end
end
