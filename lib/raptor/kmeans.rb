require 'color'
module RAPTOR
  class KMeans

    def self.test
      img = ChunkyPNG::Image.from_file('test_data/hamina.png')
      width = img.dimension.width
      height = img.dimension.height
      colors = {}
      puts "loading image..."
      height.times do |y|
        width.times do |x|
          color = img[x, y]
          next if color == 0
          color = RAPTOR::GridHash.filter_color(color)
          colors[color] = true
        end
        if y % 100 == 0
          puts "y: #{y}"
        end
      end
      #byte_range = (0..255).to_a
      #colors = []
      #2000.times do
      #  colors << [byte_range.sample, byte_range.sample, byte_range.sample]
      #end
      puts "done reading image"
      puts "num unique colors: #{colors.size}"
      colors = colors.keys
      num_clusters = 8
      puts "attempting to create #{num_clusters} clusters"
      $kmeans = KMeans.new(colors, num_clusters)
      puts "created #{num_clusters} clusters"
      puts "loading carrier image..."
      img = ChunkyPNG::Image.from_file('test_data/carriers.png')
      width = img.dimension.width
      height = img.dimension.height
      height.times do |y|
        width.times do |x|
          color = img[x, y]
          next if color == 0
          img[x, y] = $kmeans.closest_color(color)
        end
        if y % 100 == 0
          puts "y: #{y}"
        end
      end
      puts "saving..."
      img.save('test_output.png')
      puts "done done"
      true
    end

    def self.filter_nan(n)
      return 0 if n.nan?
      return n.round
    end

    def initialize(colors, num_centroids)
      filter_nan = Proc.new {|n| n.nan? ? 0 : n.round }
      sortable_colors = []
      colors.each do |color|
        sortable_colors << GridHash::SortableColor.new(color)
      end
      colors = sortable_colors
      chosen_centroids = colors.sample(num_centroids)
      #colors.sort!
      #chosen_centroids = nil
      #best_deltaE = nil
      #10.times do
      #  centroid_set = colors.sample(num_centroids)
      #  centroid_set_combs = centroid_set.combination(2).to_a
      #  avg_deltaE = 0.0
      #  centroid_set_combs.each do |pair|
      #    avg_deltaE += pair[0].get_deltaE(pair[1])
      #  end
      #  avg_deltaE /= centroid_set_combs.size
      #  if chosen_centroids.nil? || avg_deltaE > best_deltaE
      #    chosen_centroids = centroid_set
      #    best_deltaE = avg_deltaE
      #  end
      #end
      groups = {}
      num_iterations = 0
      refresh_centroids = Proc.new do
        num_iterations += 1
        chosen_centroids = []
        groups.each do |centroid, group|
          hsl_avg = [0.0, 0.0, 0.0]
          group.keys.each do |color|
            hsl = color.hsl.to_a
            hsl_avg[0] += hsl[0]
            hsl_avg[1] += hsl[1]
            hsl_avg[2] += hsl[2]
          end
          gs = group.size.to_f
          hsl_avg[0] /= gs
          hsl_avg[1] /= gs
          hsl_avg[2] /= gs
          avg_color = Color::HSL.from_fraction(hsl_avg[0], hsl_avg[1], hsl_avg[2]).to_rgb
          avg_color = [filter_nan.(avg_color.red),
                       filter_nan.(avg_color.green),
                       filter_nan.(avg_color.blue)]
          avg_color = RAPTOR::GridHash::SortableColor.new(avg_color)
          chosen_centroids << avg_color
        end
      end
      regroup = Proc.new do
        groups = {}
        chosen_centroids.each {|centroid| groups[centroid] = {}}
        colors.each do |color|
          deltas = {}
          chosen_centroids.each do |centroid_color|
            deltas[centroid_color] = centroid_color.get_deltaE(color)
          end
          best_match = deltas.invert.min
          groups[best_match[1]][color] = true
        end
      end
      # begin algorithm iterations
      prev_iterations = {}
      regroup.()
      old_groups = groups
      while true
        refresh_centroids.()
        regroup.()
        key = []
        groups.each do |centroid_color, centroid_set|
          key << centroid_color.chunky
        end
        puts "#{key}"
        break if prev_iterations.has_key?(key)
        prev_iterations[key] = true
      end
      @centroids = chosen_centroids
      @conversion_cache = {}
      #groups.each do |centroid_color, centroid_set|
      #  centroid_set.each do |color, skip|
      #    @conversion_cache[color.chunky] = centroid_color.chunky
      #  end
      #end
      @centroids.each do |centroid_color|
        @conversion_cache[centroid_color.chunky] = centroid_color.chunky
      end
      #puts "calculating deltaE threshold..."
      #avg_deltaE = 0.0
      #combs = @centroids.combination(2).to_a
      #combs.each do |pair|
      #  avg_deltaE += pair[0].get_deltaE(pair[1])
      #end
      #avg_deltaE /= combs.size
      #@deltaE_threshold = avg_deltaE * 1.2
      #puts "done initializing"
      true
    end

    def centroids
      @centroids
    end

    def closest_color(chunky_color)
      color_match = @conversion_cache[chunky_color]
      return color_match if !color_match.nil?
      best_deltaE = nil
      color = RAPTOR::GridHash::SortableColor.new(chunky_color)
      centroids.each do |index_color|
        deltaE = color.get_deltaE(index_color)
        if best_deltaE.nil? || deltaE < best_deltaE
          best_deltaE = deltaE
          color_match = index_color
        end
      end
      #if best_deltaE > @deltaE_threshold
      #  color_match = 0
      #else
      color_match = color_match.chunky
      #end
      @conversion_cache[chunky_color] = color_match
      color_match
    end

  end
end
