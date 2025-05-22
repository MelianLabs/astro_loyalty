# frozen_string_literal: true

require 'httparty'
require 'json'
require_relative 'authentication'

module AstroLoyalty
  class Client
    include HTTParty
    include Authentication

    base_uri 'https://api.astroloyalty.com/api/json'

    attr_reader :token

    def initialize(username:, password:, client_id:)
      @username = username
      @password = password
      @client_id = client_id
      @token = fetch_token
    end

    def customer_status(customer_id:)
      post('/customerStatus/', {
        customerID: customer_id,
      })
    end

    private

    def post(path, data)
      response = self.class.post(path, {
        headers: {
          'Authorization' => "Bearer #{@token}",
          'Content-Type' => 'application/x-www-form-urlencoded',
        },
        body: {
          jsonData: data.to_json,
        },
      })

      raise AstroLoyalty::Error, "API error: #{response.message}" unless response.success?

      parsed = JSON.parse(response.body)

      unless parsed['astro_status'] == 100
        raise AstroLoyalty::Error,
          "API error: #{parsed['astro_status_messsage'] || parsed.inspect}"
      end

      parsed['returnData']
    end
  end
end
