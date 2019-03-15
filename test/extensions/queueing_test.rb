require_relative '../test_helper'

class QueuingTest < MiniTest::Unit::TestCase
  class TestClient < TestService::Client
    def echo(message)
      message
    end
  end

  # Must have a constant name to work with sidekiq
  class QueuedClient < Thrifter.build(TestClient)
    include Thrifter::Queueing

    self.config.uri = 'tcp://localhost:9090'

    def custom_echo
      echo TestMessage.new(message: 'custom')
    end
  end

  def queue
    Thrifter::Queueing::Job
  end

  def jobs
    queue.jobs
  end

  def setup
    queue.clear
  end

  def test_queues_methods_with_sidekiq
    client = QueuedClient.new

    message = TestMessage.new message: 'echo'

    client.queued.echo(message)

    refute jobs.empty?, 'Nothing enqueued'

    # Now mock out an instance of QueuedClient that should be
    # instantiated and used to make the RPC in the job
    mock_client = mock
    mock_client.expects(:echo).with do |rpc|
      # NOTE: Thrift structs do not implement equality on attributes, only
      # on object identity. This is why the expectation tests the
      # message is sent all the way through.
      rpc.message == message.message
    end

    QueuedClient.stubs(:new).returns(mock_client)

    queue.drain
  end

  def test_works_with_block_form
    client = QueuedClient.new

    message = TestMessage.new message: 'echo'

    client.queued do |queue|
      queue.echo message
    end

    refute jobs.empty?, 'Nothing enqueued'
  end

  def test_fails_if_given_unknown_method
    client = QueuedClient.new

    assert_raises NoMethodError do
      client.queued.foo
    end
  end
end
