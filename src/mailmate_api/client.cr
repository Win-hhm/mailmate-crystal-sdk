module MailMate
  # Thin wrapper around the generated MailMateAPI client.
  # Manages DeviseTokenAuth headers and rotates tokens after each response.
  #
  # Usage:
  #   creds = MailMate::Credentials.load
  #   client = MailMate::Client.new(creds)
  #   inboxes = client.inboxes.get_inboxes
  class Client
    getter credentials : Credentials

    def initialize(@credentials : Credentials)
      @config = build_config
    end

    def self.from_credentials_file : Client
      new(Credentials.load)
    end

    # API accessors — each returns a generated API class pre-configured with auth
    def auth_api : MailMateAPI::AuthApi
      MailMateAPI::AuthApi.new(api_client)
    end

    def inboxes_api : MailMateAPI::InboxesApi
      MailMateAPI::InboxesApi.new(api_client)
    end

    def items_api : MailMateAPI::ItemsApi
      MailMateAPI::ItemsApi.new(api_client)
    end

    # Call after every response to rotate tokens (DeviseTokenAuth requirement —
    # tokens change on each request; storing stale tokens causes 401s).
    def update_tokens(headers : HTTP::Headers) : Nil
      if (token = headers["access-token"]?)
        @credentials = Credentials.new(
          access_token: token,
          client_id: headers.fetch("client", @credentials.client_id),
          uid: headers.fetch("uid", @credentials.uid),
          base_url: @credentials.base_url
        )
        @credentials.save
        @config = build_config
      end
    end

    private def api_client : MailMateAPI::ApiClient
      MailMateAPI::ApiClient.new(@config)
    end

    private def build_config : MailMateAPI::Configuration
      config = MailMateAPI::Configuration.new
      config.base_path = @credentials.base_url
      config.api_key["access-token"] = @credentials.access_token
      config.api_key["client"] = @credentials.client_id
      config.api_key["uid"] = @credentials.uid
      config
    end
  end
end
