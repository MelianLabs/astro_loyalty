# frozen_string_literal: true

module AstroLoyalty
  module Authentication
    INVALID_TOKEN = 250

    def fetch_token
      response = self.class.post('/token/', body: {
        username: @username,
        password: @password,
        grant_type: 'password',
        client_id: @client_id,
      })

      raise AstroLoyalty::Error, "Token fetch failed: #{response.message}" unless response.success?

      JSON.parse(response.body)['access_token']
    end

    private

    # A refresh that cannot get a token hands back the original rejection, as a client without
    # refresh would, instead of raising out of a call that was answered.
    def refreshed_token
      @token_refresher&.call(@token) || fetch_token
    rescue AstroLoyalty::Error, HTTParty::Error, SocketError, Timeout::Error, SystemCallError,
           OpenSSL::SSL::SSLError, JSON::ParserError
      nil
    end

    def invalid_token?(result)
      result.is_a?(Hash) && result[Client::ASTRO_STATUS_KEY].to_i == INVALID_TOKEN
    end
  end
end
