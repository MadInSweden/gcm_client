require 'spec_helper'

describe C2dmClient::Dispatcher do

  context '#initialize' do

    it "should create new object given username and password" do
      dispatcher = C2dmClient::Dispatcher.new('user', 'password')
      dispatcher.should be_a(C2dmClient::Dispatcher)
    end

  end

  pending 'should send single message'

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
