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
        :on_sent           => double('on_sent'),
        :on_temp_fail      => double('on_msg_temp_fail'),
        :on_perm_fail      => double('on_msg_perm_fail'),
        :on_not_registered => double('on_not_registered'),
        :on_canonical_id   => double('on_canonical_id'),
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
          stub.to_return(:status => 200, :body => Yajl.dump({
            :multicast_id => rand(1000), :success => reg_ids.size, :failure => 0, :canonical_ids => 0,
            :results => reg_ids.map { { :message_id => "1:#{rand(1000000)}" } }
          }))
       elsif response.is_a?(Exception)
          stub.to_raise(response)
        else
          stub.to_return(:status => response[0], :body => response[1])
        end
      end

      stub
    end

    pending "sleep a little after each error req (exponential back-off + Retry-After)"

    it 'should send messages' do
      reg_ids = 190.times.each_with_object([]) { |n, ary|  ary << "adjasodjasodjasoj#{n}" }

      reg_ids.each do |reg_id|
        @callbacks[:on_sent].should_receive(:call).once.ordered.with(@dispatcher, reg_id)
      end

      stub = stub_request_with_responses(reg_ids, :accepted)

      @dispatcher.dispatch(reg_ids, @payload)

      stub.should have_been_requested
    end

    it 'should handle canonical_ids' do
      reg_ids = 2.times.each_with_object([]) { |n, ary|  ary << "adjasodjasodjasoj#{n}" }

      canonical_id = "12i30213"
      @callbacks[:on_sent].should_receive(:call).once.ordered.with(@dispatcher, reg_ids[0])
      @callbacks[:on_canonical_id].should_receive(:call).once.ordered.with(@dispatcher, reg_ids[1], canonical_id)
      @callbacks[:on_sent].should_receive(:call).once.ordered.with(@dispatcher, reg_ids[1])

      stub = stub_request_with_responses(reg_ids, [200,
        Yajl.dump({
          :multicast_id => 123,
          :success => 2,
          :failure => 0,
          :canonical_ids => 1,
          :results => [
            { :message_id => "1:21323" }, { :message_id => "1:0408", :registration_id => canonical_id },
          ]
      })])

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
              temp_status  = [500, '']

              perm_error   = SocketError.new("Test Exception")
              perm_status  = [400, '']

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

              stub = stub_request_with_responses(reg_ids, [status, body])

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

              stub = stub_request_with_responses(reg_ids, [status, body], :accepted)

              @dispatcher.dispatch(reg_ids, @payload)

              stub.should have_been_requested.twice
            end
          end
        end

      end

      context 'on message' do

        it 'should handle gcm error "Unavailable"' do
          reg_ids = 3.times.each_with_object([]) { |n, ary|  ary << "adjasodjasodjasoj#{n}" }

          reg_ids.first(2).each do |reg_id|
            @callbacks[:on_temp_fail].should_receive(:call).once.ordered.\
              with(@dispatcher, reg_id, kind_of(GcmClient::GcmError)) do |d,rid,error|

              error.result.should == {'error' => "Unavailable"}
            end
          end
          reg_ids.last(1).each do |reg_id|
            @callbacks[:on_sent].should_receive(:call).once.ordered.\
              with(@dispatcher, reg_id)
          end
          reg_ids.first(2).first(1).each do |reg_id|
            @callbacks[:on_temp_fail].should_receive(:call).once.ordered.\
              with(@dispatcher, reg_id, kind_of(GcmClient::GcmError)) do |d,rid,error|

              error.result.should == {'error' => "Unavailable"}
            end
          end
          reg_ids.first(2).last(1).each do |reg_id|
            @callbacks[:on_sent].should_receive(:call).once.ordered.\
              with(@dispatcher, reg_id)
          end

          reg_ids.first(1).each do |reg_id|
            @callbacks[:on_temp_fail].should_receive(:call).once.ordered.\
              with(@dispatcher, reg_id, kind_of(GcmClient::GcmError)) do |d,rid,error|

              error.result.should == {'error' => "Unavailable"}
            end
          end

          reg_ids.first(1).each do |reg_id|
            @callbacks[:on_temp_fail].should_receive(:call).once.ordered.\
              with(@dispatcher, reg_id, kind_of(GcmClient::GcmError)) do |d,rid,error|

              error.result.should == {'error' => "Unavailable"}
            end
          end

          reg_ids.first(1).each do |reg_id|
            @callbacks[:on_temp_fail].should_receive(:call).once.ordered.\
              with(@dispatcher, reg_id, kind_of(GcmClient::GcmError)) do |d,rid,error|

              error.result.should == {'error' => "Unavailable"}
            end
          end

          reg_ids.first(1).each do |reg_id|
            @callbacks[:on_perm_fail].should_receive(:call).once.ordered.\
              with(@dispatcher, reg_id, kind_of(GcmClient::TooManyTempFailures))
          end

          stub0 = stub_request_with_responses(reg_ids, [200,
            Yajl.dump({
              :multicast_id => 123,
              :success => 1,
              :failure => 2,
              :canonical_ids => 0,
              :results => [
                { :error => "Unavailable" }, { :error => "Unavailable" }, { :message_id => "1:0408" },
              ]
          })])
          stub1 = stub_request_with_responses(reg_ids.first(2), [200,
            Yajl.dump({
              :multicast_id => 123,
              :success => 1,
              :failure => 1,
              :canonical_ids => 0,
              :results => [
                { :error => "Unavailable" }, { :message_id => "1:0408" },
              ]
          })])
          stub2 = stub_request_with_responses(reg_ids.first(1), [200,
            Yajl.dump({
              :multicast_id => 123,
              :success => 0,
              :failure => 1,
              :canonical_ids => 0,
              :results => [
                { :error => "Unavailable" },
              ]
          })])

          @dispatcher.dispatch(reg_ids, @payload)

          stub0.should have_been_requested
          stub1.should have_been_requested
          stub2.should have_been_requested.times(3)
        end

        it "should handle nonrecoverable gcm errors" do
          reg_ids = 8.times.each_with_object([]) { |n, ary|  ary << "adjasodjasodjasoj#{n}" }

          @callbacks[:on_sent].should_receive(:call).once.ordered.\
            with(@dispatcher, reg_ids[0])

          # Special callback for NotRegistred since they are really
          # meaningfull to host application.
          @callbacks[:on_not_registered].should_receive(:call).once.ordered.\
            with(@dispatcher, reg_ids[1])

          [ 'NotRegistered', 'MissingRegistration', 'InvalidRegistration', 'MismatchSenderId',
            'MessageTooBig', 'MissingRegistration' ].each_with_index do |err,n|
            @callbacks[:on_perm_fail].should_receive(:call).once.ordered.\
              with(@dispatcher, reg_ids[n + 1], kind_of(GcmClient::GcmError)) do |d,rid,error|

              error.result.should == { 'error' => err }
            end
          end

          @callbacks[:on_sent].should_receive(:call).once.ordered.\
            with(@dispatcher, reg_ids[7])

          stub = stub_request_with_responses(reg_ids, [200,
            Yajl.dump({
              :multicast_id => rand(1000),
              :success => 2,
              :failure => 6,
              :canonical_ids => 0,
              :results => [
                { :message_id => "1:#{rand(1000)}" },
                { :error => 'NotRegistered' },
                { :error => 'MissingRegistration' },
                { :error => 'InvalidRegistration' },
                { :error => 'MismatchSenderId' },
                { :error => 'MessageTooBig' },
                { :error => 'MissingRegistration' },
                { :message_id => "1:#{rand(1000)}" },
              ]
          })])

          @dispatcher.dispatch(reg_ids, @payload)

          stub.should have_been_requested
        end

      end

    end

  end

end
