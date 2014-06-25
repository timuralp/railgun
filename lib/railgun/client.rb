require 'socket'
require 'thread'

module Railgun
  # Implementation of a client for the Nailgun server
  # (https://github.com/martylamb/nailgun)
  class Client

    DEFAULT_PORT = 2113
    CHUNK_HEADER_LEN = 5

    # All of the Nailgun message types.
    NAILGUN_MESSAGE_TYPES = { argument:    'A',
                              command:     'C',
                              current_dir: 'D',
                              environment: 'E',
                              eof:         '.',
                              exit:        'X',
                              heartbeat:   'H',
                              longarg:     'L',
                              sendinput:   'S',
                              stderr:      '2',
                              stdin:       '0',
                              stdout:      '1',
                            }

    # We need the inverted map when deconstructing messages
    NAILGUN_MESSAGE_MAP = NAILGUN_MESSAGE_TYPES.invert

    KNOWN_SERVER_MESSAGES = [ :stdout, :stderr, :exit, :sendinput ]

    # Periodic notification to the server that we are still alive
    HEARTBEAT_TIMEOUT = 0.5

    Header = Struct.new(:type, :length)
    class Header
      HEADER_FORMAT = 'L>a'

      def pack
        header = [length, NAILGUN_MESSAGE_TYPES[type]]
        header.pack(HEADER_FORMAT)
      end

      def self.unpack(message)
        length, type = message.unpack(HEADER_FORMAT)
        type = NAILGUN_MESSAGE_MAP[type]
        Header.new(type, length)
      end
    end

    # Represents each message in the Nailgun protocol
    Message = Struct.new(:header, :message)

    # Used to wrap the results of an invocation
    Result = Struct.new(:out, :err, :exitcode)

    class UnknownMessageError < RuntimeError
    end

    # Public: Create a new nailgun client. The client is not connected
    # initially.
    #
    # @option options [Integer] :port The port for the nailgun server (2113 by
    #                                 default).
    # @option options [String] :host The host for the nailgun server (default -
    #                                localhost).
    #
    # @return [Railgun::Client] The client object.
    def initialize(options = {})
      @port = options.fetch(:port, DEFAULT_PORT)
      @host = options.fetch(:host, 'localhost')

      # The mutex is used to prevent the writes from the heartbeat and main
      # thread from happening at the same time to the socket.
      @socket_lock = Mutex.new
      @socket = nil
      @heartbeat_thread = nil
    end

    # Public: Execute an arbitrary command against the nailgun server. Will
    # connect if the client is not currently connected.
    #
    # @param command [String] The command to execute. This must be a Java class,
    #                         e.g. com.railgun.HelloWorld.
    #
    # @option options [Array<String>] :args Arguments to pass to the command.
    #
    # @return [Railgun::Client::Result] The result of execution with stdout,
    #                                   stderr, and the exit code available.
    def execute(command, options = {})
      @socket_lock.synchronize { connect if @socket.nil? }

      pass_arguments(options.fetch(:args, []))

      # Pass the context for the command execution
      setup_environment
      setup_current_dir

      # Pass the command to execute
      write_message_safe("#{command}", :command)

      # Retrieve the response to the command that was executed
      wait_for_exit
    end

    # Public: Close the connection to the nailgun server.
    #
    # @return [void]
    def close
      @socket_lock.synchronize do
        @socket.close if @socket
        @socket = nil
        @heartbeat_thread.terminate if @heartbeat_thread
      end
      if @heartbeat_thread
        @heartbeat_thread.join
        @heartbeat_thread = nil
      end
    end

    # Public: Connect to the nailgun server.
    #
    # @return [void]
    def connect
      @socket_lock.synchronize do
        return unless @socket.nil?

        @socket = Socket.new(Socket::AF_INET, Socket::SOCK_STREAM)
        @socket.connect(Socket.pack_sockaddr_in(port, host))

        # We need to start the heartbeat thread at this point as well
        @heartbeat_thread = Thread.new(self) { |client| client.heartbeat_loop }
      end
    end

    # Public: The heartbeat looping method. This is only made public so that we
    # can invoke it from another thread on the client.
    #
    # @return [void]
    def heartbeat_loop
      while true
        @socket_lock.synchronize {
          return if @socket.nil? or @socket.closed?
          write_message('', :heartbeat)
        }
        sleep(HEARTBEAT_TIMEOUT)
      end
    end

    private

    # Private: Reads all messages from the server until the exit message is
    # received.
    #
    # @return [Railgun::Client::Result] The result of the execution.
    def wait_for_exit
      out = []
      err = []
      while true
        msg = read_message
        case msg.header.type
          when :stdout
            out << msg.message
          when :stderr
            err << msg.message
          when :exit
            return Result.new(out.join, err.join, msg.message.to_i)
        end
      end
    end

    # Private: Pass an array of arguments to the nailgun server.
    #
    # @return [void]
    def pass_arguments(args)
      args.each { |arg| write_message_safe(arg, :argument) }
    end

    # Private: Pass the current environment to the nailgun server.
    #
    # @return [void]
    def setup_environment
      write_message_safe("NAILGUN_FILESEPARATOR=#{File::SEPARATOR}",
                         :environment)
      write_message_safe("NAILGUN_PATHSEPARATOR=#{File::PATH_SEPARATOR}",
                         :environment)

      ENV.each { |key, value|
        write_message_safe("#{key}=#{value}", :environment)
      }
    end

    # Private: Pass the current working directory to the nailgun server.
    #
    # @return [void]
    def setup_current_dir
      write_message_safe(Dir.pwd, :current_dir)
    end

    # Private: Read a nailgun message from the server.
    #
    # @return [Railgun::Client::Message] The nailgun message.
    #
    # @raise [Railgun::Client::UnknownMessageError] If the message is not one of
    # the expected types (Railgun::Client::KNOWN_SERVER_MESSAGES).
    def read_message
      @socket_lock.synchronize do
        header = Header.unpack(@socket.read(CHUNK_HEADER_LEN))
        if not KNOWN_SERVER_MESSAGES.include?(header.type)
          raise UnknownMessageError.new("Unknown message type: #{header.type}")
        end

        msg = @socket.read(header.length)
        return Message.new(header, msg)
      end
    end

    # Private: Write a message of a given type to the socket. This method is
    # *NOT* thread safe and if two threads use the same socket, an external
    # mutex *MUST* be used.
    #
    # @param message [String] The message to write out.
    # @param type [Symbol] The type of the message (from NAILGUN_MESSAGE_TYPES)
    #
    # @return [void]
    def write_message(message, type)
      @socket.write(Header.new(type, message.length).pack)
      @socket.write(message) if message.length > 0
    end

    # Private: Write a message of a given type to the socket. This is method is
    # thread safe and does ensure only one writer to the socket.
    #
    # @param message [String] The message to write out.
    # @param type [Symbol] The type of the message (from NAILGUN_MESSAGE_TYPES)
    #
    # @return [void]
    def write_message_safe(message, type)
      @socket_lock.synchronize { write_message(message, type) }
    end

    attr_reader :host, :port
  end
end
