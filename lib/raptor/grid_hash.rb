require 'color'
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
      @rotations = {}
      @compiled = false
    end

    def [](x, y, c=nil)
      raise InvalidKeyError if x.nil? || y.nil?
      x = x.to_i
      y = y.to_i
      raise OutOfGridBoundsError if x < 0 || x >= grid_width || y < 0 || y >= grid_height
    end

    def add_sample(params={})
      @compiled = true
      required_params = [:x, :y, :color, :rx, :ry, :rz]
      required_params.each {|p| raise MissingRequiredParamError if !params.keys.include?(p) }
      params.keys.each {|p| raise UnsupportedParamError if !required_params.include?(p) }
      x = params[:x].to_i
      y = params[:y].to_i
      color = params[:color]
      rx = params[:rx]
      ry = params[:ry]
      rz = params[:rz]
      pos = [x, y]
      rot = [rx, ry, rz]
      raise InvalidKeyError if x.nil? || y.nil?
      raise OutOfGridBoundsError if x < 0 || x >= grid_width || y < 0 || y >= grid_height
      @grid[pos] = {} if !@grid.has_key?(pos)
      @grid[pos][color] = {} if !@grid[pos].has_key?(color)
      @rotations[rot] = @rotations.size if !@rotations.has_key?(rot)
      rot_id = @rotations[rot]
      @grid[pos][color][rot_id] = 0 if !@grid[pos][color].has_key?(rot_id)
      @grid[pos][color][rot_id] += 1
    end

    def compile
      @grid.each do |pos, pos_row|
        pos_row.each do |color, color_row|
          color_row.each do |rot_id, rot_id_count|
            @grid[pos][color][rot_id] = rot_id_count / color_row.size
          end
        end
      end
      @compiled = true
    end

    class InvalidKeyError < StandardError
    end

    class OutOfGridBoundsError < StandardError
    end

    class MissingRequiredParamError < StandardError
    end

    class UnsupportedParamError < StandardError
    end

  end
end
