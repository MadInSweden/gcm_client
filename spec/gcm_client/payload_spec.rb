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

  context '#bytesize' do
    it 'should return bytesize of payload json' do
      GcmClient::Payload.new({'a' => 'a'*2040}).bytesize.should == 2048
      GcmClient::Payload.new({'aaa' => 'a'*40}).bytesize.should == 50

    end
  end


  it 'should limit the size of payload json to 2048 bytes (service supports 4Kb)' do
    GcmClient::Payload.new({'a' => 'a'*2040})

    lambda { GcmClient::Payload.new({'a' => 'a'*2041}) }.should raise_error(GcmClient::PayloadTooLarge) do |e|
      e.data.should == {'a' => 'a'*2041}
      e.bytesize.should == 2049
    end
  end

end
