require 'facter'
module RAPTOR
  module DataGenerator

    def self.generate_pose(options={})
      set_default = Proc.new {|key,value| options[key] = value if !options.has_key?(key) }
      set_default.(:rx, rand(0.0..1.0))
      set_default.(:ry, rand(0.0..1.0))
      set_default.(:rz, rand(0.0..1.0))
      set_default.(:width, 100)
      set_default.(:height, 100)
      set_default.(:model, 'models/hamina.3DS')
      set_default.(:img_filename, 'output.png')
      {rx: options[:rx], ry: options[:ry], rz: options[:rz],
       width: options[:width], height: options[:height],
       model: options[:model], img_filename: options[:img_filename]}
    end

    def self.render_pose(pose={})
      required_params = [:rx, :ry, :rz, :width, :height, :model, :img_filename]
      pose.keys.each {|param_key| raise UnsupportedParamError if !required_params.include?(param_key)}
      required_params.each {|param_key| raise MissingRequiredParamError if !pose.keys.include?(param_key)}
      system({"model" => pose[:model],
              "rx" => pose[:rx].to_s, "ry" => pose[:ry].to_s, "rz" => pose[:rz].to_s,
              "width" => pose[:width].to_s, "height" => pose[:height].to_s,
              "img_filename" => pose[:img_filename]},
              'blender -b -P render.py > /dev/null')
      if $? == 1
        puts "A rendering error occured -- retrying in verbose mode"
        system({"model" => pose[:model],
                "rx" => pose[:rx].to_s, "ry" => pose[:ry].to_s, "rz" => pose[:rz].to_s,
                "width" => pose[:width].to_s, "height" => pose[:height].to_s,
                "img_filename" => pose[:img_filename]},
                'blender -b -P render.py')
        raise RenderError
      end
      img = ChunkyPNG::Image.from_file(pose[:img_filename])
      img.metadata['rx'] = pose[:rx].to_s
      img.metadata['ry'] = pose[:ry].to_s
      img.metadata['rz'] = pose[:rz].to_s
      #img = RAPTOR.test_filter(img)
      img.save(pose[:img_filename])
      true
    end

    def self.render_random_pose(options={})
      pose = RAPTOR::DataGenerator.generate_pose(options)
      RAPTOR::DataGenerator.render_pose(pose)
    end

    def self.render_partitions(points_per_dimension=16, start_index=1, end_index=nil, options={})
      data_directory = 'output'
      step = 1.0 / points_per_dimension
      points_per_dimension -= 1
      rx_set = (0..points_per_dimension).to_a.collect { |n| n * step }
      ry_set = rx_set.clone
      rz_set = rx_set.clone
      end_index = rx_set.size * ry_set.size * rz_set.size if end_index.nil?
      puts "Total series size: #{rx_set.size * ry_set.size * rz_set.size - 1}"
      puts "Attempting to render this run: #{end_index - start_index}"
      final_set = []
      rx_set.each do |rx|
        ry_set.each do |ry|
          rz_set.each do |rz|
            final_set << [rx, ry, rz]
          end
        end
      end
      tmp = []
      (start_index..end_index).to_a.each do |i|
        tmp << final_set[i] if final_set[i]
      end
      final_set = tmp
      num_cores = Facter.value('processors')['count']
      last_core = 0
      core_sets = {}
      num_cores.times do |core_num|
        core_sets[core_num] = {}
      end
      i = 1
      final_set.each do |val|
        next if i < start_index || i > end_index
        core_sets[last_core][i] = val
        last_core += 1
        last_core = 0 if last_core >= num_cores
        i += 1
      end
      threads = []
      core_count = 0
      max_width = 80
      core_sets.values.each do |core_set|
        threads << Thread.new do
          core_count += 1
          core_num = core_count
          core_set.clone.each do |img_num, rot|
            rx = rot[0]
            ry = rot[1]
            rz = rot[2]
            pose = {}
            pose[:img_filename] = "#{data_directory}/#{img_num.to_s.rjust(7, '0')}.png"
            if File.exist?(pose[:img_filename])
              img_num += 1
              $stdout.flush
              st = " " * max_width
              st += "\r"
              st = "Skipping existing pose: #{pose[:img_filename]}\r"
              max_width = st.size if st.size > max_width
              print st
              $stdout.flush
              next
            end
            $stdout.flush
            st = " " * max_width
            st += "\r"
            print st
            st = "Core #{core_num}: pose ##{img_num}/#{final_set.size} #{[rx, ry, rz]}...\r"
            max_width = st.size if st.size > max_width
            print st
            $stdout.flush
            pose[:width] = options[:width] if options[:width]
            pose[:height] = options[:height] if options[:height]
            pose[:rx] = rx.to_s.to_f.to_s # ensure uniqueness despite floating point imprecision
            pose[:ry] = ry.to_s.to_f.to_s
            pose[:rz] = rz.to_s.to_f.to_s
            pose[:model] = options[:model] if options[:model]
            generated_pose = RAPTOR::DataGenerator.generate_pose(pose)
            RAPTOR::DataGenerator.render_pose(generated_pose)
            img_num += 1
          end
          Thread.exit
        end
      end
      threads.each {|t| t.join}
      sleep(0.1)
      $stdout.flush
      puts ""
      puts "Successfully rendered #{final_set.size} samples!"
      true
    end

    class UnsupportedParamError < StandardError
    end

    class MissingRequiredParamError < StandardError
    end

    class RenderError < StandardError
    end

  end
end
