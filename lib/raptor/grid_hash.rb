require 'color'
module RAPTOR
  class GridHash

    def initialize(options={})
      @unique_colors = {}
      @grid = {}
      @rotations = {}
      @num_pixels = 0
    end

    def [](x, y, c)
      x = x.to_i
      y = y.to_i
      c = c.to_i
    end

    def register_activation(params={})
      x = params[:x]
      y = params[:y]
      color = params[:color]
      @unique_colors[color] = true
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
    
    def self.closest_color(color, set)
      best_match_num = 99999999.0
      best_match = nil
      set.each do |col|
        
      end
    end

    def process_images(dir, num_colors=20)
      i = 0
      Dir.glob("#{dir}/**/*.png") do |file|
        puts "Adding activations for #{file} \t(#{i})"
        process_image(file)
        i += 1
      end
      puts "Total pixels processed: #{@num_pixels}"
      puts "Total unique colors: #{@unique_colors.size}"
      puts "Sorting unique colors..."
      @unique_colors = @unique_colors.keys
      uniq = []
      @unique_colors.each do |col|
        uniq << SortableColor.new(col)
      end
      uniq.sort!
      puts "Done sorting."
      puts "Performing color segmentation..."
      num_to_generate = (0.01 * @unique_colors.size).to_i
      step = @unique_colors.size / num_to_generate
      @indexed_colors = []
      (0..num_to_generate).to_a.each do |num|
        index = num * step
        @indexed_colors << @unique_colors[index]
      end
      @grid.each do |grid_key, grid_value|
        puts "Applying index to #{grid_key}"
        @grid.delete(grid_key)
        
      end
      true
    end

    class SortableColor
      @color = nil
      BASE = Color::RGB.new(255, 255, 255).to_lab

      def initialize(color)
        @color = color
      end

      def <=>(other)
        c1 = ChunkyPNG::Color.to_truecolor_bytes(@color)
        c1 = Color::RGB.new(c1[0], c1[1], c1[2])
        c2 = ChunkyPNG::Color.to_truecolor_bytes(other.instance_variable_get(:@color))
        c2 = Color::RGB.new(c2[0], c2[1], c2[2])
        c1_deltaE = c1.delta_e94(BASE, c1.to_lab)
        c2_deltaE = c2.delta_e94(BASE, c2.to_lab)
        c1_deltaE <=> c2_deltaE
      end
    end

    def process_image(img_path)
      rot = File.basename(img_path, ".png").split("_").collect {|e| e.to_i}
      rx = rot[0]
      ry = rot[1]
      rz = rot[2]
      img = ChunkyPNG::Image.from_file img_path
      total = 0
      img.dimension.width.times do |col|
        img.dimension.height.times do |row|
          color = img[col, row]
          next if color == 0
          @num_pixels += 1
          register_activation(x: col, y: row, color: img[col, row], rx: rx, ry: ry, rz: rz)
        end
      end
    end

  end
end
