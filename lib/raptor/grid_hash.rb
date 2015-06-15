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

    def process_images(dir)
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

      ChunkyPNG::Color.to_rgb(col)
    end

    class SortableColor
      @color = nil

      def initialize(color)
        @color = color
      end

      def <=>(other)
        is_neg = c1 < c2
        c1 = ChunkyPNG::Color.to_rgb(@color)
        c1 = Color::RGB.new(c1[0], c1[1], c1[2])
        c2 = ChunkyPNG::Color.to_rgb(other.get_instance_variable(:@color))
        c2 = Color::RGB.new(c2[0], c2[1], c2[2])
        deltaE = col1.delta_e94(c1.to_lab, c2.to_lab)
        detaE *= -1 if neg
        deltaE
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
