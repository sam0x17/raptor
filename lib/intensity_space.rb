class IntensitySpace

  def initialize(intensities)
    intensities = intensities.clone
    intensities << 0
    intensities << 255
    intensities.uniq!
    @intensities = intensities
    @cache = {}
    @intensities.each do |intensity|
      # initialize cache
      closest_intensity(intensity)
    end
  end

  def closest_intensity(intensity)
    cache_hit = @cache[intensity]
    return cache_hit if !cache_hit.nil?
    best_match_diff = nil
    best_match = nil
    @intensities.each do |possible_match|
      diff = (intensity - possible_match).abs
      if !best_match || diff < best_match_diff
        best_match = possible_match
        best_match_diff = diff
      end
    end
    #ret = [best_match, best_match_diff]
    @cache[intensity] = best_match
    return best_match
  end

end
