require 'rack'
require 'net/ldap'
require 'net/ntlm'
require 'uri'
module OmniAuth
  module Strategies
    class LDAP
      class Adaptor
				class LdapError < StandardError; end
				class ConfigurationError < StandardError; end
				class AuthenticationError < StandardError; end
				class ConnectionError < StandardError; end
	      VALID_ADAPTER_CONFIGURATION_KEYS = [:host, :port, :method, :bind_dn, :password,
	                                          :try_sasl, :sasl_mechanisms, :sasl_quiet]
	      MUST_HAVE_KEYS = [:host, :port, :method]
	      METHOD = {
	        :ssl => :simple_tls,
	        :tls => :start_tls,
	        :plain => nil
	      }     
	      attr_reader :bind_dn                                     
	
	      def initialize(configuration={})
	        @connection = nil
	        @disconnected = false
	        @bound = false
	        @configuration = configuration.dup
	        @logger = @configuration.delete(:logger)
	        message = []
	        MUST_HAVE_KEYS.each do |name|
	        	message << name if configuration[name].nil? 
	        end
	        raise ArgumentError.new(message.join(",") +" MUST be provided") unless message.empty?
	        VALID_ADAPTER_CONFIGURATION_KEYS.each do |name|
	          instance_variable_set("@#{name}", configuration[name])
	        end
	      end
	
				def connect(options={})
	        host = options[:host] || @host
	        method = options[:method] || @method || :plain
	        port = options[:port] || @port || ensure_port(method)
	        method = ensure_method(method)
	        @disconnected = false
	        @bound = false
	        @bind_tried = false				
          config = {
            :host => host,
            :port => port,
          }
          config[:encryption] = {:method => method} if method
          @connection, @uri, @with_start_tls = 
          begin
            uri = construct_uri(host, port, method == :simple_tls)
            with_start_tls = method == :start_tls
            puts ({:uri => uri, :with_start_tls => with_start_tls}).inspect
            [Net::LDAP::Connection.new(config), uri, with_start_tls]
          rescue Net::LDAP::LdapError
            raise ConnectionError, $!.message
          end
	      end
	
	      def unbind(options={})
	          @connection.close # Net::LDAP doesn't implement unbind.
	      end
	
	      def bind(options={})
	        connect(options) unless connecting?
	        begin
		        @bind_tried = true
		
		        bind_dn = (options[:bind_dn] || @bind_dn).to_s
		        try_sasl = options.has_key?(:try_sasl) ? options[:try_sasl] : @try_sasl
		
		        # Rough bind loop:
		        # Attempt 1: SASL if available
		        # Attempt 2: SIMPLE with credentials if password block
		        # Attempt 3: SIMPLE ANONYMOUS if 1 and 2 fail (or pwblock returns '')
		        if try_sasl and sasl_bind(bind_dn, options)
		        	puts "bind with sasl"
		        elsif simple_bind(bind_dn, options)
		        	puts "bind with simple"
		        else
		          message = yield if block_given?
		          message ||= ('All authentication methods for %s exhausted.') % target
		          raise AuthenticationError, message
		        end
		
		        @bound = true
	        rescue Net::LDAP::LdapError
	          raise AuthenticationError, $!.message
	        end
	      end
	
	      def disconnect!(options={})
	        unbind(options)
	        @connection = @uri = @with_start_tls = nil
	        @disconnected = true
	      end
	
	      def rebind(options={})
	        unbind(options) if bound?
	        connect(options)
	      end
	
	      def connecting?
	        !@connection.nil? and !@disconnected
	      end
	
	      def bound?
	        connecting? and @bound
	      end
	
	
	      private
	      def execute(method, *args, &block)
	        result = @connection.send(method, *args, &block)
	        message = nil
	        if result.is_a?(Hash)
	          message = result[:errorMessage]
	          result = result[:resultCode]
	        end
	        unless result.zero?
	          message = [Net::LDAP.result2string(result), message].compact.join(": ")
	          raise LdapError, message
	        end
	      end	      
	      
	      def ensure_port(method)
	        if method == :ssl
	          URI::LDAPS::DEFAULT_PORT
	        else
	          URI::LDAP::DEFAULT_PORT
	        end
	      end
	
	      def prepare_connection(options)
	      end
	
	
	      def need_credential_sasl_mechanism?(mechanism)
	        not %(GSSAPI EXTERNAL ANONYMOUS).include?(mechanism)
	      end
	
	      def ensure_method(method)
	        method ||= "plain"
	        normalized_method = method.to_s.downcase.to_sym
	        return METHOD[normalized_method] if METHOD.has_key?(normalized_method)
	
	        available_methods = METHOD.keys.collect {|m| m.inspect}.join(", ")
	        format = "%s is not one of the available connect methods: %s"
	        raise ConfigurationError, format % [method.inspect, available_methods]
	      end
	      
	      def sasl_bind(bind_dn, options={})
	        if options.has_key?(:sasl_quiet)
	          sasl_quiet = options[:sasl_quiet]
	        else
	          sasl_quiet = @sasl_quiet
	        end
	
	        sasl_mechanisms = options[:sasl_mechanisms] || @sasl_mechanisms
          begin
	          sasl_mechanisms.each do |mechanism|
		          normalized_mechanism = mechanism.downcase.gsub(/-/, '_')
		          sasl_bind_setup = "sasl_bind_setup_#{normalized_mechanism}"
		          next unless respond_to?(sasl_bind_setup, true)
		          initial_credential, challenge_response =
		            send(sasl_bind_setup, bind_dn, options)
		          args = {
		            :method => :sasl,
		            :initial_credential => initial_credential,
		            :mechanism => mechanism,
		            :challenge_response => challenge_response,
		          }
		          info = {
		            :name => "bind: SASL", :dn => bind_dn, :mechanism => mechanism,
		          }
		          puts info.inspect
		          return true if execute(:bind, args)
	          end
	        rescue Exception => e
	        	puts e.message
	          false
	        end
	        false
			  end

      def parse_sasl_digest_md5_credential(cred)
        params = {}
        cred.scan(/(\w+)=(\"?)(.+?)\2(?:,|$)/) do |name, sep, value|
          params[name] = value
        end
        params
      end			  
      CHARS = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
      def generate_client_nonce(size=32)
        nonce = ""
        size.times do |i|
          nonce << CHARS[rand(CHARS.size)]
        end
        nonce
      end      
      def sasl_bind_setup_digest_md5(bind_dn, options)
        initial_credential = ""
        nonce_count = 1
        challenge_response = Proc.new do |cred|
          params = parse_sasl_digest_md5_credential(cred)
          qops = params["qop"].split(/,/)
          unless qops.include?("auth")
            raise ActiveLdap::AuthenticationError,
                  _("unsupported qops: %s") % qops.inspect
          end
          qop = "auth"
          server = @connection.instance_variable_get("@conn").addr[2]
          realm = params['realm']
          uri = "ldap/#{server}"
          nc = "%08x" % nonce_count
          nonce = params["nonce"]
          cnonce = generate_client_nonce
          requests = {
            :username => bind_dn.inspect,
            :realm => realm.inspect,
            :nonce => nonce.inspect,
            :cnonce => cnonce.inspect,
            :nc => nc,
            :qop => qop,
            :maxbuf => "65536",
            "digest-uri" => uri.inspect,
          }
          a1 = "#{bind_dn}:#{realm}:#{@password}"
          a1 = "#{Digest::MD5.digest(a1)}:#{nonce}:#{cnonce}"
          ha1 = Digest::MD5.hexdigest(a1)
          a2 = "AUTHENTICATE:#{uri}"
          ha2 = Digest::MD5.hexdigest(a2)
          response = "#{ha1}:#{nonce}:#{nc}:#{cnonce}:#{qop}:#{ha2}"
          requests["response"] = Digest::MD5.hexdigest(response)
          nonce_count += 1
          requests.collect do |key, value|
            "#{key}=#{value}"
          end.join(",")
        end
        [initial_credential, challenge_response]
      end
      def sasl_bind_setup_gss_spnego(bind_dn, options)
        puts options.inspect
        user,psw = [bind_dn, @password]
        raise LdapError.new( "invalid binding information" ) unless (user && psw)

        nego = proc {|challenge|
          t2_msg = Net::NTLM::Message.parse( challenge )
          user, domain = user.split('\\').reverse
          t2_msg.target_name = Net::NTLM::encode_utf16le(domain) if domain
          t3_msg = t2_msg.response( {:user => user, :password => psw}, {:ntlmv2 => true} )
          t3_msg.serialize
        }        
        [Net::NTLM::Message::Type1.new.serialize, nego]        
      end
      
	      def simple_bind(bind_dn, options={})
	          args = {
	            :method => :simple,
	            :username => bind_dn,
	            :password => @password,
	          }
	          execute(:bind, args)
	          true
	      end
	      
	      def construct_uri(host, port, ssl)
	        protocol = ssl ? "ldaps" : "ldap"
	        URI.parse("#{protocol}://#{host}:#{port}").to_s
	      end
	
	      def target
	        return nil if @uri.nil?
	        if @with_start_tls
	          "#{@uri}(StartTLS)"
	        else
	          @uri
	        end
	      end	
      end
    end
  end
end