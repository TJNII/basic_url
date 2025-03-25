# Licensed under the Apache 2 License
# (C)2025 Tom Noonan II

require 'simplecov'

RSpec.configure do |rspec|
  rspec.expect_with :rspec do |c|
    c.max_formatted_output_length = nil
  end
end

SimpleCov.start do
  enable_coverage :branch

  # Container handler: In a container coverage/ may not be writable.
  begin
    coverage_path = Pathname.new('coverage')
    Dir.mkdir(coverage_path) unless coverage_path.directory?
    FileUtils.touch(coverage_path.join('index.html'))
  rescue StandardError => exc
    coverage_path = Dir.mktmpdir('coverage')
    warn("coverage/ directory not writable (#{exc}), writing coverage report to #{coverage_path}")
  end
  coverage_dir(coverage_path)
end
