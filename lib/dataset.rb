require 'facter'
class Dataset
  @@models = {}

  def m
    @m
  end

  def model
    @model
  end

  def model_path
    @model_path
  end

  def render_width
    @render_width
  end

  def render_height
    @render_height
  end

  def autocrop?
    @autocrop
  end

  def verbose?
    @verbose
  end

  def imgs_dir
    @imgs_dir
  end

  def img_paths
    @img_paths
  end

  def initialize(data_options={})
    # set up options
    set_default = Proc.new {|key,value| data_options[key] = value if !data_options.has_key?(key) }
    set_default.(:m, 5) # num samples ^ (1/3)
    set_default.(:model, :hamina) # default model symbol to use (can be registered with register_model)
    set_default.(:width, 60) # width of rendered images
    set_default.(:height, 60) # height of rendered images
    set_default.(:autocrop, true) # whether autocropping should be used
    set_default.(:verbose, true) # whether verbose status messages should be displayed
    set_default.(:imgs_dir, Dataset.find_imgs_dir(data_options))
    @m = data_options[:m]
    @model = data_options[:model]
    @model_path = Dataset.model_path(@model)
    @render_width = data_options[:width]
    @render_height = data_options[:height]
    @autocrop = data_options[:autocrop]
    @imgs_dir = data_options[:imgs_dir]
    @verbose = data_options[:verbose]
    puts "Dataset: '#{data_options[:imgs_dir]}'" if verbose?

    # create data directory (if applicable)
    FileUtils.mkdir_p(@imgs_dir)

    # prepare list of poses
    m = @m
    step = 2.0 / m
    m -= 1
    rx_set = (0..m).to_a.collect { |n| n * step - 1.0 }
    ry_set = rx_set.clone
    rz_set = rx_set.clone
    final_set = []
    rx_set.each do |rx|
      ry_set.each do |ry|
        rz_set.each do |rz|
          final_set << [rx, ry, rz]
        end
      end
    end
    puts "Total samples: #{final_set.size}" if verbose?

    # spread out poses over available CPU cores
    num_cores = Facter.value('processors')['count']
    last_core = 0
    core_sets = {}
    num_cores.times {|core_num| core_sets[core_num] = {} }
    i = 1
    final_set.each do |val|
      core_sets[last_core][i] = val
      last_core += 1
      last_core = 0 if last_core >= num_cores
      i += 1
    end

    # create threads and begin rendering
    current_core = 0
    max_width = 80
    threads = []
    mut = Mutex.new
    core_sets.values.each do |core_set|
      current_core += 1
      threads << Thread.new(current_core, core_set, data_options, final_set.size) do |icurrent_core, icore_set, idata_options, final_set_size|
        icore_set.each do |img_num, orientation|
          rx = orientation[0]
          ry = orientation[1]
          rz = orientation[2]
          pose = {}
          pose[:img_filename] = "#{idata_options[:imgs_dir]}/#{img_num.to_s.rjust(7, '0')}.png"
          pose[:width] = idata_options[:width]
          pose[:height] = idata_options[:height]
          pose[:autocrop] = idata_options[:autocrop]
          pose[:model] = idata_options[:model]
          pose[:rx] = rx.to_s.to_f.to_s
          pose[:ry] = ry.to_s.to_f.to_s
          pose[:rz] = rz.to_s.to_f.to_s

          # skip existing images if applicable
          if File.exist?(pose[:img_filename])
            if idata_options[:verbose]
              mut.lock
              st = " " * max_width
              st += "\r"
              print st
              st = "Skipping existing pose: #{[rx.round(4), ry.round(4), rz.round(4)]}\r"
              max_width = st.size if st.size > max_width
              print st
              $stdout.flush
              mut.unlock
            end
            next
          end

          # otherwise render the pose
          if idata_options[:verbose]
            mut.lock
            st = " " * max_width
            st += "\r"
            print st
            st = "Core #{icurrent_core}: rendering pose ##{img_num}/#{final_set_size} #{[rx.round(4), ry.round(4), rz.round(4)]}...\r"
            max_width = st.size if st.size > max_width
            print st
            $stdout.flush
            mut.unlock
          end
          Dataset.render_pose(pose)
        end
        Thread.exit
      end
    end
    threads.each {|t| t.join}
    sleep(0.2)
    puts "" if verbose?
    puts "Successfully rendered/loaded #{final_set.size} samples!" if verbose?
    puts "Caching sample filenames..." if verbose?
    @img_paths = []
    Dir.glob("#{@imgs_dir}/**/*.png") do |file|
      @img_paths << file
    end
    puts "Sorting sample filenames..." if verbose?
    @img_paths.sort!
    true
  end
  
  def self.render_test_set(num_samples, data_options={})
    # set up options
    set_default = Proc.new {|key,value| data_options[key] = value if !data_options.has_key?(key) }
    set_default.(:m, 5) # num samples ^ (1/3)
    set_default.(:model, :hamina) # default model symbol to use (can be registered with register_model)
    set_default.(:width, 60) # width of rendered image 
    set_default.(:height, 60) # height of rendered images
    set_default.(:autocrop, true) # whether autocropping should be used
    set_default.(:verbose, true) # whether verbose status messages should be displayed
    set_default.(:imgs_dir, Dataset.find_imgs_dir(data_options))
    puts "Dataset: '#{data_options[:imgs_dir]}'" if verbose?

    # create data directory (if applicable)
    FileUtils.mkdir_p(@imgs_dir)

    # prepare list of poses
    m = @m
    step = 2.0 / m
    m -= 1
    rx_set = (0..m).to_a.collect { |n| n * step - 1.0 }
    ry_set = rx_set.clone
    rz_set = rx_set.clone
    final_set = []
    rx_set.each do |rx|
      ry_set.each do |ry|
        rz_set.each do |rz|
          final_set << [rx, ry, rz]
        end
      end
    end
    puts "Total samples: #{final_set.size}" if verbose?

    # spread out poses over available CPU cores
    num_cores = Facter.value('processors')['count']
    last_core = 0
    core_sets = {}
    num_cores.times {|core_num| core_sets[core_num] = {} }
    i = 1
    final_set.each do |val|
      core_sets[last_core][i] = val
      last_core += 1
      last_core = 0 if last_core >= num_cores
      i += 1
    end

    # create threads and begin rendering
    current_core = 0
    max_width = 80
    threads = []
    mut = Mutex.new
    core_sets.values.each do |core_set|
      current_core += 1
      threads << Thread.new(current_core, core_set, data_options, final_set.size) do |icurrent_core, icore_set, idata_options, final_set_size|
        icore_set.each do |img_num, orientation|
          rx = orientation[0]
          ry = orientation[1]
          rz = orientation[2]
          pose = {}
          pose[:img_filename] = "#{idata_options[:imgs_dir]}/#{img_num.to_s.rjust(7, '0')}.png"
          pose[:width] = idata_options[:width]
          pose[:height] = idata_options[:height]
          pose[:autocrop] = idata_options[:autocrop]
          pose[:model] = idata_options[:model]
          pose[:rx] = rx.to_s.to_f.to_s
          pose[:ry] = ry.to_s.to_f.to_s
          pose[:rz] = rz.to_s.to_f.to_s

          # skip existing images if applicable
          if File.exist?(pose[:img_filename])
            if idata_options[:verbose]
              mut.lock
              st = " " * max_width
              st += "\r"
              print st
              st = "Skipping existing pose: #{[rx.round(4), ry.round(4), rz.round(4)]}\r"
              max_width = st.size if st.size > max_width
              print st
              $stdout.flush
              mut.unlock
            end
            next
          end

          # otherwise render the pose
          if idata_options[:verbose]
            mut.lock
            st = " " * max_width
            st += "\r"
            print st
            st = "Core #{icurrent_core}: rendering pose ##{img_num}/#{final_set_size} #{[rx.round(4), ry.round(4), rz.round(4)]}...\r"
            max_width = st.size if st.size > max_width
            print st
            $stdout.flush
            mut.unlock
          end
          Dataset.render_pose(pose)
        end
        Thread.exit
      end
    end
    threads.each {|t| t.join}
    sleep(0.2)
    puts "" if verbose?
    puts "Successfully rendered/loaded #{final_set.size} samples!" if verbose?
    puts "Caching sample filenames..." if verbose?
    @img_paths = []
    Dir.glob("#{@imgs_dir}/**/*.png") do |file|
      @img_paths << file
    end
    puts "Sorting sample filenames..." if verbose?
    @img_paths.sort!
    true
  end

  def self.render_pose(pose={})
    sw = nil
    sh = nil
    rw = pose[:width]
    rh = pose[:height]
    pose[:model] = Dataset.model_path(pose[:model]) if pose[:model].is_a? Symbol
    if pose[:autocrop]
      rw = (pose[:width] * 4.0).round
      rh = (pose[:height] * 4.0).round
      sw = pose[:width]
      sh = pose[:height]
    end
    system({"model" => pose[:model],
            "rx" => pose[:rx].to_s, "ry" => pose[:ry].to_s, "rz" => pose[:rz].to_s,
            "width" => rw.to_s, "height" => rh.to_s,
            "img_filename" => pose[:img_filename]},
            'blender -b -P render.py > /dev/null')
    img = ChunkyPNG::Image.from_file(pose[:img_filename])
    if pose[:autocrop]
      dest_w = pose[:width]
      dest_h = pose[:height]
      img.trim!(0)
      resize_bounds = smart_resize_bounds(img.dimension.width,
                                          img.dimension.height,
                                          sw,
                                          sh)
      img.resample_bilinear!(resize_bounds[:w], resize_bounds[:h])
      img2 = ChunkyPNG::Image.new(sw, sh)
      img2.compose!(img, resize_bounds[:x], resize_bounds[:y])
      img = img2
      img2 = nil
    end
    img.metadata['rx'] = pose[:rx].to_s
    img.metadata['ry'] = pose[:ry].to_s
    img.metadata['rz'] = pose[:rz].to_s
    img.save(pose[:img_filename])
    pose
  end

  def self.register_model(symbol, path)
    @@models[symbol] = path
  end

  def self.model_path(symbol)
    @@models[symbol]
  end

  def self.find_imgs_dir(options={})
    "data/imgs/#{options[:model]} #{options[:width]}x#{options[:height]} m-#{options[:m]} crop-#{options[:autocrop] ? 't' : 'f'} "
  end
end
