# frozen_string_literal: true

require 'spec_helper'
require 'astro_loyalty/client'

RSpec.describe AstroLoyalty::Client do
  let(:credentials) do
    {
      username: 'test_user',
      password: 'test_pass',
      client_id: 'client_123',
    }
  end
  let(:token_response) do
    {
      access_token: 'sample_token',
      token_type: 'bearer',
      expires: '1800',
      created: Time.now.to_i.to_s,
    }.to_json
  end
  let(:client) { described_class.new(**credentials) }
  let(:headers) do
    {
      'Authorization' => 'Bearer sample_token',
      'Content-Type' => 'application/x-www-form-urlencoded',
    }
  end

  before do
    allow(described_class).to receive(:post).with(
      '/token/',
      body: {
        username: credentials[:username],
        password: credentials[:password],
        grant_type: 'password',
        client_id: credentials[:client_id],
      }
    ).and_return(double(success?: true, body: token_response))
  end

  it 'has the correct base_uri set' do
    expect(described_class.base_uri).to eq('https://api.astroloyalty.com/api/json')
  end

  describe 'authentication' do
    it 'initializes and fetches a token' do
      expect(client.token).to eq('sample_token')
    end

    context 'when the token response is unsuccessful' do
      before do
        allow(described_class).to receive(:post).and_return(double(success?: false, message: 'Unauthorized'))
      end

      it 'raises an error' do
        expect do
          client
        end.to raise_error(AstroLoyalty::Error, /Token fetch failed: Unauthorized/)
      end
    end
  end

  describe '#customer_status' do
    let(:customer_status_response) do
      {
        astro_status: 100,
        returnData: {
          customerID: '123',
          first_name: 'John',
          last_name: 'Doe',
        },
      }.to_json
    end

    before do
      allow(described_class).to receive(:post).with(
        '/customerStatus/',
        hash_including(
          headers:,
          body: hash_including(jsonData: /"customerID":"123"/),
        )
      ).and_return(double(success?: true, body: customer_status_response))
    end

    it 'returns the customer status' do
      expect(client.customer_status(customer_id: '123')).to eq(
        'customerID' => '123',
        'first_name' => 'John',
        'last_name' => 'Doe',
      )
    end
  end

  describe '#search_customer' do
    let(:search_customer_response) do
      {
        astro_status: 100,
        returnData: {
          customerID: '123',
          first_name: 'John',
          last_name: 'Doe',
          email_address: 'john@example.com',
          phone: '1234567890',
        },
      }.to_json
    end

    before do
      allow(described_class).to receive(:post).with(
        '/searchCustomer/',
        hash_including(
          headers:,
          body: hash_including(jsonData: json_data)
        )
      ).and_return(double(success?: true, body: search_customer_response))
    end

    context 'when searching by email' do
      let(:json_data) { /"email_address":"john@example\.com"/ }

      it 'returns the customer details' do
        expect(client.search_customer(email_address: 'john@example.com')).to eq(
          'customerID' => '123',
          'first_name' => 'John',
          'last_name' => 'Doe',
          'email_address' => 'john@example.com',
          'phone' => '1234567890'
        )
      end
    end

    context 'when searching by phone' do
      let(:json_data) { /"phone":"1234567890"/ }

      it 'returns the customer details' do
        expect(client.search_customer(phone: '1234567890')).to eq(
          'customerID' => '123',
          'first_name' => 'John',
          'last_name' => 'Doe',
          'email_address' => 'john@example.com',
          'phone' => '1234567890'
        )
      end
    end

    context 'when neither email nor phone is provided' do
      let(:json_data) { nil }

      it 'raises an ArgumentError' do
        expect { client.search_customer }.to raise_error(
          ArgumentError,
          'Either email_address or phone must be provided'
        )
      end
    end
  end

  describe '#link_customer' do
    let(:link_customer_response) do
      {
        status: 100,
        returnData: {
          astro_customer_id: 'astro789',
        },
      }.to_json
    end

    before do
      allow(described_class).to receive(:post).with(
        '/linkCustomer/',
        hash_including(
          headers:,
          body: hash_including(jsonData: /"customerID":"abc123"/),
        )
      ).and_return(double(success?: true, body: link_customer_response))
    end

    it 'links internal customer id to astro customer id' do
      result = client.link_customer(customer_id: 'abc123', astro_customer_id: 'astro789')

      expect(result).to be_a(Hash)
      expect(result['astro_customer_id']).to eq('astro789')
    end
  end

  describe '#add_customer' do
    let(:add_customer_response) do
      {
        status: 100,
        returnData: {
          astro_customer_id: '123456',
        },
      }.to_json
    end

    before do
      allow(described_class).to receive(:post).with(
        '/addCustomer/',
        hash_including(
          headers:,
          body: hash_including(jsonData: /"customerID":"abc123"/)
        )
      ).and_return(double(success?: true, body: add_customer_response))
    end

    it 'adds a new customer with required fields' do
      result = client.add_customer(
        customer_id: 'abc123',
        first_name: 'Jane',
        last_name: 'Doe'
      )

      expect(result).to be_a(Hash)
      expect(result['astro_customer_id']).to eq('123456')
    end
  end

  describe '#list_offers' do
    let(:astro_program_title) { 'Almo Nature |  Buy 4, Get 1 FREE on 2.47oz HQS Cat Cans' }
    let(:list_offers_response) do
      {
        astro_status: 100,
        astro_status_message: 'Success',
        returnData: {
          program_list: [
            {
              astro_mfg_id: '240',
              astro_mfg_name: 'Almo Nature',
              astro_program_id: '18564',
              astro_program_title:,
              astro_program_long_description: 'Delicious, nutritious dog food.',
              astro_program_image: 'https://api.astroloyalty.com/display_image.php?ec=z53mi3VCNs5cWyrSB%2BBsn63GJg%3D%3D',
              in_store_only: 1,
              astro_program_start_date: '2025-04-01',
              astro_program_end_date: '2025-06-30',
            },
          ],
        },
      }
    end

    before do
      allow(described_class).to receive(:post).with(
        '/listOffers/',
        hash_including(headers:)
      ).and_return(double(success?: true, body: list_offers_response.to_json))
    end

    it 'returns the list of offers' do
      result = client.list_offers
      expect(result).to be_a(Hash)
      expect(result['program_list'].first['astro_program_title']).to eq(astro_program_title)
    end
  end

  describe '#add_transaction_batch' do
    let(:expected_payload) do
      {
        customerID: 'abc123',
        transactions: [
          {
            transactionID: 'TXN-002',
            item_code: '1234567890',
            item_qty: '1',
            item_transaction_date: '2025-01-01',
          },
          {
            transactionID: 'TXN-003',
            item_code: '1234567891',
            item_qty: '2',
            item_transaction_date: '2025-01-01',
          },
        ],
      }
    end
    let(:add_transaction_batch_response) do
      {
        astro_status: 100,
        astro_status_message: 'Success',
        returnData: [
          {
            transaction_status: 100,
            transaction_status_message: "Transaction\nAdded",
            transactionID: 'TXN-002',
            astro_transaction_id: '310645666',
            astro_program_id: '1209',
            astro_program_title: "Lotus\nDOG | 20lb & 25lb Kibble LG | Official Buy 12 Get 1\nFree",
          },
          {
            transaction_status: 100,
            transaction_status_message: "Transaction\nAdded",
            transactionID: 'TXN-003',
            astro_transaction_id: '310645667',
            astro_program_id: '1209',
            astro_program_title: "Lotus\nap DOG | 20lb & 25lb Kibble LG | Official Buy 12 Get 1 Free",
          },
        ],
      }
    end

    before do
      allow(described_class).to receive(:post).with(
        '/addTransactionBatch/',
        {
          headers:,
          body: {
            jsonData: expected_payload.to_json,
          },
        }
      ).and_return(double(success?: true, body: add_transaction_batch_response.to_json))
    end

    it 'adds the transactions' do
      result = client.add_transaction_batch(
        customer_id: 'abc123',
        transactions: [
          {
            transaction_id: 'TXN-002',
            item_qty: '1',
            item_code: '1234567890',
            item_transaction_date: '2025-01-01',
          },
          {
            transaction_id: 'TXN-003',
            item_qty: '2',
            item_code: '1234567891',
            item_transaction_date: '2025-01-01',
          },
        ],
      )
      expect(result).to be_a(Array)
      expect(result.map { |txn| txn['transaction_status'] }).to eq([100, 100])
    end

    it 'validates the transactions' do
      expect do
        client.add_transaction_batch(
          customer_id: 'abc123',
          transactions: [{ transaction_id: 'TXN-002' }]
        )
      end.to raise_error(ArgumentError, /Transaction at index 0 is missing required keys: item_code/)
    end
  end

  describe '#remove_transaction' do
    let(:remove_transaction_response) do
      {
        astro_status: 100,
        astro_status_message: 'Success',
        returnData: [{ transaction_status: 100, transaction_status_message: 'Success', transactionID: 'TXN-004',
                       astro_transaction_id: '310647863', transactionDeleted: true }],
      }
    end

    before do
      allow(described_class).to receive(:post).with(
        '/removeTransaction/',
        hash_including(headers:, body: { jsonData: { customerID: 'abc123', transactionID: 'TXN-004' }.to_json })
      ).and_return(double(success?: true, body: remove_transaction_response.to_json))
    end

    it 'removes the transaction' do
      result = client.remove_transaction(customer_id: 'abc123', transaction_id: 'TXN-004')
      expect(result).to be_a(Array)
      expect(result.first['transactionDeleted']).to be(true)
    end
  end

  describe '#remove_offer_transaction' do
    let(:remove_offer_transaction_response) do
      {
        astro_status: 100,
        astro_status_message: 'Success',
        returnData: [{ transaction_status: 100, transaction_status_message: 'Success', transactionID: 'TXN-004',
                       astro_transaction_id: '310647863', transactionDeleted: true }],
      }
    end

    before do
      allow(described_class).to receive(:post).with(
        '/removeOfferTransaction/',
        hash_including(headers:, body: { jsonData: { customerID: 'abc123', transactionID: 'TXN-004' }.to_json })
      ).and_return(double(success?: true, body: remove_offer_transaction_response.to_json))
    end

    it 'removes the transaction' do
      result = client.remove_offer_transaction(customer_id: 'abc123', transaction_id: 'TXN-004')
      expect(result).to be_a(Array)
      expect(result.first['transactionDeleted']).to be(true)
    end
  end

  describe '#add_redemption' do
    let(:add_redemption_response) do
      {
        astro_status: 100,
        astro_status_message: 'Success',
      }
    end

    before do
      allow(described_class).to receive(:post).with(
        '/addRedemption/',
        hash_including(
          headers:,
          body: { jsonData: { customerID: 'abc123', astro_reward_id: '1234567890',
                              astro_item_id: '1234567891' }.to_json }
        )
      ).and_return(double(success?: true, body: add_redemption_response.to_json))
    end

    it 'adds the redemption' do
      result = client.add_redemption(customer_id: 'abc123', astro_reward_id: '1234567890', astro_item_id: '1234567891')
      expect(result).to be_a(Hash)
    end
  end

  describe '#remove_redemption' do
    let(:add_redemption_response) do
      {
        astro_status: 100,
        astro_status_message: 'Success',
      }
    end

    before do
      allow(described_class).to receive(:post).with(
        '/removeRedemption/',
        hash_including(
          headers:,
          body: { jsonData: { customerID: 'abc123', astro_reward_id: '1234567890' }.to_json }
        )
      ).and_return(double(success?: true, body: add_redemption_response.to_json))
    end

    it 'removes the redemption' do
      result = client.remove_redemption(customer_id: 'abc123', astro_reward_id: '1234567890')
      expect(result).to be_a(Hash)
    end
  end

  describe '#add_offer_transaction' do
    let(:add_offer_transaction_response) do
      {
        astro_status: 100,
        astro_status_message: 'Success',
      }
    end

    before do
      allow(described_class).to receive(:post).with(
        '/addOfferTransaction/',
        hash_including(
          headers:,
          body: { jsonData: { customerID: 'abc123', transactionID: '1234567890',
                              item_code: '123', item_qty: 1 }.to_json }
        )
      ).and_return(double(success?: true, body: add_offer_transaction_response.to_json))
    end

    it 'adds the offer transaction' do
      result = client.add_offer_transaction(customer_id: 'abc123', transaction_id: '1234567890',
        item_code: '123')
      expect(result).to be_a(Hash)
    end
  end

  describe '#add_offer_redemption' do
    let(:add_offer_redemption_response) do
      {
        astro_status: 100,
        astro_status_message: 'Success',
      }
    end

    before do
      allow(described_class).to receive(:post).with(
        '/addOfferRedemption/',
        hash_including(
          headers:,
          body: { jsonData: { customerID: 'abc123', astro_reward_id: '1234567890',
                              astro_item_id: '1234567891' }.to_json }
        )
      ).and_return(double(success?: true, body: add_offer_redemption_response.to_json))
    end

    it 'adds the offer redemption' do
      result = client.add_offer_redemption(customer_id: 'abc123', astro_reward_id: '1234567890',
        astro_item_id: '1234567891')
      expect(result).to be_a(Hash)
    end
  end

  describe '#check_redemption_eligibility' do
    let(:check_redemption_eligibility_response) do
      {
        astro_status: 100,
        astro_status_message: 'Success',
        returnData: {
          isEligible: false,
        },
      }
    end

    before do
      allow(described_class).to receive(:post).with(
        '/checkRedemptionEligibility/',
        hash_including(headers:, body: { jsonData: { customerID: 'abc123', item_code: '123' }.to_json })
      ).and_return(double(success?: true, body: check_redemption_eligibility_response.to_json))
    end

    it 'checks the redemption eligibility' do
      result = client.check_redemption_eligibility(customer_id: 'abc123', item_code: '123')
      expect(result).to be_a(Hash)
      expect(result['isEligible']).to be(false)
    end
  end
end
