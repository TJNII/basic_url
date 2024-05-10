require_relative 'lib/basic_url/version'

Gem::Specification.new do |spec|
  spec.name = 'basic_url'
  spec.version = BasicUrl::VERSION
  spec.authors = ['Tom Noonan II']
  spec.email = ['tom@tjnii.com']

  spec.summary = 'A Simple URL object that supports common URL operations'
  #  spec.description = "TODO: Write a longer description or delete this line."
  #  spec.homepage = "TODO: Put your gem's website or public repo URL here."
  spec.required_ruby_version = '>= 3.0.0'

  #  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  #  spec.metadata["homepage_uri"] = spec.homepage
  #  spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  #  spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rspec', '~> 3.8'
  spec.add_development_dependency 'rubocop', '~> 1.60'
  spec.add_development_dependency 'simplecov', '~> 0.16'
end
