require 'raptor/grid_hash'
require 'oily_png'
module RAPTOR

  def self.test
    img = ChunkyPNG::Image.from_file 'test.png'
    unique_colors = {}
    num_non_transparent_colors = 0
    img.dimension.width.times do |col|
      img.dimension.height.times do |row|
        color = img[col, row]
        next if color == 0
        unique_colors[color] = true
        num_non_transparent_colors += 1
      end
    end
    puts "                   WIDTH: #{img.dimension.width}"
    puts "                  HEIGHT: #{img.dimension.height}"
    puts "#                 PIXELS: #{img.dimension.width * img.dimension.height}"
    puts "# NON TRANSPARENT COLORS: #{num_non_transparent_colors}"
    puts "#          UNIQUE COLORS: #{unique_colors.size}"
  end

end
