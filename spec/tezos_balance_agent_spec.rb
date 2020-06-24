require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::TezosBalanceAgent do
  before(:each) do
    @valid_options = Agents::TezosBalanceAgent.new.default_options
    @checker = Agents::TezosBalanceAgent.new(:name => "TezosBalanceAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
