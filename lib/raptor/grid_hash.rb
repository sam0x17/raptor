require 'color'
require 'objspace'
module RAPTOR
  class GridHash

    CLEAR_LINE = "                                                                                \r"

    def initialize
      @unique_colors = {}
      @grid = {}
      @rotations = {}
      @num_pixels = 0
      @rots_inverted = nil
      @imgs = []
    end

    def image_files
      @imgs
    end

    def rotation_by_id(rot_id)
      @rots_inverted = @rotations.invert if @rots_inverted.nil?
      @rots_inverted[rot_id]
    end

    def memory_size
      ObjectSpace.memsize_of(self) +
      ObjectSpace.memsize_of(@grid) +
      ObjectSpace.memsize_of(@rotations) +
      ObjectSpace.memsize_of(@rots_inverted) +
      ObjectSpace.memsize_of(@imgs) +
      ObjectSpace.memsize_of(@combs) +
      ObjectSpace.memsize_of(@kmeans) +
      ObjectSpace.memsize_of(@unique_colors)
    end

    def self.filter_color(color)
      bytes = ChunkyPNG::Color.to_truecolor_bytes(color)
      ChunkyPNG::Color.rgb(bytes[0], bytes[1], bytes[2])
    end

    def register_activation(params={})
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

    def identify_rotation(img, sensitivity=0.5)
      # calculate deltE threshold
      deltaE_threshold = 0.0
      @combs = @kmeans.centroids.combination(2).to_a if @combs.nil?
      @combs.each do |pair|
        deltaE_threshold += pair[0].get_deltaE(pair[1])
      end
      deltaE_threshold = 1.0 / sensitivity * (deltaE_threshold / @combs.size)
      # process image
      img = ChunkyPNG::Image.from_file(img) if img.is_a? String
      counts = {}
      @rotations.each do |rot, rot_id|
        counts[rot_id] = 0
      end
      width = img.dimension.width
      height = img.dimension.height
      width.times do |x|
        height.times do |y|
          color = img[x, y]
          next if color == 0
          color = RAPTOR::GridHash.filter_color(color)
          color_index_match = @kmeans.closest_color(color)
          key = [x, y, color_index_match]
          rots = @grid[key]
          rots.each do |rot_id|
            counts[rot_id] += 1
          end
        end
      end
      counts = counts.sort_by(&:last)
      ret = []
      counts.each do |rot_id, count|
        rot = rotation_by_id(rot_id)
        ret << [rot, rot_id, count]
      end
      ret
    end

    def process_images(dir, num_index_colors=8)
      @imgs = []
      @unique_colors = {}
      @grid = {}
      @rotations = {}
      @num_pixels = 0
      @rots_inverted = nil
      @combs = nil
      i = 1
      Dir.glob("#{dir}/**/*.png") do |file|
        @imgs << file
        i += 1
      end
      @imgs.uniq!
      @imgs.sort!
      num_images = @imgs.size
      puts "Discovered #{num_images} unique image files"
      i = 1
      @imgs.each do |file|
        print CLEAR_LINE
        print "Collecting color info from image #{i}/#{num_images} (#{file})\r"
        $stdout.flush
        collect_image_color_data(file)
        i += 1
      end
      puts ""
      puts "Total pixels processed: #{@num_pixels}"
      @unique_colors = @unique_colors.keys.collect {|col| SortableColor.new(col) }
      puts "Total unique colors: #{@unique_colors.size}"
      puts "Generating indexed color set (#{num_index_colors} index colors)..."
      #num_index_colors -= 1
      #index_step = @unique_colors.size / num_index_colors
      #(0..num_index_colors).to_a.each do |num|
      #  index = num * index_step
      #  index = @unique_colors.size - 1 if index > @unique_colors.size - 1
      #  @indexed_colors << @unique_colors[index]
      #end
      @kmeans = RAPTOR::KMeans.new(@unique_colors, num_index_colors)
      @unique_colors = nil # save memory
      puts "Collecting per-pixel pose information..."
      i = 1
      @imgs.each do |file|
        print CLEAR_LINE
        print "Analyzing pixels from image #{i}/#{num_images} (#{file})\r"
        img = ChunkyPNG::Image.from_file file
        $stdout.flush
        rx = img.metadata['rx'].to_f
        ry = img.metadata['ry'].to_f
        rz = img.metadata['rz'].to_f
        width = img.dimension.width
        height = img.dimension.height
        width.times do |col|
          height.times do |row|
            color = img[col, row]
            next if color == 0
            color = img[col, row]
            color = GridHash.filter_color(color)
            indexed_color = @kmeans.closest_color(color)
            register_activation(x: col, y: row, color: indexed_color, rx: rx, ry: ry, rz: rz)
          end
        end
        i += 1
      end
      puts ""
      puts "Done"
    end

    class SortableColor
      BASE = Color::RGB.new(128, 128, 128).to_lab

      def initialize(color)
        @bytes = ChunkyPNG::Color.to_truecolor_bytes(color) if color.is_a? Integer
        @bytes = color if color.is_a? Array
      end

      def get_deltaE_comparison(other)
        self_deltaE = rgb.delta_e94(BASE, lab)
        other_deltaE = rgb.delta_e94(BASE, other.lab)
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
        chunky == other.chunky
      end

      def <=>(other)
        deltaE = get_deltaE_comparison(other)
        deltaE[0] <=> deltaE[1]
      end

      def get_deltaE(other)
        rgb.delta_e94(lab, other.lab)
      end

      def bytes
        @bytes
      end

      def chunky
        @chunky = ChunkyPNG::Color.rgb(bytes[0], bytes[1], bytes[2]) if @chunky.nil?
        @chunky
      end

      def rgb
        @rgb = Color::RGB.new(@bytes[0], @bytes[1], @bytes[2]) if @rgb.nil?
        @rgb
      end

      def hsl
        @hsl = rgb.to_hsl if @hsl.nil?
        @hsl
      end

      def lab
        @lab = rgb.to_lab if @lab.nil?
        @lab
      end

      def hash
        @bytes.hash
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
          color = GridHash.filter_color(color)
          @num_pixels += 1
          @unique_colors[color] = true
        end
      end
      true
    end

  end
end
