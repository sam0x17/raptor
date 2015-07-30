
def euclidean_distance_3d(p, q)
  a = q[0] - p[0]
  b = q[1] - p[1]
  c = q[2] - p[2]
  Math.sqrt(a*a + b*b + c*c)
end

def euclidean_distance_2d(p, q)
  a = q[0] - p[0]
  b = q[1] - p[1]
  Math.sqrt(a*a + b*b)
end

def point_along_line_2d(origin, direction, distance)
  [origin[0] + direction[0] * distance,
   origin[1] + direction[1] * distance]
end

def mag2d(v)
  Math.sqrt(v[0]*v[0] + v[1]*v[1])
end

def norm2d(v)
  mag = mag2d(v)
  [v[0] / mag,
   v[1] / mag]
end

def random_direction_2d
  unit_circle_pt(rand(0.0..1.0))
end

def unit_circle_pt(dist)
t = (2.0 * Math::PI) * dist
[Math.cos(t), Math.sin(t)]
end

def random_image_pixel(img, origin, dist_range=nil, ignore_color=0, ignore_cutoff=20)
  color = nil
  pos = nil
  distance = nil
  ignores = 0
  origin = [origin[0].to_f, origin[1].to_f]
  if dist_range.nil?
    dist_range = (1.0..mag2d([img.dimension.width - 1.0, img.dimension.height - 1.0]))
  else
    dist_range = (dist_range.first.to_f..dist_range.last.to_f)
  end
  while true
    ignores += 1
    direction = random_direction_2d
    distance = rand(dist_range)
    pos = point_along_line_2d(origin, direction, distance)
    pos = [pos[0].round, pos[1].round]
    next if pos[0] < 0 || pos[0] >= img.dimension.width ||
             pos[1] < 0 || pos[1] >= img.dimension.height
    color = img[pos[0], pos[1]]
    next if !ignore_color.nil? && color == ignore_color
    return nil if ignores >= ignore_cutoff
    break
  end
  [color, pos, distance]
end

def orientation_percent_error(expected, actual)
  ((((expected[0].to_f - actual[0].to_f) / 1.0).abs +
  ((expected[1].to_f - actual[1].to_f) / 1.0).abs +
  ((expected[2].to_f - actual[2].to_f) / 1.0).abs) / 3.0) / 2.0
end

def directory_size(path)
  path << '/' unless path.end_with?('/')

  raise RuntimeError, "#{path} is not a directory" unless File.directory?(path)

  total_size = 0
  Dir["#{path}**/*"].each do |f|
    total_size += File.size(f) if File.file?(f) && File.size?(f)
  end
  total_size
end

def smart_resize_bounds(sw, sh, dw, dh)
  raise "dest width and dest height cannot both be nil!"  if dw.nil? && dh.nil?
  voff = 0.0; hoff = 0.0
  tdw = dw; tdh = dh;
  tsw = sw; tsh = sh;
  tdw = tdh * tsw / tsh if dw.nil?
  tdh = tdw * tsh / tsw if dh.nil?
  if !dw.nil? && !dh.nil?
    voff = tdh - (tsh * tdw) / tsw
    hoff = tdw - (tdh * tsw) / tsh
    voff = 0.0 if voff < 0.0
    hoff = 0.0 if hoff < 0.0
  end
  x = (hoff / 2.0).floor
  y = (voff / 2.0).floor
  w = (tdw - hoff).floor
  h = (tdh - voff).floor
  while true
    w += 1; next if w + x * 2 < dw
    w -= 1; next if w + x * 2 > dw
    h += 1; next if h + y * 2 < dh
    h -= 1; next if h + y * 2 > dh
    break
  end
  {x: x, y: y, w: w, h: h}
end

def get_image_intensity_gradient(img)
  img = ChunkyPNG::Image.from_file(img) if img.is_a? String
  width = img.dimension.width
  height = img.dimension.height
  grid = {}
  width.times do |x|
    height.times do |y|
      orig_color = img[x, y]
      next if orig_color == 0
      vpos = Proc.new do |tx, ty|
        ret = nil
        if tx >= 0 && tx < width && ty >= 0 && ty < height
          ret = [tx, ty]
        else
          ret = [x, y]
        end
        ret
      end
      points = []
      points << vpos.(x - 1, y)
      points << vpos.(x - 1, y - 1)
      points << vpos.(x, y - 1)
      colors = []
      points.each {|point| colors << ChunkyPNG::Color.to_truecolor_bytes(img[point[0], point[1]])}
      orig_color_bytes = ChunkyPNG::Color.to_truecolor_bytes(orig_color)
      avg_diff = [0.0, 0.0, 0.0]
      colors.each do |color|
        diff = [(color[0] - orig_color_bytes[0]).abs,
                (color[1] - orig_color_bytes[1]).abs,
                (color[2] - orig_color_bytes[2]).abs]
        avg_diff[0] += diff[0].to_f
        avg_diff[1] += diff[1].to_f
        avg_diff[2] += diff[2].to_f
      end
      avg_diff[0] = avg_diff[0] / points.size.to_f
      avg_diff[1] = avg_diff[1] / points.size.to_f
      avg_diff[2] = avg_diff[2] / points.size.to_f
      grid[[x, y]] = ((avg_diff[0].to_f + avg_diff[1].to_f + avg_diff[2].to_f) / 3.0).round
    end
  end
  grid
end

def get_image_gradient(img, grayscale=false)
  img = ChunkyPNG::Image.from_file(img) if img.is_a? String
  width = img.dimension.width
  height = img.dimension.height
  img2 = img.clone
  width.times do |x|
    height.times do |y|
      orig_color = img2[x, y]
      next if orig_color == 0
      vpos = Proc.new do |tx, ty|
        ret = nil
        if tx >= 0 && tx < width && ty >= 0 && ty < height
          ret = [tx, ty]
        else
          ret = [x, y]
        end
        ret
      end
      points = []
      points << vpos.(x - 1, y)
      points << vpos.(x - 1, y - 1)
      points << vpos.(x, y - 1)
      colors = []
      points.each {|point| colors << ChunkyPNG::Color.to_truecolor_bytes(img2[point[0], point[1]])}
      orig_color_bytes = ChunkyPNG::Color.to_truecolor_bytes(orig_color)
      avg_diff = [0.0, 0.0, 0.0]
      colors.each do |color|
        diff = [(color[0] - orig_color_bytes[0]).abs,
                (color[1] - orig_color_bytes[1]).abs,
                (color[2] - orig_color_bytes[2]).abs]
        avg_diff[0] += diff[0].to_f
        avg_diff[1] += diff[1].to_f
        avg_diff[2] += diff[2].to_f
      end
      avg_diff[0] = (avg_diff[0] / points.size).round
      avg_diff[1] = (avg_diff[1] / points.size).round
      avg_diff[2] = (avg_diff[2] / points.size).round
      if grayscale
        a = ((avg_diff[0].to_f + avg_diff[1].to_f + avg_diff[2].to_f) / 3.0).round
        avg_diff = [a, a, a]
      end
      img[x, y] = ChunkyPNG::Color.rgba(avg_diff[0], avg_diff[1], avg_diff[2], 255)
    end
    #puts "x: #{x}" if x % 100 == 0
  end
  #puts "saving image..."
  #img.save('test_output.png')
  img
end
