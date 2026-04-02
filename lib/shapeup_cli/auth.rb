# frozen_string_literal: true

module ShapeupCli
  module Auth
    CLIENT_NAME = "ShapeUp CLI"

    # OAuth 2.1 PKCE login flow:
    # 1. Discover OAuth metadata from /.well-known/oauth-authorization-server
    # 2. Dynamically register client (loopback redirect)
    # 3. Start local callback server
    # 4. Open browser for authorisation
    # 5. Receive code on callback
    # 6. Exchange code for token via PKCE

    def self.login(host: Config.host)
      metadata = discover_metadata(host)
      callback_port = find_available_port
      redirect_uri = "http://127.0.0.1:#{callback_port}/callback"

      client = register_client(metadata["registration_endpoint"], redirect_uri)
      code_verifier = generate_code_verifier
      code_challenge = generate_code_challenge(code_verifier)
      state = SecureRandom.hex(16)

      auth_url = build_auth_url(
        metadata["authorization_endpoint"],
        client_id: client["client_id"],
        redirect_uri: redirect_uri,
        code_challenge: code_challenge,
        state: state
      )

      puts "Opening browser for authentication..."
      puts "If the browser doesn't open, visit:"
      puts "  #{auth_url}"
      puts

      open_browser(auth_url)

      code = wait_for_callback(callback_port, state)

      token_response = exchange_code(
        metadata["token_endpoint"],
        code: code,
        client_id: client["client_id"],
        redirect_uri: redirect_uri,
        code_verifier: code_verifier
      )

      token_response
    end

    def self.token
      Config.token
    end

    # --- Private helpers ---

    def self.discover_metadata(host)
      uri = URI.parse("#{host}/.well-known/oauth-authorization-server")
      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        raise Client::ApiError, "Failed to discover OAuth metadata at #{host}"
      end

      JSON.parse(response.body)
    end

    def self.register_client(endpoint, redirect_uri)
      uri = URI.parse(endpoint)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(
        client_name: CLIENT_NAME,
        redirect_uris: [ redirect_uri ],
        token_endpoint_auth_method: "none",
        grant_types: [ "authorization_code" ],
        response_types: [ "code" ],
        scope: "read write"
      )

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise Client::ApiError, "Failed to register OAuth client: #{response.body}"
      end

      JSON.parse(response.body)
    end

    def self.build_auth_url(endpoint, client_id:, redirect_uri:, code_challenge:, state:)
      uri = URI.parse(endpoint)
      uri.query = URI.encode_www_form(
        response_type: "code",
        client_id: client_id,
        redirect_uri: redirect_uri,
        code_challenge: code_challenge,
        code_challenge_method: "S256",
        scope: "write",
        state: state
      )
      uri.to_s
    end

    def self.exchange_code(endpoint, code:, client_id:, redirect_uri:, code_verifier:)
      uri = URI.parse(endpoint)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request.body = URI.encode_www_form(
        grant_type: "authorization_code",
        code: code,
        client_id: client_id,
        redirect_uri: redirect_uri,
        code_verifier: code_verifier
      )

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise Client::ApiError, "Token exchange failed: #{response.body}"
      end

      JSON.parse(response.body)
    end

    def self.wait_for_callback(port, expected_state)
      server = TCPServer.new("127.0.0.1", port)
      client = server.accept

      # Read the HTTP request
      request_line = client.gets
      headers = {}
      while (line = client.gets) && line.strip != ""
        key, value = line.split(": ", 2)
        headers[key.downcase] = value&.strip
      end

      # Parse query params from GET /callback?code=...&state=...
      path, query_string = request_line.split(" ")[1].split("?", 2)
      params = URI.decode_www_form(query_string || "").to_h

      code = nil
      error = nil

      if params["error"]
        error = params["error_description"] || params["error"]
        body = "<html><body><h1>Authentication failed</h1><p>#{error}</p><p>You can close this tab.</p></body></html>"
      elsif params["state"] != expected_state
        error = "State mismatch"
        body = "<html><body><h1>Authentication failed</h1><p>State mismatch.</p></body></html>"
      else
        code = params["code"]
        body = "<html><body><h1>Authenticated!</h1><p>You can close this tab and return to the terminal.</p></body></html>"
      end

      client.print "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}"
      client.close
      server.close

      raise Client::ApiError, "Authentication failed: #{error}" if error
      raise Client::ApiError, "No authorization code received" unless code

      code
    end

    def self.generate_code_verifier
      SecureRandom.urlsafe_base64(32)
    end

    def self.generate_code_challenge(verifier)
      digest = Digest::SHA256.digest(verifier)
      Base64.urlsafe_encode64(digest, padding: false)
    end

    def self.find_available_port
      server = TCPServer.new("127.0.0.1", 0)
      port = server.addr[1]
      server.close
      port
    end

    def self.open_browser(url)
      case RUBY_PLATFORM
      when /darwin/  then system("open", url)
      when /linux/   then system("xdg-open", url)
      when /mswin|mingw/ then system("start", url)
      end
    end

    private_class_method :discover_metadata, :register_client, :build_auth_url,
      :exchange_code, :wait_for_callback, :generate_code_verifier,
      :generate_code_challenge, :find_available_port, :open_browser
  end
end
