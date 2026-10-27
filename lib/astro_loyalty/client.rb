# frozen_string_literal: true

require 'httparty'
require 'json'
require_relative 'authentication'

module AstroLoyalty
  class Client
    include HTTParty
    include Authentication

    base_uri 'https://api.astroloyalty.com/api/json'

    # Astro reports the application-level outcome in the response envelope, not the HTTP status.
    ASTRO_STATUS_KEY = 'astro_status'
    ASTRO_STATUS_MESSAGE_KEY = 'astro_status_message'
    ASTRO_STATUS_SUCCESS = 100

    attr_reader :token

    # True when a response Astro answered with is an application-level success. Callers need this
    # for the endpoints that return no returnData, where the envelope status is the whole answer.
    def self.success?(result)
      return true unless result.is_a?(Hash) && result.key?(ASTRO_STATUS_KEY)

      result[ASTRO_STATUS_KEY].to_i == ASTRO_STATUS_SUCCESS
    end

    # refresh_expired_token: on an Invalid Token envelope, get a new token and retry the call once.
    # token_refresher: optional callable given the rejected token; a token it returns is used
    #   instead of fetching one (e.g. a newer token another process already cached), nil fetches.
    # on_token_refresh: optional callable told path:, token: and result: after each retry.
    def initialize(username:, password:, client_id:, token: nil, refresh_expired_token: false, # rubocop:disable Metrics/ParameterLists
                   token_refresher: nil, on_token_refresh: nil)
      @username = username
      @password = password
      @client_id = client_id
      @refresh_expired_token = refresh_expired_token
      @token_refresher = token_refresher
      @on_token_refresh = on_token_refresh
      @token = token || fetch_token
    end

    def customer_status(customer_id:)
      post('/customerStatus/', {
        customerID: customer_id,
      })
    end

    def customer_reward_status(customer_id:)
      post('/customerRewardStatus/', {
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

    def link_customer(customer_id:, astro_customer_id:)
      post('/linkCustomer/', {
        customerID: customer_id,
        astro_customer_id:,
      })
    end

    # Supported attributes: email_address, address, city, state, zip, phone
    def add_customer(customer_id:, first_name:, last_name:, **attributes)
      payload = {
        customerID: customer_id,
        first_name:,
        last_name:,
      }.merge(attributes)

      post('/addCustomer/', payload)
    end

    def list_offers
      post('/listOffers/', {})
    end

    def add_offer_transaction(customer_id:, transaction_id:, item_code:, item_qty: 1)
      post('/addOfferTransaction/', {
        customerID: customer_id,
        transactionID: transaction_id,
        item_code:,
        item_qty:,
      })
    end

    def add_transaction_batch(customer_id:, transactions:)
      required_keys = %i[transaction_id item_code]
      transactions.each_with_index do |txn, index|
        raise ArgumentError, "Transaction at index #{index} must be a Hash" unless txn.is_a?(Hash)

        missing = required_keys - txn.keys.map(&:to_sym)

        unless missing.empty?
          raise ArgumentError, "Transaction at index #{index} is missing required keys: #{missing.join(', ')}"
        end
      end

      post('/addTransactionBatch/', {
        customerID: customer_id,
        transactions: transactions.map do |txn|
          {
            transactionID: txn[:transaction_id],
            item_code: txn[:item_code],
            item_qty: txn[:item_qty],
            item_transaction_date: txn[:item_transaction_date],
          }
        end,
      })
    end

    def remove_transaction(customer_id:, transaction_id:, quantity: nil)
      payload = {
        customerID: customer_id,
        transactionID: transaction_id,
      }
      payload[:item_qty] = quantity if quantity
      post('/removeTransaction/', payload)
    end

    def remove_offer_transaction(customer_id:, transaction_id:)
      post('/removeOfferTransaction/', {
        customerID: customer_id,
        transactionID: transaction_id,
      })
    end

    # Some manufacturer programs refuse a redemption without the customer's email (status 720) or
    # address (710); the rest accept it without them, so only the details given are sent.
    def add_redemption(customer_id:, astro_reward_id:, astro_item_id:, customer_email_address: nil, # rubocop:disable Metrics/ParameterLists
                       customer_address: nil, customer_city: nil, customer_state: nil, customer_zip: nil)
      customer_details = { customer_email_address:, customer_address:, customer_city:, customer_state:,
                           customer_zip: }.compact
      post('/addRedemption/', {
        customerID: customer_id,
        astro_reward_id:,
        astro_item_id:,
      }.merge(customer_details))
    end

    def remove_redemption(customer_id:, astro_reward_id:)
      post('/removeRedemption/', {
        customerID: customer_id,
        astro_reward_id:,
      })
    end

    def add_offer_redemption(customer_id:, astro_reward_id:, astro_item_id:, customer_email_address:, # rubocop:disable Metrics/ParameterLists
                             customer_address:, customer_city:, customer_state:, customer_zip:)
      post('/addOfferRedemption/', {
        customerID: customer_id,
        astro_reward_id:,
        astro_item_id:,
        customer_email_address:,
        customer_address:,
        customer_city:,
        customer_state:,
        customer_zip:,
      })
    end

    def check_redemption_eligibility(customer_id:, item_code:)
      post('/checkRedemptionEligibility/', {
        customerID: customer_id,
        item_code:,
      })
    end

    private

    def post(path, data)
      result = request(path, data)
      return result unless @refresh_expired_token && invalid_token?(result)

      new_token = refreshed_token
      return result if new_token.nil?

      @token = new_token
      retried = request(path, data)
      @on_token_refresh&.call(path:, token: new_token, result: retried)
      retried
    end

    def request(path, data)
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

      extract_return_data(JSON.parse(response.body))
    end

    # Astro answers HTTP 200 for application-level failures too, carrying the real outcome in
    # astro_status / astro_status_message. Endpoints like /addOfferTransaction/, /addRedemption/
    # and /addOfferRedemption/ send no returnData at all, so collapsing an empty returnData to {}
    # threw away the only signal they give — a rejected write was indistinguishable from an
    # accepted one. Fall back to the envelope status instead of {}.
    def extract_return_data(body)
      return_data = body['returnData']
      return return_data unless return_data.nil? || return_data.empty?

      body.slice(ASTRO_STATUS_KEY, ASTRO_STATUS_MESSAGE_KEY)
    end
  end
end
