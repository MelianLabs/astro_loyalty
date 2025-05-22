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
          headers: hash_including(
            'Authorization' => 'Bearer sample_token',
            'Content-Type' => 'application/x-www-form-urlencoded',
          ),
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
end
