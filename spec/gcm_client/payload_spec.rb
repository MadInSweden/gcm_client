require 'spec_helper'

describe GcmClient::Payload do

  context '#initialize' do

    it "should create new object given data array" do
      payload = GcmClient::Payload.new({})
      payload.should be_a(GcmClient::Payload)
    end

  end

  context '#json_for_registration_ids' do

    it "should return a json hash with registration ids and data (all keys and values converted to String instances) " do
      payload = GcmClient::Payload.new({})
      Yajl.load(payload.json_for_registration_ids([1,2,3])).should == {
        'registration_ids' => ['1', '2', '3'],
        'data' => {}
      }

      payload = GcmClient::Payload.new({:haj => 1327, :hoj => :idg})
      Yajl.load(payload.json_for_registration_ids([1,2,3])).should == {
        'registration_ids' => ['1', '2', '3'],
        'data' => {
          'haj' => '1327',
          'hoj' => 'idg'
        }
      }
    end

  end

  pending "should validate size of payload"

  pending "should serialize data to HTTP POST data"

end
