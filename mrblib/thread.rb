MessagePack.register_pack_type(1, Symbol) { |sym| String(sym) }
MessagePack.register_unpack_type(1) { |data| data.to_sym }
MessagePack.register_pack_type(2, Class) { |cls| String(cls) }
MessagePack.register_unpack_type(2) { |data| data.constantize }
MessagePack.register_pack_type(3, Exception) do |exception|
  {
    class: exception.class,
    message: exception.message,
    backtrace: exception.backtrace
  }.to_msgpack
end
MessagePack.register_unpack_type(3) do |data|
  data = MessagePack.unpack(data)
  exception = data[:class].new(data[:message])
  exception.set_backtrace(data[:backtrace])
  exception
end


module LibZMQ
  class Thread_fn
    def initialize(pipe)
      @pipe = pipe
      @instances = {}
    end

    def run
      while true
        msg = MessagePack.unpack(@pipe.recv.to_str(true))
        begin
          case msg[:type]
          when :new
            instance = msg[:class].new(*msg[:args])
            @instances[instance.__id__] = instance
            LibZMQ.send(@pipe, {type: :instance, object_id: instance.__id__}.to_msgpack, 0)
          when :send
            if (instance = @instances[msg[:object_id]])
              result = instance.__send__(msg[:method], *msg[:args])
              LibZMQ.send(@pipe, {type: :result, result: result}.to_msgpack, 0)
            else
              LibZMQ.send(@pipe, {type: :exception, exception: ArgumentError.new("No such Instance")}.to_msgpack, 0)
            end
          when :async_send
            if (instance = @instances[msg[:object_id]])
              begin
                instance.__send__(msg[:method], *msg[:args])
              rescue => e
                puts e.inspect
              end
            end
          end
        rescue => e
          LibZMQ.send(@pipe, {type: :exception, exception: e}.to_msgpack, 0)
        end
      end
    end
  end
end

module ZMQ
  class Actor
    def initialize(*args, &block)
    end

    def new(mrb_class, *args)
      if block_given?
        raise ArgumentError, "blocks cannot be migrated"
      end
      LibZMQ.send(@pipe, {type: :new, class: mrb_class, args: args}.to_msgpack, 0)
      msg = MessagePack.unpack(@pipe.recv.to_str(true))
      case msg[:type]
      when :instance
        Proxy.new(self, msg[:object_id])
      when :exception
        raise msg[:exception]
      end
    end

    def send(object_id, method, *args)
      LibZMQ.send(@pipe, {type: :send, object_id: object_id, method: method, args: args}.to_msgpack, 0)
      msg = MessagePack.unpack(@pipe.recv.to_str(true))
      case msg[:type]
      when :result
        msg[:result]
      when :exception
        raise msg[:exception]
      end
    end

    def async_send(object_id, method, *args)
      LibZMQ.send(@pipe, {type: :async_send, object_id: object_id, method: method, args: args}.to_msgpack, 0)
    end
  end

  class Proxy
    attr_reader :object_id

    def initialize(thread, object_id)
      @thread = thread
      @object_id = object_id
    end

    def send(m, *args)
      if block_given?
        raise ArgumentError, "blocks cannot be migrated"
      end
      @thread.send(@object_id, m, *args)
    end

    def send(m, *args)
      if block_given?
        raise ArgumentError, "blocks cannot be migrated"
      end
      @thread.async_send(@object_id, m, *args)
    end

    def respond_to?(m)
      super(m) || @thread.send(@object_id, :respond_to?, m)
    end
  end
end
