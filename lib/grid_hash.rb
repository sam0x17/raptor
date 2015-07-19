class GridHash

  def initialize(dataset, num_centroids, verbose=true)
    intensities = {}
    i = 0
    dataset.img_paths.each do |path|
      i += 1
      grad = get_image_intensity_gradient(path)
      width = grad.size
      height = grad[0].size
      print " " * 80 if verbose
      print "\r" if verbose
      print "Collecting intensity data from image ##{i}/#{dataset.img_paths.size}..." if verbose
      width.times do |x|
        height.times do |y|
          intensities[grad[x][y]] = true
        end
      end
    end
    intensities = intensities.keys
    puts "" if verbose
    puts "Running k-means..." if verbose
    @kmeans = KMeansIntensity.new(intensities, num_centroids)
    @grid = {}
    @orientations = {}
    puts "Collecting per-pixel pose information..."
    i = 0
    dataset.img_paths.each do |path|
      i += 1
      print " " * 80 if verbose
      print "\r" if verbose
      print "Analyzing image ##{i}/#{dataset.img_paths.size}..." if verbose
      $stdout.flush
      img = ChunkyPNG::Image.from_file(path)
      rx = img.metadata['rx'].to_f
      ry = img.metadata['ry'].to_f
      rz = img.metadata['rz'].to_f
      grad = get_image_intensity_gradient(img)
      width = grad.size
      height = grad[0].size
      width.times do |x|
        height.times do |y|
          next if grad[x][y] == -1
          intensity = @kmeans.closest_intensity(grad[x][y])
          intensity_diff = intensity[1]
          intensity = intensity[0]
          key = [x, y, intensity]
          @grid[key] = [] if !@grid.has_key?(key)
          orientation = [rx, ry, rz]
          @orientations[orientation] = @orientations.size + 1 if !@orientations.has_key?(orientation)
          orientation_id = @orientations[orientation]
          @grid[key] << orientation_id
        end
      end
    end
    puts "" if verbose
  end

  def identify_orientation(img, return_multiple=false)
    img = ChunkyPNG::Image.from_file(img) if img.is_a? String
    counts = {}
    @orientations.each do |orientation, orientation_id|
      counts[orientation_id] = 0.0
    end
    width = img.dimension.width
    height = img.dimension.height
    grad = get_image_intensity_gradient(img)
    width.times do |x|
      height.times do |y|
        next if grad[x][y] == -1
        intensity = @kmeans.closest_intensity(grad[x][y])
        intensity_diff = intensity[1]
        intensity = intensity[0]
        key = [x, y, intensity]
        orientations = @grid[key]
        next if orientations.nil?
        orientations.each do |orientation_id|
          counts[orientation_id] += intensity
        end
      end
    end
    if return_multiple
      counts = counts.sort_by(&:last)
      ret = []
      counts.each do |orientation_id, count|
        @orientations_inverted = @orientations.invert if !@orientations_inverted
        orientation = @orientations_inverted[orientation_id]
        ret << {orientation: orientation, id: orientation_id, confidence: count}
      end
      return ret
    end
    best_count = 0
    best_orientation_id = nil
    counts.each do |orientation_id, count|
      if count > best_count
        best_count = count
        best_orientation_id = orientation_id
      end
    end
    @orientations_inverted = @orientations.invert if !@orientations_inverted
    best_orientation = @orientations_inverted[best_orientation_id]
    {orientation: best_orientation, id: best_orientation_id, confidence: best_count}
  end

end
