# frozen_string_literal: true

require 'spec_helper'
require 'astro_loyalty/client'

RSpec.describe AstroLoyalty::Client do
  let(:credentials) { { username: 'test_user', password: 'test_pass', client_id: 'client_123' } }
  let(:token_body) do
    { username: 'test_user', password: 'test_pass', grant_type: 'password', client_id: 'client_123' }
  end
  let(:invalid_token) do
    double(success?: true, body: { astro_status: 250, astro_status_message: 'Invalid Token' }.to_json)
  end
  let(:status_ok) do
    double(success?: true, body: { astro_status: 100, returnData: { customerID: '123' } }.to_json)
  end

  def token_response(token)
    double(success?: true, body: { access_token: token }.to_json)
  end

  def stub_customer_status(token, response)
    allow(described_class).to receive(:post).
      with('/customerStatus/', hash_including(headers: hash_including('Authorization' => "Bearer #{token}"))).
      and_return(response)
  end

  before do
    allow(described_class).to receive(:post).with('/token/', body: token_body).
      and_return(token_response('fresh_token'))
  end

  describe 'initialization' do
    it 'uses a token passed in without fetching one' do
      client = described_class.new(**credentials, token: 'cached_token')

      expect(client.token).to eq('cached_token')
      expect(described_class).not_to have_received(:post).with('/token/', anything)
    end

    it 'fetches a token when none is passed in' do
      client = described_class.new(**credentials, token: nil)

      expect(client.token).to eq('fresh_token')
    end
  end

  context 'when refresh_expired_token is off' do
    it 'returns the Invalid Token envelope without fetching a new token' do
      stub_customer_status('stale_token', invalid_token)
      client = described_class.new(**credentials, token: 'stale_token')

      result = client.customer_status(customer_id: '123')

      expect(result).to eq('astro_status' => 250, 'astro_status_message' => 'Invalid Token')
      expect(described_class).not_to have_received(:post).with('/token/', anything)
    end
  end

  context 'when refresh_expired_token is on' do
    let(:refreshes) { [] }
    let(:client) do
      described_class.new(**credentials, token: 'stale_token', refresh_expired_token: true,
        on_token_refresh: ->(**event) { refreshes << event })
    end

    it 'fetches a new token on Invalid Token and retries the call once' do
      stub_customer_status('stale_token', invalid_token)
      stub_customer_status('fresh_token', status_ok)

      result = client.customer_status(customer_id: '123')

      expect([result, client.token]).to eq([{ 'customerID' => '123' }, 'fresh_token'])
    end

    it 'reports the refresh with the path and the retried result' do
      stub_customer_status('stale_token', invalid_token)
      stub_customer_status('fresh_token', status_ok)

      client.customer_status(customer_id: '123')

      expect(refreshes).to eq([{ path: '/customerStatus/', token: 'fresh_token', result: { 'customerID' => '123' } }])
    end

    it 'returns a second Invalid Token as is, without another refresh' do
      stub_customer_status('stale_token', invalid_token)
      stub_customer_status('fresh_token', invalid_token)

      result = client.customer_status(customer_id: '123')

      expect([result['astro_status'], refreshes.size]).to eq([250, 1])
    end

    it 'leaves other statuses alone' do
      refused = double(success?: true, body: { astro_status: 310, astro_status_message: 'No Customer Found' }.to_json)
      stub_customer_status('stale_token', refused)

      result = client.customer_status(customer_id: '123')

      expect(result['astro_status']).to eq(310)
      expect(described_class).not_to have_received(:post).with('/token/', anything)
    end

    it 'leaves array responses alone' do
      batch = double(success?: true,
        body: { astro_status: 100, returnData: [{ transaction_status: 250 }] }.to_json)
      stub_customer_status('stale_token', batch)

      result = client.customer_status(customer_id: '123')

      expect(result).to eq([{ 'transaction_status' => 250 }])
      expect(described_class).not_to have_received(:post).with('/token/', anything)
    end

    it 'returns the original Invalid Token envelope when the new token cannot be fetched' do
      stub_customer_status('stale_token', invalid_token)
      allow(described_class).to receive(:post).with('/token/', body: token_body).
        and_return(double(success?: false, message: 'Unauthorized'))

      result = client.customer_status(customer_id: '123')

      expect([result['astro_status'], client.token, refreshes]).to eq([250, 'stale_token', []])
    end

    it 'returns the original Invalid Token envelope when the token request times out' do
      stub_customer_status('stale_token', invalid_token)
      allow(described_class).to receive(:post).with('/token/', body: token_body).and_raise(Net::ReadTimeout)

      result = client.customer_status(customer_id: '123')

      expect(result).to eq('astro_status' => 250, 'astro_status_message' => 'Invalid Token')
    end

    context 'with a token_refresher' do
      it 'uses the token it returns instead of fetching one' do
        stub_customer_status('stale_token', invalid_token)
        stub_customer_status('shared_token', status_ok)
        client = described_class.new(**credentials, token: 'stale_token', refresh_expired_token: true,
          token_refresher: ->(stale_token) { 'shared_token' if stale_token == 'stale_token' })

        expect(client.customer_status(customer_id: '123')).to eq('customerID' => '123')
        expect(described_class).not_to have_received(:post).with('/token/', anything)
      end

      it 'fetches a token when it returns nil' do
        stub_customer_status('stale_token', invalid_token)
        stub_customer_status('fresh_token', status_ok)
        client = described_class.new(**credentials, token: 'stale_token', refresh_expired_token: true,
          token_refresher: ->(_stale_token) {})

        client.customer_status(customer_id: '123')

        expect(described_class).to have_received(:post).with('/token/', body: token_body).once
      end
    end
  end
end
