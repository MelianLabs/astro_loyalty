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

    def search_customer(email_address: nil, phone: nil)
      raise ArgumentError, 'Either email_address or phone must be provided' if email_address.nil? && phone.nil?

      post('/searchCustomer/', {
        email_address:,
        phone:,
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

      JSON.parse(response.body)['returnData']
    end
  end
end
