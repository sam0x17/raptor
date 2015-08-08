class GridHash

  def initialize(dataset, num_centroids=10, verbose=true)
    intensities = {}
    i = 0
    grads = []
    dataset.img_paths.each do |img_path|
      img = ChunkyPNG::Image.from_file(img_path)
      i += 1
      grad = get_image_intensity_gradient(img)
      grads << grad
      width = img.dimension.width
      height = img.dimension.height
      print " " * 80 if verbose
      print "\r" if verbose
      print "Collecting intensity data from image ##{i}/#{dataset.img_paths.size}..." if verbose
      width.times do |x|
        height.times do |y|
          t = grad[[x, y]]
          intensities[t] = true if !t.nil?
        end
      end
    end
    intensities = intensities.keys
    puts "" if verbose
    #puts "Creating intensity space" if verbose
    #@intensity_space = IntensitySpace.new(intensities)
    puts "Running k-means..." if verbose
    @kmeans = KMeansIntensity.new(intensities, num_centroids)
    @grid = {}
    @orientations = {}
    puts "Collecting per-pixel pose information..."
    i = 0
    dataset.img_paths.each do |img_path|
      img = ChunkyPNG::Image.from_file(img_path)
      i += 1
      print " " * 80 if verbose
      print "\r" if verbose
      print "Analyzing image ##{i}/#{dataset.img_paths.size}..." if verbose
      $stdout.flush
      rx = img.metadata['rx'].to_f
      ry = img.metadata['ry'].to_f
      rz = img.metadata['rz'].to_f
      grad = grads[i - 1]
      width = img.dimension.width
      height = img.dimension.height
      width.times do |x|
        height.times do |y|
          next if grad[[x, y]] == nil
          intensity = @kmeans.closest_intensity(grad[[x, y]])
          intensity_diff = intensity[1]
          intensity = intensity[0]
          #intensity = @intensity_space.closest_intensity(grad[[x, y]])
          key = [x, y, intensity]
          @grid[key] = [] if !@grid.has_key?(key)
          orientation = [rx, ry, rz]
          @orientations[orientation] = @orientations.size + 1 if !@orientations.has_key?(orientation)
          orientation_id = @orientations[orientation]
          @grid[key] << orientation_id
        end
      end
    end
    grads = nil
    @orientations_inverted = @orientations.invert
    puts "" if verbose
  end

  VPOS = Proc.new do |tx, ty, x, y, width, height|
    ret = nil
    if tx >= 0 && tx < width && ty >= 0 && ty < height
      ret = [tx, ty]
    else
      ret = [x, y]
    end
    ret
  end

  def identify_orientation(img, return_multiple=false)
    img = ChunkyPNG::Image.from_file(img) if img.is_a? String
    counts = {}
    @orientations_inverted.keys.each do |orientation_id|
      counts[orientation_id] = 0
    end
    width = img.dimension.width
    height = img.dimension.height
    width.times do |x|
      height.times do |y|
        orig_color = img[x, y]
        next if orig_color == 0
        orig_color_bytes = ChunkyPNG::Color.to_truecolor_bytes(orig_color)
        points = [
         VPOS.(x - 1, y, x, y, width, height),
         #VPOS.(x - 1, y - 1, x, y, width, height),
         VPOS.(x, y - 1, x, y, width, height)
        ]
        avg_diff = 0.0
        points.each do |point|
          color_bytes = ChunkyPNG::Color.to_truecolor_bytes(img[point[0], point[1]])
          avg_diff += (color_bytes[0] - orig_color_bytes[0]).abs.to_f
          avg_diff += (color_bytes[1] - orig_color_bytes[1]).abs.to_f
          avg_diff += (color_bytes[2] - orig_color_bytes[2]).abs.to_f
        end
        avg_diff /= points.size.to_f * 3.0
        closest = @kmeans.closest_intensity(avg_diff.round)[0]
        #closest =  @intensity_space.closest_intensity(avg_diff.round)
        orientations = @grid[[x, y, closest]]
        next if orientations.nil?
        orientations.each do |orientation_id|
          counts[orientation_id] += 1
        end
      end
    end
    if return_multiple
      counts = counts.sort_by(&:last)
      ret = []
      counts.each do |orientation_id, count|
        orientation = @orientations_inverted[orientation_id]
        ret << {orientation: orientation, id: orientation_id, confidence: count}
      end
      return ret
    end
    best_count = 0
    best_orientation_id = nil
    counts.each do |orientation_id, count|
      if count > best_count
        best_orientation_id = orientation_id
        best_count = count
      end
    end
    best_orientation = @orientations_inverted[best_orientation_id]
    return {orientation: best_orientation, id: best_orientation_id, confidence: best_count}
  end

end
