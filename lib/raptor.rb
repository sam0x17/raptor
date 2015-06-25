require 'raptor/grid_hash'
require 'raptor/data_generator'
require 'oily_png'
require 'fileutils'
module RAPTOR

  def self.rotation_percent_error(expected, actual)
    (((expected[0].to_f - actual[0].to_f) / 1.0).abs +
    ((expected[1].to_f - actual[1].to_f) / 1.0).abs +
    ((expected[2].to_f - actual[2].to_f) / 1.0).abs) / 3.0
  end

  def self.rotation_euclidean_error(expected, actual)
    RAPTOR.euclidean_distance(expected, actual)
  end

  def self.euclidean_distance(p, q)
    a = q[0] - p[0]
    b = q[1] - p[1]
    c = q[2] - p[2]
    Math.sqrt(a*a + b*b + c*c)
  end

  def self.interpolate(r1, r2, w1, w2)
    v = [r2[0] - r1[0], r2[1] - r1[1], r2[2] - r1[2]]
    total_dist = RAPTOR.euclidean_distance(r1, r2)
    f = w1.to_f / (w1 + w2)
    [r1[0] + f*v[0], r1[1] + f*v[1], r1[2] + f*v[2]]
  end

  def self.experiment(img_dir, interpolate=false, euclidean_error=false)
    puts "Experiment started using #{img_dir}"
    $gh = RAPTOR::GridHash.new
    $gh.process_images(img_dir)
    imgs = []
    puts "Loading list of images..."
    Dir.glob("#{img_dir}/**/*.png") do |file|
      imgs << file
    end
    puts "Ensuring that image set is unique..."
    imgs.uniq!
    puts "Randomly shuffling image set..."
    imgs.shuffle!
    puts "Performing tests..."
    test_set = imgs.first(1000)
    avg_err = 0.0
    test_set.each do |img_path|
      puts "Testing #{img_path}..."
      counts = $gh.identify_rotation(img_path).to_a.last(8)
      expected = counts.last[0]
      puts "expected: |#{expected}|"
      expected_str = $gh.get_file_index_by_rotation(expected)
      test_dir = "experiment_output/#{expected_str}"
      puts "attempting to make directory #{test_dir}"
      Dir.mkdir(test_dir)
      i = counts.size - 1
      counts.each do |arr|
        rot = arr[0]
        count = arr[1]
        item_str = $gh.get_file_index_by_rotation(rot).to_s.rjust(7, "0")
        error = RAPTOR.rotation_percent_error(expected, rot) if !euclidean_error
        error = RAPTOR.rotation_euclidean_error(expected, rot) if euclidean_error
        FileUtils.cp("#{img_dir}/#{item_str}.png", "#{test_dir}/#{i}.png")
        puts "#{arr[0]}\t=>\t#{arr[1]} : #{error}" if !interpolate
        avg_err += error if i == 1 && !interpolate
        i -= 1
      end
      if interpolate
        real = counts[counts.size - 1]
        guess1 = counts[counts.size - 2]
        guess2 = counts[counts.size - 3]
        interp = RAPTOR.interpolate(guess1[0], guess2[0], guess1[1], guess2[1])
        error = RAPTOR.rotation_percent_error(real[0], interp) if !euclidean_error
        error = RAPTOR.rotation_euclidean_error(real[0], interp) if euclidean_error
        puts "#{error}\t#{interp}"
        avg_err += error
      end
    end
    puts "# tests: #{test_set.size}"
    puts "RAPTOR memory usage: #{$gh.memory_size} bytes"
    avg_err = avg_err / test_set.size.to_f
    puts "Average % error: #{avg_err}"
    true
  end

  def self.image_gradient(img)
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
