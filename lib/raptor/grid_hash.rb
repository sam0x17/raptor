require 'color'
module RAPTOR
  class GridHash

    def initialize(options={})
      @unique_colors = {}
      @grid = {}
      @rotations = {}
      @color_mappings = {}
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

    def process_images(dir, num_index_colors=50)
      @unique_colors = {}
      @grid = {}
      @rotations = {}
      @num_pixels = 0
      @color_mappings = {}
      @indexed_colors = []
      i = 1
      puts "Collecting color information..."
      Dir.glob("#{dir}/**/*.png") do |file|
        puts "Processed up to #{file}\t(#{i})" if i % 1000 == 0
        collect_image_color_data(file)
        i += 1
      end
      num_images = i
      puts "Completed initial pass"
      puts "Total images: #{num_images}"
      puts "Total pixels processed: #{@num_pixels}"
      puts "Total unique colors: #{@unique_colors.size}"
      puts "Generating LAB versions of unique colors..."
      @unique_colors = @unique_colors.keys.collect {|col| SortableColor.new(col) }
      puts "Sorting unique colors based on DeltaE distance from black..."
      @unique_colors.sort!
      puts "Generating indexed color set..."
      num_index_colors -= 1
      index_step = @unique_colors.size / num_index_colors
      (0..num_index_colors).to_a.each do |num|
        index = num * index_step
        @indexed_colors << @unique_colors[index]
      end
      puts "Generating RGB to LAB color mappings..."
      @unique_colors.select {|col| @color_mappings[col.color_chunky] = col.color_lab}
      puts "Generating indexed color mappings..."
      @index_mappings = {}
      tst_bytes = ChunkyPNG::Color.to_truecolor_bytes(0)
      tst_chunky_rgb = ChunkyPNG::RGB.new(0, 0, 0)
      @color_mappings.each do |chunky_val, lab_val|
        next if @index_mapping.has_key?(chunky_val)
        best_deltaE = nil
        best_match = nil
        @indexed_colors.each do |index|
          deltaE = tst_chunky_rgb.delta_e94(lab_val, index.color_lab)
          if best_deltaE.nil? || deltaE < best_deltaE
            best_deltaE = deltaE
            best_match = index.color_chunky
          end
        end
        @index_mappings[chunky_val] = best_match
      end
      puts "Generating per-pixel pose information..."
      i = 1
      Dir.glob("#{dir}/**/*.png") do |file|
        rot = File.basename(file, ".png").split("_").collect {|e| e.to_i}
        rx = rot[0]
        ry = rot[1]
        rz = rot[2]
        img = ChunkyPNG::Image.from_file file
        width = img.dimension.width
        height = img.dimension.height
        width.times do |col|
          height.times do |row|
            color = img[col, row]
            next if color == 0
            indexed_color = @index_mappings[color]
            register_activation(x: col, y: row, color: indexed_color, rx: rx, ry: ry, rz: rz)
          end
        end
        puts "Processed up to #{file}\t(#{i})" if i % 1000 == 0
        i += 1
      end
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

    def collect_image_color_data(img_path)
      img = ChunkyPNG::Image.from_file img_path
      width = img.dimension.width
      height = img.dimension.height
      width.times do |col|
        height.times do |row|
          color = img[col, row]
          next if color == 0
          @num_pixels += 1
          @unique_colors[color] = true
        end
      end
      true
    end

    def process_image2(img_path)
      rot = File.basename(img_path, ".png").split("_").collect {|e| e.to_i}
      rx = rot[0]
      ry = rot[1]
      rz = rot[2]
      img = ChunkyPNG::Image.from_file img_path
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
