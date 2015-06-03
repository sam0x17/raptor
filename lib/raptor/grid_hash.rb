module RAPTOR
  class GridHash
    attr_accessor :grid_width
    attr_accessor :grid_height
    attr_reader :colors

    def initialize(options={})
      self.grid_width = options.has_key?(:grid_width) ? options[:grid_width].to_i : 128
      self.grid_height = options.has_key?(:grid_height) ? options[:grid_height].to_i : 128
      @colors = {}
      @grid = {}
    end

    def [](x, y, c=nil)
      raise InvalidKeyError if x.nil? || y.nil?
      x = x.to_i
      y = y.to_i
      raise OutOfGridBoundsError if x < 0 || x >= grid_width || y < 0 || y >= grid_height
    end

    class InvalidKeyError < StandardError
    end

    class OutOfGridBoundsError < StandardError
    end

  end
end
