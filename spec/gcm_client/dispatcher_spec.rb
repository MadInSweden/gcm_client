require 'spec_helper'

describe GcmClient::Dispatcher do

  context '#initialize' do

    it "should create new object given api_key" do
      dispatcher = GcmClient::Dispatcher.new('api_key')
      dispatcher.should be_a(GcmClient::Dispatcher)
    end

    it "should set timeouts on HttpClient instance" do
      dispatcher = GcmClient::Dispatcher.new('api_key')
      dispatcher.http.connect_timeout.should    == 30
      dispatcher.http.send_timeout.should       == 30
      dispatcher.http.receive_timeout.should    == 30
      dispatcher.http.keep_alive_timeout.should == 15
    end

  end

  context '#dispatch' do
    before(:each) do
      @api_key = 'asdasjodajsdo'

      @callbacks = {
        :on_sent => double('on_sent'),
        :on_temp_fail => double('on_msg_temp_fail'),
        :on_perm_fail => double('on_msg_perm_fail'),
      }

      @payload = GcmClient::Payload.new(:a => 'b')
      @dispatcher = GcmClient::Dispatcher.new(@api_key, @callbacks)
    end

    def stub_request_with_responses(reg_ids, *responses)
      stub = stub_request(:post, "https://android.googleapis.com/gcm/send").with(
        :body => @payload.json_for_registration_ids(reg_ids),
        :headers => { 'Content-Type' => 'application/json', 'Authorization' => "key=#{@api_key}" }
      )
      responses.each do |response|
        stub = if response == :accepted
          stub.to_return(:status => 200)
       elsif response.is_a?(Exception)
          stub.to_raise(response)
        else
          stub.to_return(:status => response[0], :body => response[1], :headers => response[2])
        end
      end

      stub
    end

    pending 'should implement nifty logging'
    pending 'should handle canonical_ids'
    pending "sleep a little after each error req"

    it 'should send messages' do
      reg_ids = 190.times.each_with_object([]) { |n, ary|  ary << "adjasodjasodjasoj#{n}" }

      reg_ids.each do |reg_id|
        @callbacks[:on_sent].should_receive(:call).once.ordered.with(@dispatcher, reg_id)
      end

      stub = stub_request_with_responses(reg_ids, :accepted)

      @dispatcher.dispatch(reg_ids, @payload)

      stub.should have_been_requested
    end

    context 'integration test', :integration => true do

    it 'should send more than 1000 messages in batches' do
      reg_ids = 1500.times.each_with_object([]) { |n, ary|  ary << "adjasodjasodjasoj#{n}" }

      reg_ids.each do |reg_id|
        @callbacks[:on_sent].should_receive(:call).once.ordered.with(@dispatcher, reg_id)
      end

      stub0 = stub_request_with_responses(reg_ids.first(1000), :accepted)
      stub1 = stub_request_with_responses(reg_ids.last(500), :accepted)

      @dispatcher.dispatch(reg_ids, @payload)

      stub0.should have_been_requested
      stub1.should have_been_requested
    end

    end

    context 'errors' do

      context 'on request' do

        context 'integration test', :integration => true do

          it "should handle a combination of different errors and successes and limit max number of temp errors" do
              reg_ids = 5000.times.each_with_object([]) { |n, ary|  ary << "adjasodjasodjasoj#{n}" }.\
                             each_slice(1000).to_a

              temp_error   = HTTPClient::BadResponseError.new("Test Exception")
              temp_status  = [500, '', {}]

              perm_error   = SocketError.new("Test Exception")
              perm_status  = [400, '', {}]

              # First batch, temp_error, temp_status, success
              stub0  = stub_request_with_responses(reg_ids[0], temp_error, temp_status, :accepted)

              # Second batch, temp_error, temp_status, temp_error, temp_status, temp_error -> perm_fail
              stub1  = stub_request_with_responses(reg_ids[1], temp_error, temp_status, temp_error, temp_status, temp_error)

              # Third perm_error
              stub2  = stub_request_with_responses(reg_ids[2], perm_error)

              # Fourth temp_status, perm_status
              stub3  = stub_request_with_responses(reg_ids[3], temp_status, perm_status)

              # Fifth success
              stub4  = stub_request_with_responses(reg_ids[4], :accepted)

              # Callbacks
              reg_ids[0].each do |reg_id|
                @callbacks[:on_temp_fail].should_receive(:call).once.ordered.with(@dispatcher, reg_id, temp_error)
              end
              reg_ids[1].each do |reg_id|
                @callbacks[:on_temp_fail].should_receive(:call).once.ordered.with(@dispatcher, reg_id, temp_error)
              end
              reg_ids[2].each do |reg_id|
                @callbacks[:on_perm_fail].should_receive(:call).once.ordered.with(@dispatcher, reg_id, perm_error)
              end
              reg_ids[3].each do |reg_id|
                @callbacks[:on_temp_fail].should_receive(:call).once.ordered.with(@dispatcher, reg_id, kind_of(GcmClient::HTTPError))
              end
              reg_ids[4].each do |reg_id|
                @callbacks[:on_sent].should_receive(:call).once.ordered.with(@dispatcher, reg_id)
              end

              reg_ids[0].each do |reg_id|
                @callbacks[:on_temp_fail].should_receive(:call).once.ordered.with(@dispatcher, reg_id, kind_of(GcmClient::HTTPError))
              end
              reg_ids[1].each do |reg_id|
                @callbacks[:on_temp_fail].should_receive(:call).once.ordered.with(@dispatcher, reg_id, kind_of(GcmClient::HTTPError))
              end
              reg_ids[3].each do |reg_id|
                @callbacks[:on_perm_fail].should_receive(:call).once.ordered.with(@dispatcher, reg_id, kind_of(GcmClient::HTTPError))
              end

              reg_ids[0].each do |reg_id|
                @callbacks[:on_sent].should_receive(:call).once.ordered.with(@dispatcher, reg_id)
              end
              reg_ids[1].each do |reg_id|
                @callbacks[:on_temp_fail].should_receive(:call).once.ordered.with(@dispatcher, reg_id, temp_error)
              end

              reg_ids[1].each do |reg_id|
                @callbacks[:on_temp_fail].should_receive(:call).once.ordered.with(@dispatcher, reg_id, kind_of(GcmClient::HTTPError))
              end

              reg_ids[1].each do |reg_id|
                @callbacks[:on_temp_fail].should_receive(:call).once.ordered.with(@dispatcher, reg_id, temp_error)
                @callbacks[:on_perm_fail].should_receive(:call).once.ordered.with(@dispatcher, reg_id, kind_of(GcmClient::TooManyTempFailures))
              end

              @dispatcher.dispatch(reg_ids.flatten, @payload)

              stub0.should have_been_requested.times(3)
              stub1.should have_been_requested.times(5)
              stub2.should have_been_requested.times(1)
              stub3.should have_been_requested.times(2)
              stub4.should have_been_requested.times(1)
          end

        end

        context 'non recoverable' do
          [SocketError, SystemCallError, RuntimeError].each do |eklass|
            it "should fail messages for #{eklass}" do
              reg_ids = 50.times.each_with_object([]) { |n, ary|  ary << "adjasodjasodjasoj#{n}" }
              error   = eklass.new("Test Exception")

              reg_ids.each do |reg_id|
                @callbacks[:on_perm_fail].should_receive(:call).once.ordered.with(@dispatcher, reg_id, error)
              end

              stub = stub_request_with_responses(reg_ids, error)

              @dispatcher.dispatch(reg_ids, @payload)

              stub.should have_been_requested
            end
          end

          [400,401].each do |status|
            it "should raise error for HTTP #{status} errors" do
              reg_ids = 50.times.each_with_object([]) { |n, ary|  ary << "adjasodjasodjasoj#{n}" }
              body = "Failed to comply with stuff"

              reg_ids.each do |reg_id|
                @callbacks[:on_perm_fail].should_receive(:call).once.ordered.\
                  with(@dispatcher, reg_id, kind_of(GcmClient::HTTPError)) do |d, rid, error|
                  error.response.status.should == status
                  error.response.body.should == body
                end
              end

              stub = stub_request_with_responses(reg_ids, [status, body,{}])

              @dispatcher.dispatch(reg_ids, @payload)

              stub.should have_been_requested
            end
          end

        end

        context 'recoverable' do
          [
            HTTPClient::BadResponseError,
            HTTPClient::TimeoutError,
            OpenSSL::SSL::SSLError,
            Errno::ETIMEDOUT,
            Errno::EADDRNOTAVAIL
          ].each do |eklass|
            it "should handle #{eklass} errors" do
              reg_ids = 50.times.each_with_object([]) { |n, ary|  ary << "adjasodjasodjasoj#{n}" }
              error   = eklass.new("Test Exception")

              reg_ids.each do |reg_id|
                @callbacks[:on_temp_fail].should_receive(:call).once.ordered.with(@dispatcher, reg_id, error)
              end
              reg_ids.each do |reg_id|
                @callbacks[:on_sent].should_receive(:call).once.ordered.with(@dispatcher, reg_id)
              end

              stub = stub_request_with_responses(reg_ids, error, :accepted)

              @dispatcher.dispatch(reg_ids, @payload)

              stub.should have_been_requested.twice
            end
          end

          [500,503].each do |status|
            it "should handle HTTP #{status} errors" do
              reg_ids = 50.times.each_with_object([]) { |n, ary|  ary << "adjasodjasodjasoj#{n}" }
              body = "Timed out or something"

              reg_ids.each do |reg_id|
                @callbacks[:on_temp_fail].should_receive(:call).once.ordered.\
                  with(@dispatcher, reg_id, kind_of(GcmClient::HTTPError)) do |d, rid, error|
                  error.response.status.should == status
                  error.response.body.should == body
                end
              end
              reg_ids.each do |reg_id|
                @callbacks[:on_sent].should_receive(:call).once.ordered.with(@dispatcher, reg_id)
              end

              stub = stub_request_with_responses(reg_ids, [status, body, {}], :accepted)

              @dispatcher.dispatch(reg_ids, @payload)

              stub.should have_been_requested.twice
            end
          end
        end

      end

      context 'on message' do

        context 'recoverable' do
          pending 'Unavailable'
        end

        context 'non recoverable' do
          pending 'NotRegistered'
          pending 'MissingRegistration'
          pending 'InvalidRegistration'
          pending 'MismatchSenderId'
          pending 'MessageTooBig'
          pending 'MissingRegistration'
          pending 'MessageFailedToManyTimes (internal)'
        end

      end

    end

  end

end
