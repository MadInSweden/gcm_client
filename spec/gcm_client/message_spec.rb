require 'spec_helper'

describe GcmClient::Message do

  context '#initialize' do

    it "should create new object given registration_id and a payload" do
      payload = GcmClient::Payload.new('coll_key')
      message = GcmClient::Message.new('reg_id', payload)
      message.should be_a(GcmClient::Message)
    end

  end

  pending 'should serialize to http post data'

end
