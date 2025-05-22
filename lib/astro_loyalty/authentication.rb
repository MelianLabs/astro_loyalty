# frozen_string_literal: true

module AstroLoyalty
  module Authentication
    # TODO: Add handling for expired tokens
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
  end
end
