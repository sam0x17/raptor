class GridHash

  def initialize(dataset, num_centroids, verbose=true)
    puts "Collecting intensity information..." if verbose
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
    puts "Running k-means..." if verbose
    @kmeans = KMeansIntensity.new(intensities, num_centroids)
    @grid = {}
    @orientations = {}
    puts "Collecting per-pixel pose information..."
    dataset.img_paths.each do |path|
      print " " * 80 if verbose
      print "\r" if verbose
      print "Analyzing image ##{i}/#{dataset.img_paths.size}...\r" if verbose
      img = ChunkyPNG::Image.from_file(path)
      rx = img.metadata['rx'].to_f
      ry = img.metadata['ry'].to_f
      rz = img.metadata['rz'].to_f
      grad = get_image_intensity_gradient(img)
      width = grad.size
      height = grad[0].size
      width.times do |x|
        height.times do |y|
          intensity = @kmeans.closest_intensity(grad[x][y])
          intensity_diff = intensity[1]
          intensity = intensity[0]
          @grid[[x, y]] = {} if !@grid.has_key?([x, y])
          @grid[[x, y]][intensity] = [] if !@grid[[x, y]].has_key?(intensity)
          orientation = [rx, ry, rz]
          @orientations[orientation] = @orientations.size if !@orientations.has_key?(orientation)
          orientation_id = @orientations[orientation]
          @grid[[x, y]][intensity] << orientation_id
        end
      end
    end
  end

end
