require 'color'
module RAPTOR
  class GridHash

    def initialize(options={})
      @unique_colors = {}
      @grid = {}
      @rotations = {}
      @num_pixels = 0
      @rots_inverted = nil
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
          color = @color_mappings[color]
          key = [x, y, color]
          rots = @grid[key]
          rots.each do |rot_id|
            counts[rot_id] += 1
            total_rots += 1
          end
        end
      end
      counts = counts.sort_by(&:last)
      @rots_inverted = @rotations.invert if @rots_inverted.nil?
      counts.last(20).each do |rot_id, count|
        puts "#{@rots_inverted[rot_id]} => #{count}"
      end
      true
    end
    
    def self.closest_color(color, set)
      best_deltaE = nil
      best_match = nil
      set.each do |col|
        deltaE = color.get_deltaE(col)
        if best_match.nil?
          best_match = col
          best_deltaE = deltaE
          next
        end
        if deltaE < best_deltaE
          best_match = col
          best_deltaE = deltaE
        end
      end
      best_match
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
      @unique_colors = uniq
      
      puts "Done sorting."
      puts "Performing color indexing..."
      num_to_generate = 50
      num_to_generate -= 1
      step = @unique_colors.size / num_to_generate
      @indexed_colors = []
      (0..num_to_generate).to_a.each do |num|
        index = num * step
        @indexed_colors << @unique_colors[index]
      end
      puts "Generated index set, simplifying grid..."
      grid_tmp = {}
      @color_mappings = {}
      grid_mod_count = 0
      anticipated_grid_mods = @grid.keys.size
      @grid.each do |grid_key, grid_value|
        grid_mod_count += 1
        @grid.delete(grid_key)
        orig = SortableColor.new(grid_key[2])
        closest = RAPTOR::GridHash.closest_color(orig, @indexed_colors)
        @color_mappings[grid_key[2]] = closest.color_chunky
        grid_key = [grid_key[0], grid_key[1], closest.color_chunky]
        grid_tmp[grid_key] = [] if !grid_tmp.has_key?(grid_key)
        grid_tmp[grid_key] += grid_value
        puts "#{grid_mod_count} / #{anticipated_grid_mods} grid modifications" if grid_mod_count % 100 == 0
      end
      @grid = grid_tmp
      puts "# of colors before indexing: #{@unique_colors.size}"
      puts "# of colors after indexing: #{@indexed_colors.size}"
      puts "done"
      true
    end

    class SortableColor
      BASE = Color::RGB.new(255, 255, 255).to_lab

      def initialize(color)
        @color_chunky = color
        bytes = ChunkyPNG::Color.to_truecolor_bytes(color)
        @color_rgb = Color::RGB.new(bytes[0], bytes[1], bytes[2])
        @color_lab = @color_rgb.to_lab
      end
      
      def get_deltaE_comparison(other)
        self_deltaE = @color_rgb.delta_e94(BASE, @color_lab)
        other_deltaE = @color_rgb.delta_e94(BASE, other.instance_variable_get(:@color_lab))
        [self_deltaE, other_deltaE]
      end
      
      def >(other)
        deltaE = get_deltaE_comparison(other)
        deltaE[0] > deltaE[1]
      end
      
      def <(other)
        deltaE = get_deltaE_comparison(other)
        deltaE[0] < deltaE[1]
      end
      
      def ==(other)
        deltaE = get_deltaE_comparison(other)
        deltaE[0] == deltaE[1]
      end

      def <=>(other)
        deltaE = get_deltaE_comparison(other)
        deltaE[0] <=> deltaE[1]
      end
      
      def get_deltaE(other)
        @color_rgb.delta_e94(@color_lab, other.color_lab)
      end
      
      def color_chunky
        @color_chunky
      end
      
      def color_rgb
        @color_rgb
      end
      
      def color_lab
        @color_lab
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
