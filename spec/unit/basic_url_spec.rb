# Licensed under the Apache 2 License
# (C)2024 Tom Noonan II

require './spec/helpers/spec_helper'
require './spec/helpers/random'
require './lib/basic_url'

describe BasicUrl do
  let(:test_components) do
    {
      protocol: Helpers::Random.word,
      host: Array.new(3) { Helpers::Random.word }.join('.'),
      port: rand(1..0xffff),
      path: Array.new(3) { Helpers::Random.word }.join('/'),
      params: Array.new(3) { [Helpers::Random.word, Helpers::Random.word] }.to_h,
      fragment: Helpers::Random.word,
      user: Helpers::Random.word,
      password: Helpers::Random.word,
    }
  end

  let(:test_enabled_url_component_keys) { test_components.keys }
  let(:test_enabled_url_components) { test_components.select { |k, _| test_enabled_url_component_keys.include?(k) } }

  let(:encoded_params) { test_components[:params].map { |k, v| "#{k}=#{v}" }.join('&') }

  let(:url_test_components) do
    {
      protocol: "#{test_components[:protocol]}://",
      user: "#{test_components[:user]}#{test_enabled_url_component_keys.include?(:password) ? '' : '@'}",
      password: ":#{test_components[:password]}@",
      host: test_components[:host],
      port: ":#{test_components[:port]}",
      path: "/#{test_components[:path]}",
      params: "?#{encoded_params}",
      fragment: "##{test_components[:fragment]}",
    }
  end

  let(:input_url) do
    url_test_components.select { |k, _| test_enabled_url_component_keys.include?(k) }.values.join
  end

  describe '.parse' do
    shared_examples 'parsing' do
      let(:expected_components) { default_components.merge(test_enabled_url_components) }

      describe 'When passed only the URL' do
        let(:default_components) do
          {
            protocol: nil,
            host: nil,
            port: nil,
            path: nil,
            params: {},
            fragment: nil,
            user: nil,
            password: nil,
          }
        end

        subject { described_class.parse(input_url) }

        it 'parses' do
          expected_components.each do |component, value|
            expect(subject.send(component)).to eq(value)
          end
        end

        it 'returns the correct url string' do
          if expected_components[:protocol] && expected_components[:host]
            expect(subject.to_s).to eq(input_url)
          else
            expect { subject.to_s }.to raise_exception(described_class::Errors::InvalidURL)
          end
        end
      end

      describe 'When passed the URL and a default protocol' do
        let(:default_components) do
          {
            protocol: 'http',
            host: nil,
            port: 80,
            path: nil,
            params: {},
            fragment: nil,
            user: nil,
            password: nil,
          }
        end

        subject { described_class.parse(input_url, default_protocol: 'http') }

        it 'parses' do
          expected_components.each do |component, value|
            expect(subject.send(component)).to eq(value)
          end
        end

        it "it able to reparse it's url output string" do
          if expected_components[:protocol] && expected_components[:host]
            reparsed_output = described_class.parse(subject.to_s)
            expected_components.each do |component, value|
              expect(reparsed_output.send(component)).to eq(value)
            end
          else
            expect { subject.to_s }.to raise_exception(described_class::Errors::InvalidURL)
          end
        end
      end
    end

    describe 'when passed a complete, complex URL' do
      it_behaves_like 'parsing'
    end

    describe 'complex permutations' do
      params = {
        protocol: [:host],
        host: [],
        port: [:host],
        path: [:host],
        params: [:host],
        fragment: [:host],
        user: [:host],
        password: [:host],
      }

      raw_permutations = Array.new(2**(params.length)) { |i| params.keys.map.with_index { |k, ki| [k, ((i & (1 << ki)) != 0)] }.to_h }
      filtered_permutations = raw_permutations.reject do |permutation|
        if permutation.values.any?
          params.map do |param, dependencies|
            dependencies.map { |dep_param| !permutation[dep_param] }.any? if permutation[param]
          end.any?
        else
          true
        end
      end

      filtered_permutations.each do |permutation|
        enabled_components = permutation.select { |_, v| v }.keys

        describe "When the URL contains #{enabled_components} components" do
          let(:test_enabled_url_component_keys) { enabled_components }

          it_behaves_like 'parsing'
        end
      end
    end

    #
    # Some static tests for sanity / corner cases
    #
    describe 'when passed a simple URL' do
      let(:test_components) do
        {
          protocol: Helpers::Random.word,
          host: Helpers::Random.word,
        }
      end

      let(:input_url) { "#{test_components[:protocol]}://#{test_components[:host]}" }

      it_behaves_like 'parsing'
    end

    describe 'when passed a bare fqdn' do
      let(:test_components) do
        {
          host: Array.new(2) { Helpers::Random.word }.join('.'),
        }
      end

      let(:input_url) { test_components[:host] }

      it_behaves_like 'parsing'
    end

    describe 'when passed a bare fqdn & port' do
      let(:test_components) do
        {
          host: Array.new(2) { Helpers::Random.word }.join('.'),
          port: rand(1..0xffff),
        }
      end

      let(:input_url) { "#{test_components[:host]}:#{test_components[:port]}" }

      it_behaves_like 'parsing'
    end

    describe 'when passed a IPv4 address' do
      let(:test_components) do
        {
          host: '192.0.2.42',
        }
      end

      let(:input_url) { test_components[:host] }

      it_behaves_like 'parsing'
    end

    describe 'when passed a bare proto://[IPv6 address]' do
      let(:test_components) do
        {
          protocol: Helpers::Random.word,
          # Brackets: https://www.ietf.org/rfc/rfc2732.txt
          host: '[2001:db8::ba5e:ba11]',
        }
      end

      let(:input_url) { "#{test_components[:protocol]}://#{test_components[:host]}" }

      it_behaves_like 'parsing'
    end

    describe 'when passed a bare proto://[IPv6 address]:port' do
      let(:test_components) do
        {
          protocol: Helpers::Random.word,
          # Brackets: https://www.ietf.org/rfc/rfc2732.txt
          host: '[2001:db8::beef]',
          port: rand(1..0xffff),
        }
      end

      let(:input_url) { "#{test_components[:protocol]}://#{test_components[:host]}:#{test_components[:port]}" }

      it_behaves_like 'parsing'
    end

    describe 'when passed array query parameters' do
      let(:test_components) do
        {
          protocol: Helpers::Random.word,
          host: Helpers::Random.word,
          params: {
            'simple_key' => 'simple_value',
            'array_key' => %w[array_value_1 array_value_2 array_value_3],
          },
        }
      end

      let(:input_url) do
        "#{test_components[:protocol]}://#{test_components[:host]}?simple_key=simple_value&array_key[]=array_value_1&array_key[]=array_value_2&array_key[]=array_value_3"
      end

      it_behaves_like 'parsing'
    end

    describe 'when passed an invalid URL' do
      let(:input_url) { '7foo:[)URL:192.168.745.-4' }

      it 'raises InvalidURL' do
        expect { described_class.parse(input_url) }.to raise_exception(described_class::Errors::InvalidURL)
      end
    end

    describe 'when passed invalid query parameters' do
      let(:input_url) { 'http://foo/bar?param&param' }

      it 'raises InvalidURL' do
        expect { described_class.parse(input_url) }.to raise_exception(described_class::Errors::InvalidURL)
      end
    end
  end

  describe 'basic attributes' do
    subject { described_class.new }

    %i[protocol host port path params fragment user password].each do |param|
      describe param.to_s do
        it 'defaults to empty' do
          case param
          when :params
            expect(subject.send(param)).to eq({})
          else
            expect(subject.send(param)).to be_nil
          end
        end

        it 'is settable' do
          expect(subject.send(param)).to_not eq(test_components.fetch(param))
          subject.send("#{param}=", test_components.fetch(param))
          expect(subject.send(param)).to eq(test_components.fetch(param))
        end

        if %i[path fragment user password].include?(param)
          it 'urlencodes in the to_s output' do
            subject.protocol = 'foo'
            subject.host = 'bar'

            test_value_parts = Array.new(3) { Helpers::Random.word(length: 5) }
            test_value_raw = "#{test_value_parts[0]}!#{test_value_parts[1]}[#{test_value_parts[2]}]"
            test_value_encoded = "#{test_value_parts[0]}%21#{test_value_parts[1]}%5b#{test_value_parts[2]}%5d"

            expect(subject.to_s.downcase).to_not include(test_value_raw)
            expect(subject.to_s.downcase).to_not include(test_value_encoded)
            subject.send("#{param}=", test_value_raw)
            expect(subject.send(param)).to eq(test_value_raw)

            expect(subject.to_s.downcase).to_not include(test_value_raw)
            expect(subject.to_s.downcase).to include(test_value_encoded)
          end
        end

        if param == :params
          it 'urlencodes in the to_s output' do
            subject.protocol = 'foo'
            subject.host = 'bar'

            test_value_parts = Array.new(3) { Helpers::Random.word(length: 5) }
            test_value_raw = "#{test_value_parts[0]}!#{test_value_parts[1]}[#{test_value_parts[2]}]"
            test_value_encoded = "#{test_value_parts[0]}%21#{test_value_parts[1]}%5b#{test_value_parts[2]}%5d"

            expect(subject.to_s.downcase).to_not include(test_value_raw)
            expect(subject.to_s.downcase).to_not include(test_value_encoded)
            subject.params[:key] = test_value_raw
            expect(subject.params[:key]).to eq(test_value_raw)

            expect(subject.to_s.downcase).to_not include(test_value_raw)
            expect(subject.to_s.downcase).to include(test_value_encoded)
          end

          it 'is not nullable' do
            expect { subject.send("#{param}=", nil) }.to raise_exception(described_class::Errors::InvalidComponent)
          end
        else
          it 'is nullable' do
            subject.send("#{param}=", test_components.fetch(param))
            expect(subject.send(param)).to eq(test_components.fetch(param))

            subject.send("#{param}=", nil)
            expect(subject.send(param)).to eq(nil)
          end
        end

        describe 'when passed an invalid class' do
          let(:invalid_values) do
            {
              protocol: 7,
              host: 2.0,
              port: 'eighty',
              path: false,
              params: [],
              fragment: true,
              user: %w[testuser],
              password: :password,
            }
          end

          it 'throws ComponentTypeError' do
            expect { subject.send("#{param}=", invalid_values[param]) }.to raise_exception(described_class::Errors::ComponentTypeError)
          end
        end

        if %i[default_protocol protocol host path].include?(param)
          it 'Throws InvalidComponent when passed a disallowed symbol' do
            expect { subject.send("#{param}=", 'foo#bar?baz') }.to raise_exception(described_class::Errors::InvalidComponent)
          end
        end
      end
    end
  end

  describe 'default protocol' do
    subject { described_class.new(default_protocol: 'ftp') }

    it 'is readable at .default_protocol' do
      expect(subject.default_protocol).to eq 'ftp'
      subject.protocol = test_components[:protocol]
      expect(subject.default_protocol).to eq 'ftp'
    end

    it 'sets the default protocol' do
      expect(subject.protocol).to eq 'ftp'
      subject.protocol = test_components[:protocol]
      expect(subject.protocol).to_not eq 'ftp'
    end

    it 'sets the default port' do
      expect(subject.port).to eq 21
      subject.port = test_components[:port]
      expect(subject.port).to_not eq 21
    end
  end

  describe 'joins' do
    0x10.times do |ti|
      a_absolute       = ((ti & 0x01) != 0)
      a_trailing_slash = ((ti & 0x02) != 0)
      b_absolute       = ((ti & 0x04) != 0)
      b_trailing_slash = ((ti & 0x08) != 0)

      describe "When path A #{a_absolute ? 'is' : 'is not'} absolute" do
        describe "When path A #{a_trailing_slash ? 'has' : 'does not have'} a trailing slash" do
          describe "When path B #{b_absolute ? 'is' : 'is not'} absolute" do
            describe "When path B #{b_trailing_slash ? 'has' : 'does not have'} a trailing slash" do
              [:default, true, false].each do |replace_when_absolute|
                describe "When replace_when_absolute is #{replace_when_absolute}" do
                  let(:test_path_a_core_components) { Array.new(3) { Helpers::Random.word } }
                  let(:test_path_b_core_components) { Array.new(3) { Helpers::Random.word } }

                  let(:test_path_a) do
                    components = test_path_a_core_components.dup
                    components.insert(0, nil) if a_absolute
                    components.append(nil) if a_trailing_slash
                    components.join('/')
                  end

                  let(:test_path_b) do
                    components = test_path_b_core_components.dup
                    components.insert(0, nil) if b_absolute
                    components.append(nil) if b_trailing_slash
                    components.join('/')
                  end

                  let(:test_kwargs) do
                    case replace_when_absolute
                    when :default
                      {}
                    else
                      { replace_when_absolute: replace_when_absolute }
                    end
                  end

                  let(:combined_test_path_components) { test_path_a_core_components + test_path_b_core_components }

                  subject { described_class.new(**test_components.merge({ path: test_path_a })) }

                  describe '.join' do
                    let(:test_join_output) do
                      # Fun fact: URI::join(test_path_a, test_path_b) throws an exception on 100% of these cases
                      subject.join(test_path_b, **test_kwargs)
                    end

                    it 'returns a BasicURL object' do
                      expect(test_join_output).to be_a(described_class)
                    end

                    it 'matches all other params to the parent' do
                      test_components.each do |component, value|
                        next if component == :path

                        expect(test_join_output.send(component)).to eq(value)
                      end
                    end

                    it 'does not modify the original object' do
                      expect(subject.path_components).to eq test_path_a_core_components
                      expect(test_join_output.object_id).to_not eq(subject.object_id)
                      expect(subject.path_components).to eq test_path_a_core_components
                    end

                    if replace_when_absolute != false && b_absolute
                      it 'replaces path A with path B' do
                        expect(test_join_output.path_components).to eq test_path_b_core_components
                        expect(test_join_output.path).to eq(test_path_b_core_components.join('/'))
                      end
                    else
                      it 'appends path B to path A' do
                        expect(test_join_output.path_components).to eq combined_test_path_components
                        expect(test_join_output.path).to eq(combined_test_path_components.join('/'))
                      end
                    end
                  end

                  describe '.join!' do
                    let(:test_join_output) do
                      subject.join!(test_path_b, **test_kwargs)
                    end

                    it 'does modifies the original object' do
                      expect(subject.path_components).to eq test_path_a_core_components
                      test_join_output
                      expect(subject.path_components).to_not eq test_path_a_core_components
                    end

                    if replace_when_absolute != false && b_absolute
                      it 'replaces path A with path B' do
                        expect(test_join_output).to eq test_path_b_core_components.join('/')
                        expect(subject.path_components).to eq test_path_b_core_components
                        expect(subject.path).to eq(test_path_b_core_components.join('/'))
                      end
                    else
                      it 'appends path B to path A' do
                        expect(test_join_output).to eq(combined_test_path_components.join('/'))
                        expect(subject.path_components).to eq combined_test_path_components
                        expect(subject.path).to eq(combined_test_path_components.join('/'))
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  describe '.path_components' do
    subject { described_class.new(path: test_components[:path]) }

    it 'returns the path components' do
      expect(subject.path_components).to eq(test_components[:path].split('/'))
    end
  end
end
