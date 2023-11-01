module Agents
  class TezosBalanceAgent < Agent
    include FormConfigurable
    can_dry_run!
    no_bulk_receive!
    default_schedule "never"

    description do
      <<-MD
      The tezos balance agent fetches tezos's balance from tezos explorer

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "value": xxxx,
              ...
            "crypto": "XTZ"
          }
    MD

    def default_options
      {
        'wallet_address' => '',
        'expected_receive_period_in_days' => '2',
        'changes_only' => 'true'
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :wallet_address, type: :string
    form_configurable :changes_only, type: :boolean

    def validate_options
      unless options['wallet_address'].present?
        errors.add(:base, "wallet_address is a required field")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      handle interpolated[:wallet_address]
    end

    private

    def handle(wallet)

      uri = URI.parse("https://api.tzkt.io/v1/accounts/#{wallet}/balance")
      response = Net::HTTP.get_response(uri)
      
      log response.code

      payload = JSON.parse(response.body)
      event = { 'crypto' => "XTZ", 'address' => wallet, 'value' => "#{payload}" }

      if interpolated['changes_only'] == 'true'
        if payload != memory['last_status']
          create_event payload: event
          memory['last_status'] = payload
        end
      else
        create_event payload: event
        if payload != memory['last_status']
          memory['last_status'] = payload
        end
      end
    end
  end
end
