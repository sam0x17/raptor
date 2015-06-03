module RAPTOR
  class GridHash
    attr_accessor :grid_width
    attr_accessor :grid_height
    attr_reader :colors

    def initialize
      self.grid_width = 128
      self.grid_height = 128
      @colors = {}
      @grid = {}
    end

    def [](key)
      validate_key! key
      return @grid[[key[:x], key[:y]]]
    end

    class InvalidKeyError < StandardError
    end

    protected

    def key_valid?(key)
      !(!key.has_key?(:x) || !key.has_key?(:y) ||
      key[:x].nil? || key[:y].nil? ||
      key[:x] < 0 || key[:y] < 0 ||
      key[:x] > grid_width - 1 || key[:y] > grid_height - 1)
    end

    def validate_key!(key)
      raise InvalidKeyError if !key_valid?(key)
    end

  end
end
