# Licensed under the Apache 2 License
# (C)2024 Tom Noonan II

module Helpers
  module Random
    def self.word(length: rand(10..50))
      return (0...length).map { ('a'..'z').to_a[rand(26)] }.join
    end
  end
end
