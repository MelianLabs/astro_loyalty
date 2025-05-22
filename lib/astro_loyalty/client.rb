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
  end
end
