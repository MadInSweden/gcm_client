require 'spec_helper'

describe GcmClient::Dispatcher do

  context '#initialize' do

    it "should create new object given api_key" do
      dispatcher = GcmClient::Dispatcher.new('api_key')
      dispatcher.should be_a(GcmClient::Dispatcher)
    end

  end

  it 'should send single message' do
    api_key = 'asdasjodajsdo'
    reg_ids = ['asdjaosdjasod']

    on_sent_callback = stub(:on_sent_callback)
    on_sent_callback.should_receive(:call).with(reg_ids)

    payload = GcmClient::Payload.new(:a => 'b')
    dispatcher = GcmClient::Dispatcher.new(api_key, :on_sent => on_sent_callback)

    stub = stub_request(:post, "https://android.googleapis.com/gcm/send").with(
      :body => payload.json_for_registration_ids(reg_ids),
      :headers => { 'Content-Type' => 'application/json', 'Authorization' => "key=#{api_key}" }
    )

    dispatcher.dispatch(reg_ids, payload)

    stub.should have_been_requested
  end

  it 'should send multiple messages' do
    api_key = 'asdasjodajsdo'
    reg_ids = 1000.times.each_with_object([]) { |n, ary|  ary << "adjasodjasodjasoj#{n}" }

    on_sent_callback = stub(:on_sent_callback)
    on_sent_callback.should_receive(:call).with(reg_ids)

    payload = GcmClient::Payload.new(:a => 'b')
    dispatcher = GcmClient::Dispatcher.new(api_key, :on_sent => on_sent_callback)

    stub = stub_request(:post, "https://android.googleapis.com/gcm/send").with(
      :body => payload.json_for_registration_ids(reg_ids),
      :headers => { 'Content-Type' => 'application/json', 'Authorization' => "key=#{api_key}" }
    )

    dispatcher.dispatch(reg_ids, payload)

    stub.should have_been_requested
  end

  pending 'should handle reqs larger than 1000 messages'

  pending 'should handle initial authentication while sending'
  pending 'should handle errors when authenticating'

  pending 'should handle http protocol errors while sending'
  pending 'should handle ssl protocol errors while sending'
  pending 'should handle network errors while sending'
  pending 'should handle response error codes while sending'
  pending 'should handle http 401 (auth) errors while sending'
  pending 'should handle http 503 (retry later) errors while sending'

  pending 'it should implement nifty logging'

end
