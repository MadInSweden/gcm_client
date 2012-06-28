require 'spec_helper'

describe C2dmClient::Message do

  context '#initialize' do

    it "should create new object given registration_id and a payload" do
      payload = C2dmClient::Payload.new('coll_key')
      message = C2dmClient::Message.new('reg_id', payload)
      message.should be_a(C2dmClient::Message)
    end

  end

  pending 'should serialize to http post data'

end
