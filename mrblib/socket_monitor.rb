module ZMQ
  class Socket
    class Monitor
      Events = {
        LibZMQ::EVENT_CONNECTED => :connected,
        LibZMQ::EVENT_CONNECT_DELAYED => :connect_delayed,
        LibZMQ::EVENT_CONNECT_RETRIED => :connect_retried,
        LibZMQ::EVENT_LISTENING => :listening,
        LibZMQ::EVENT_BIND_FAILED => :bind_failed,
        LibZMQ::EVENT_ACCEPTED => :accepted,
        LibZMQ::EVENT_ACCEPT_FAILED => :accept_failed,
        LibZMQ::EVENT_CLOSED => :closed,
        LibZMQ::EVENT_CLOSE_FAILED => :close_failed,
        LibZMQ::EVENT_DISCONNECTED => :disconnected,
        LibZMQ::EVENT_MONITOR_STOPPED => :monitor_stopped
      }
      if LibZMQ.const_defined?("EVENT_HANDSHAKE_FAILED")
        Events[LibZMQ::EVENT_HANDSHAKE_FAILED] = :handshake_failed
        Events[LibZMQ::EVENT_HANDSHAKE_SUCCEED] = :handshake_succeed
      end

      # this is a helper for ZMQ::Poller so you can add a object which looks like a zmq socket to be added more easily
      attr_reader :zmq_socket

      def initialize(endpoint)
        @zmq_socket = ZMQ::Pair.new(endpoint)
      end

      def recv
        msg = @zmq_socket.recv
        event, value = msg[0].to_str(true).unpack('SL')
        {event: Events[event], value: value, endpoint: msg[1].to_str}
      end
    end
  end
end
