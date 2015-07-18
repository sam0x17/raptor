class KMeansIntensity

  def initialize(intensities, num_centroids)
    num_centroids -= 2
    chosen_centroids = intensities.sample(num_centroids)
    groups = {}
    num_iterations = 0
    refresh_centroids = Proc.new do
      num_iterations += 1
      chosen_centroids = []
      groups.each do |centroid, group|
        avg_intensity = 0.0
        group.keys.each do |intensity|
          avg_intensity += intensity
        end
        avg_intensity /= group.size.to_f
        chosen_centroids << avg_intensity.round
      end
    end
    regroup = Proc.new do
      groups = {}
      chosen_centroids.each {|centroid| groups[centroid] = {}}
      intensities.each do |intensity|
        diffs = {}
        chosen_centroids.each do |centroid_intensity|
          diffs[centroid_intensity] = (intensity - centroid_intensity).abs
        end
        best_match = diffs.invert.min
        groups[best_match[1]][intensity] = true
      end
    end
    # begin iterations
    prev_iterations = {}
    regroup.()
    old_groups = groups
    while true
      refresh_centroids.()
      regroup.()
      key = []
      groups.each do |centroid_intensity, centroid_set|
        key << centroid_intensity
      end
      key.sort!
      puts "#{key}"
      break if prev_iterations.has_key?(key)
      prev_iterations[key] = true
    end
    chosen_centroids << 0
    chosen_centroids << 255
    chosen_centroids.sort!
    puts "#{chosen_centroids}"
    @centroids = chosen_centroids
  end

  def closest_intensity(intensity)
    best_match_diff = nil
    best_match = nil
    @centroids.each do |possible_match|
      diff = (intensity - possible_match).abs
      if !best_match || diff < best_match_diff
        best_match = possible_match
        best_match_diff = diff
      end
    end
    [best_match, best_match_diff]
  end

end
