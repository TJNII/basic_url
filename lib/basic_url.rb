require 'uri'

require_relative 'basic_url/version'
require_relative 'basic_url/errors'

class BasicUrl
  def self.urldecode_component(input)
    return nil if input.nil?

    return URI.decode_www_form_component(input)
  end

  def self.parse(input, **kwargs)
    input = input.downcase

    # URI.parse does all kinds of oddball grouping if it doesn't have a protocol
    # Parse the protocol out ourself, injecting a placeholder if needed
    proto_match = input.match(%r{^(?<proto>[a-z0-9]+)://})
    if proto_match
      proto = proto_match[:proto]
    else
      proto = nil
      input = "DUMMY://#{input}"
    end

    begin
      uri_obj = URI.parse(input)
    rescue StandardError => exc
      raise(Errors::InvalidURL, "Failed to parse URL #{input}: #{exc.class}: #{exc}")
    end

    params_hash = {}

    if uri_obj.query
      begin
        params_array = uri_obj.query.split('&').map { |qc| qc.split('=') }
        params_array.each.with_index do |pair, index|
          raise(Errors::InvalidURL, "Parameter #{pair} at index #{index + 1} failed to parse as a key-value pair") if pair.length != 2

          value = urldecode_component(pair[1])

          if pair[0][-2..-1] == '[]'
            key = urldecode_component(pair[0][0..-3])
            params_hash[key] ||= []
            params_hash[key].push(value)
          else
            key = urldecode_component(pair[0])
            params_hash[key] = value
          end
        end
      rescue StandardError => exc
        raise(Errors::InvalidURL, "Failed to parse URL #{input} query parameters: #{exc.class}: #{exc}")
      end
    end

    components = {
      protocol: proto,
      host: uri_obj.host,
      port: uri_obj.port,
      path: uri_obj.path,
      params: params_hash,
      fragment: urldecode_component(uri_obj.fragment),
      user: urldecode_component(uri_obj.user),
      password: urldecode_component(uri_obj.password),
    }.reject { |_, v| v.to_s.empty? }

    return new(**kwargs.merge(components))
  end

  attr_reader :default_protocol, :fragment, :host, :params, :password, :path_components, :port, :protocol, :user

  %i[protocol host port path_components params fragment user password].each do |component|
    define_method("#{component}=") do |value|
      _validate_component(component: component, value: value)
      instance_variable_set("@#{component}", value)
    end
  end

  def initialize(**kwargs)
    @path_components = []
    @default_protocol = kwargs.delete(:default_protocol)

    raise(ArgumentError, ':path and :path_components are exclusive') if kwargs.key(:path) && kwargs.key(:path_components)

    defaults = {
      protocol: @default_protocol,
      host: nil,
      port: _default_port_for_protocol(protocol: @default_protocol),
      params: {},
      fragment: nil,
      user: nil,
      password: nil,
    }

    defaults.merge(kwargs.compact).sort.each do |component, value|
      send("#{component}=", value)
    end
  end

  def join(value, replace_when_absolute: true)
    _validate_component(component: :path, value: value)
    new_components = _path_to_a(value: value)

    rv = dup

    rv.path_components = if replace_when_absolute && value[0] == '/'
                           new_components
                         else
                           @path_components + new_components
                         end

    return rv
  end

  def join!(value, replace_when_absolute: true)
    _validate_component(component: :path, value: value)
    new_components = _path_to_a(value: value)

    if replace_when_absolute && value[0] == '/'
      @path_components  = new_components
    else
      @path_components += new_components
    end

    return path
  end

  def path=(value)
    if value.nil?
      @path_components = []
    else
      _validate_component(component: :path, value: value)
      @path_components = _path_to_a(value: value)
    end
  end

  def path
    return nil if @path_components.empty?

    return @path_components.join('/')
  end

  def path_encoded
    return nil if @path_components.empty?

    return @path_components.map { |c| urlencode_component(c) }.join('/')
  end

  def to_s
    %i[protocol host].each do |required_component|
      raise(Errors::InvalidURL, "Missing #{required_component}") unless send(required_component)
    end

    ret_val = "#{protocol}://"
    if user || password
      ret_val += urlencode_component(user) if user
      ret_val += ":#{urlencode_component(password)}" if password
      ret_val += '@'
    end

    ret_val += host
    ret_val += ":#{port}" if port && port != _default_port_for_protocol(protocol: protocol)
    ret_val += "/#{path_encoded}" unless @path_components.empty?
    ret_val += _query_string unless params.empty?
    ret_val += "##{urlencode_component(fragment)}" if fragment

    return ret_val
  end

  def urlencode_component(value)
    return URI.encode_www_form_component(value.to_s)
  end

  private

  def _default_port_for_protocol(protocol:)
    return nil if protocol.nil?

    rv = URI.parse("#{protocol}://").port
    return rv
  end

  def _query_string
    encoded_components = []

    params.each_pair do |key, value|
      encoded_key = urlencode_component(key)
      if value.is_a? Array
        value.map { |v| urlencode_component(v) }.each do |encoded_value|
          encoded_components.push("#{encoded_key}[]=#{encoded_value}")
        end
      else
        encoded_value = urlencode_component(value)
        encoded_components.push("#{encoded_key}=#{encoded_value}")
      end
    end

    return "?#{encoded_components.join('&')}"
  end

  def _path_to_a(value:)
    value.split('/').reject(&:empty?).map { |c| self.class.urldecode_component(c) }
  end

  def _validate_component(**kwargs)
    if kwargs.fetch(:value).nil?
      raise(Errors::InvalidComponent, "nil #{kwargs.fetch(:component)} not allowed") if %i[params].include?(kwargs.fetch(:component))

      return
    end

    _validate_component_type(**kwargs)
    _validate_component_characters(**kwargs)
  end

  def _validate_component_characters(component:, value:)
    case component
    when :default_protocol, :protocol
      # Basic URL building symbols
      disallowed_chars = %w[@ : / ? & #]
    when :host
      disallowed_chars = if value[0] == '[' && value[-1] == ']'
                           # IPv6
                           # This should technically be more strict, but this is a minimal sanity check
                           %w[@ / ? & #]
                         else
                           %w[@ : / ? & #]
                         end
    when :path
      disallowed_chars = %w[? #]
    when :path_components
      value.each do |comp|
        _validate_component_characters(component: :path, value: comp)
      end

      return
    when :port, :params, :fragment, :user, :password
      # port: integer: Nothing to do
      # params: hash, urlencoded
      # user: urlencoded
      # password: urlencoded
      return
    else
      raise(Errors::InternalError, "Unknown component #{component}")
    end

    disallowed_chars.each do |dchar|
      raise(Errors::InvalidComponent, "#{component} contains disallowed character #{dchar}") if value.include?(dchar)
    end
  end

  def _validate_component_type(component:, value:)
    types = {
      default_protocol: String,
      protocol: String,
      host: String,
      port: Integer,
      path: String,
      path_components: Array,
      params: Hash,
      fragment: String,
      user: String,
      password: String,
    }

    raise(Errors::InternalError, "Unknown component #{component}") unless types.key?(component)
    raise(Errors::ComponentTypeError, "#{component} must be a #{types[component]}, got a #{value.class} (#{value})") unless value.is_a?(types[component])
  end
end
