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
      memory['last_status'].to_i > 0

      return false if recent_error_logs?
      
      if interpolated['expected_receive_period_in_days'].present?
        return false unless last_receive_at && last_receive_at > interpolated['expected_receive_period_in_days'].to_i.days.ago
      end

      true
    end

    def check
      handle interpolated[:wallet_address]
    end

    private

    def handle(wallet)


        uri = URI.parse("https://api.tzstats.com/explorer/account/#{wallet}?")
        request = Net::HTTP::Get.new(uri)
        request["Authority"] = "api.tzstats.com"
        request["Cache-Control"] = "max-age=0"
        request["Upgrade-Insecure-Requests"] = "1"
        
        req_options = {
          use_ssl: uri.scheme == "https",
        }

        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end
        
        log response.code

        parsed_json = JSON.parse(response.body)
        payload = { 'crypto' => "XTZ", 'address' => parsed_json["address"], 'value' => parsed_json["total_balance"] }

        if interpolated['changes_only'] == 'true'
          if payload.to_s != memory['last_status']
            memory['last_status'] = payload.to_s
            create_event payload: payload
          end
        else
          create_event payload: payload
          if payload.to_s != memory['last_status']
            memory['last_status'] = payload.to_s
          end
        end
    end
  end
end
