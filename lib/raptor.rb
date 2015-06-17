require 'raptor/grid_hash'
require 'raptor/data_generator'
require 'oily_png'
module RAPTOR

  def self.rotation_percent_error(expected, actual)
    (expected[0].to_f - actual[0].to_f) / actual[0].to_f +
    (expected[1].to_f - actual[1].to_f) / actual[1].to_f +
    (expected[2].to_f - actual[2].to_f) / actual[2].to_f / 3.0
  end

  def self.experiment(img_dir)
    puts "Experiment started using #{img_dir}"
    gh = RAPTOR::GridHash.new
    gh.process_images(img_dir)
    imgs = []
    puts "Loading list of images..."
    Dir.glob("#{img_dir}/**/*.png") do |file|
      imgs << file
    end
    test_set = []
    10.times do
      test_set << imgs.sample
    end
    test_set.each do |img_path|
      puts "Testing #{img_path}..."
      counts = gh.identify_rotation(img_path)

    end
  end

  def self.test_filter(img)
    img = ChunkyPNG::Image.from_file(img) if img.is_a? String
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
        old_color_hsv = ChunkyPNG::Color.to_hsv(old_color, true)
        colors.each do |color|
          final_color[0] += (color[0] - old_color_hsv[0]).abs
          final_color[1] += (color[1] - old_color_hsv[1]).abs
          final_color[2] += (color[2] - old_color_hsv[2]).abs
          final_color[3] += (color[3] - old_color_hsv[3]).abs
        end
        final_color[0] /= colors.size
        final_color[1] /= colors.size
        final_color[2] /= colors.size
        final_color[3] /= colors.size
        img[x, y] = ChunkyPNG::Color.from_hsv(final_color[0], final_color[1], final_color[2], final_color[3])
      end
    end
    #img.save('test_output.png')
    img
  end

end
