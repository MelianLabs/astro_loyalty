# AstroLoyalty

A Ruby wrapper for the [Astro Loyalty](https://www.astroloyalty.com) REST API.

## Installation

This gem is not published to RubyGems.org. Install it from git by adding it to your application's Gemfile:

```ruby
gem 'astro_loyalty', git: 'git@github.com:MelianLabs/astro_loyalty.git'
```

And then execute:

    $ bundle install

## Usage

Create a client with your Astro Loyalty credentials. A token is fetched automatically on initialization:

```ruby
client = AstroLoyalty::Client.new(
  username: 'username',
  password: 'password',
  client_id: 'client_id'
)
```

### Customers

```ruby
# Search for a customer by email address and/or phone
client.search_customer(email_address: 'pet.parent@example.com')
client.search_customer(phone: '5555555555')

# Add a customer (optional attributes: email_address, address, city, state, zip, phone)
client.add_customer(customer_id: '123', first_name: 'Jane', last_name: 'Doe', email_address: 'pet.parent@example.com')

# Link your customer ID to an existing Astro customer
client.link_customer(customer_id: '123', astro_customer_id: '456')

# Fetch a customer's status and reward status
client.customer_status(customer_id: '123')
client.customer_reward_status(customer_id: '123')
```

### Transactions

```ruby
# Add a single offer transaction
client.add_offer_transaction(customer_id: '123', transaction_id: 'txn_1', item_code: 'SKU123', item_qty: 1)

# Add a batch of transactions (each requires transaction_id and item_code;
# item_qty and item_transaction_date are optional)
client.add_transaction_batch(
  customer_id: '123',
  transactions: [
    { transaction_id: 'txn_1', item_code: 'SKU123', item_qty: 2 },
    { transaction_id: 'txn_2', item_code: 'SKU456' },
  ]
)

# Remove transactions
client.remove_transaction(customer_id: '123', transaction_id: 'txn_1', quantity: 1)
client.remove_offer_transaction(customer_id: '123', transaction_id: 'txn_1')
```

### Offers and redemptions

```ruby
# List available offers
client.list_offers

# Check whether a customer is eligible to redeem an item
client.check_redemption_eligibility(customer_id: '123', item_code: 'SKU123')

# Add or remove a redemption
client.add_redemption(customer_id: '123', astro_reward_id: '789', astro_item_id: '101')
# Programs that require the customer's email or address refuse the redemption without them (status 720/710)
client.add_redemption(customer_id: '123', astro_reward_id: '789', astro_item_id: '101',
                      customer_email_address: 'jane@example.com')
client.remove_redemption(customer_id: '123', astro_reward_id: '789')

# Add an offer redemption (requires the customer's contact details)
client.add_offer_redemption(
  customer_id: '123',
  astro_reward_id: '789',
  astro_item_id: '101',
  customer_email_address: 'pet.parent@example.com',
  customer_address: '123 Main St',
  customer_city: 'San Francisco',
  customer_state: 'CA',
  customer_zip: '94105'
)
```

### Handling responses

Methods return the API's `returnData` when present. The Astro API reports application-level failures with an HTTP 200 and an `astro_status` envelope, and some endpoints (e.g. `addOfferTransaction`, `addRedemption`, `addOfferRedemption`) return no `returnData` at all — in those cases the envelope status is returned instead. Use `AstroLoyalty::Client.success?` to check the outcome:

```ruby
result = client.add_redemption(customer_id: '123', astro_reward_id: '789', astro_item_id: '101')

if AstroLoyalty::Client.success?(result)
  # redemption accepted
else
  result['astro_status_message'] # reason for the failure
end
```

An `AstroLoyalty::Error` is raised when the API responds with a non-2xx HTTP status.

### Expired tokens

A token is fetched once, when the client is built. Astro answers a call made with an expired or revoked token with HTTP 200 and `astro_status` 250 "Invalid Token". Pass `refresh_expired_token: true` to have the client get a new token and retry that call once; a second 250 is returned as is. If the new token cannot be fetched, the original 250 is returned rather than raising.

```ruby
client = AstroLoyalty::Client.new(
  username: 'your_username',
  password: 'your_password',
  client_id: 'your_client_id',
  token: cached_token,                                   # optional: skip the token request
  refresh_expired_token: true,
  token_refresher: ->(rejected_token) { newer_cached_token_or_nil(rejected_token) }, # optional
  on_token_refresh: ->(path:, token:, result:) { cache_token(token) },                # optional
)
```

`token_refresher` is given the rejected token and may return a newer one (for example a token another process already cached); returning `nil` fetches a new token. `on_token_refresh` is called after each retry with the request path, the new token and the retried call's result.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
