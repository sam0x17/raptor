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

    def [](x, y, c)
      x = x.to_i
      y = y.to_i
      c = c.to_i
    end

    def register_activation(params={})
      @compiled = true
      x = params[:x]
      y = params[:y]
      color = params[:color]
      rx = params[:rx]
      ry = params[:ry]
      rz = params[:rz]
      key = [x, y, color]
      rot = [rx, ry, rz]
      @grid[key] = [] if !@grid.has_key?(key)
      @rotations[rot] = @rotations.size if !@rotations.has_key?(rot)
      rot_id = @rotations[rot]
      @grid[key] << rot_id
    end

    def identify_rotation(img)
      img = ChunkyPNG::Image.from_file(img) if img.is_a? String
      counts = {}
      @rotations.each do |rot, rot_id|
        counts[rot_id] = 1
      end
      total_rots = 0
      img.dimension.width.times do |x|
        img.dimension.height.times do |y|
          color = img[x, y]
          next if color == 0
          key = [x, y, color]
          rots = @grid[key]
          rots.each do |rot_id|
            counts[rot_id] += 1
            total_rots += 1
          end
        end
      end
      counts = counts.sort_by(&:last)
      rots_inverted = @rotations.invert
      counts.last(20).each do |rot_id, count|
        puts "#{rots_inverted[rot_id]} => #{count}"
      end
      true
    end

    def analyze
      @grid.each do |key, rots|
        puts "#{rots}" if rots.size > 1
      end
      true
    end

    def process_image(img_path)
      rot = File.basename(img_path, ".png").split("_").collect {|e| e.to_i}
      rx = rot[0]
      ry = rot[1]
      rz = rot[2]
      img = ChunkyPNG::Image.from_file img_path
      self.grid_height = img.dimension.height
      self.grid_width = img.dimension.width
      total = 0
      img.dimension.width.times do |col|
        img.dimension.height.times do |row|
          color = img[col, row]
          next if color == 0
          register_activation(x: col, y: row, color: img[col, row], rx: rx, ry: ry, rz: rz)
        end
      end
    end

    def process_images(dir)
      i = 0
      Dir.glob("#{dir}/**/*.png") do |file|
        puts "Adding activations for #{file} (#{i})"
        process_image(file)
        i += 1
      end
    end

  end
end
