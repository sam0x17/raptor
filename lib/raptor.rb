require 'raptor/grid_hash'
require 'raptor/data_generator'
require 'oily_png'
module RAPTOR
  
  def self.test_filter(img_path)
    img = ChunkyPNG::Image.from_file img_path
    width = img.dimension.width
    height = img.dimension.height
    width.times do |x|
      height.times do |y|
        old_color = img[x, y]
        next if old_color == 0
        vpos = Proc.new do |tx, ty|
          ret = nil
          if tx >= 0 && tx < width && ty >= 0 && ty < height
            ret = [tx, ty]
          else
            ret = [x, y]
          end
          ret
        end
        ps = []
        colors = []
        ps << vpos.(x - 1, y - 1)
        ps << vpos.(x    , y - 1)
        ps << vpos.(x + 1, y - 1)
        ps << vpos.(x - 1, y    )
        ps << [x, y]
        ps << vpos.(x + 1, y    )
        ps << vpos.(x - 1, y + 1)
        ps << vpos.(x    , y + 1)
        ps << vpos.(x + 1, y + 1)
        ps.each {|pos| colors << ChunkyPNG::Color.to_hsv(img[pos[0], pos[1]], true)}
        colors.reject! {|color| color == [0, 0.0, 0.0, 0]}
        final_color = [0, 0.0, 0.0, 0]
        colors.each do |color|
          final_color[0] += color[0]
          final_color[1] += color[1]
          final_color[2] += color[2]
          final_color[3] += color[3]
        end
        final_color[0] /= colors.size
        final_color[1] /= colors.size
        final_color[2] /= colors.size
        final_color[3] /= colors.size
        puts "FINAL_COLOR: #{final_color}"
        img[x, y] = ChunkyPNG::Color.from_hsv(final_color[0].abs, final_color[1], final_color[2], final_color[3].to_i)
        #colors.reject! {|color| color == 0}
        #colors.each {|color| ratio_sum += old_color.to_f / color.to_f}
        #ratio = ratio_sum / colors.size
        #puts "#{[x, y]}: #{ratio}"
      end
    end
    img.save('test_output.png')
  end
  
end
