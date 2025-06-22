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

    def remove_transaction(customer_id:, transaction_id:)
      post('/removeTransaction/', {
        customerID: customer_id,
        transactionID: transaction_id,
      })
    end

    def remove_offer_transaction(customer_id:, transaction_id:)
      post('/removeOfferTransaction/', {
        customerID: customer_id,
        transactionID: transaction_id,
      })
    end

    def add_redemption(customer_id:, astro_reward_id:, astro_item_id:)
      post('/addRedemption/', {
        customerID: customer_id,
        astro_reward_id:,
        astro_item_id:,
      })
    end

    def remove_redemption(customer_id:, astro_reward_id:)
      post('/removeRedemption/', {
        customerID: customer_id,
        astro_reward_id:,
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

      return_data = JSON.parse(response.body)['returnData']
      return_data.nil? || return_data.empty? ? {} : return_data
    end
  end
end
