require 'spec_helper'

describe GcmClient::Payload do

  context '#initialize' do

    it "should create new object given collapse_key and data array" do
      payload = GcmClient::Payload.new('asd', {})
      payload.should be_a(GcmClient::Payload)
    end

    it "should create new object given collapse_key" do
      payload = GcmClient::Payload.new('asd')
      payload.should be_a(GcmClient::Payload)
    end

  end

  context '#to_hash' do

    it "should return a hash with collapse_key if no data hash is given" do
      payload = GcmClient::Payload.new('asd')

      payload.to_hash.should == {
        'collapse_key' => 'asd'
      }
    end

    it "should return a hash with collapse_key and data hash items" do
      payload = GcmClient::Payload.new('asd', {
        'text' => 'Call me later..',
        'sound' => 'call.m4a'
      })

      payload.to_hash.should == {
        'collapse_key' => 'asd',
        'data.text'    => 'Call me later..',
        'data.sound'   => 'call.m4a'
      }
    end

    it "should convert all keys & values to strings" do
      payload = GcmClient::Payload.new(37, :test => :foo)

      payload.to_hash.should == {
        'collapse_key' => '37',
        'data.test'    => 'foo'
      }
    end

    it "should return a frozen hash" do
      payload = GcmClient::Payload.new('test')
      payload.to_hash.should be_frozen
    end

  end

  pending "should validate size of payload"

  pending "should serialize data to HTTP POST data"

end
