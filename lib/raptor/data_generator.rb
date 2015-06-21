require 'facter'
module RAPTOR
  module DataGenerator

    def self.generate_pose(options={})
      set_default = Proc.new {|key,value| options[key] = value if !options.has_key?(key) }
      set_default.(:rx, rand(0.0..1.0))
      set_default.(:ry, rand(0.0..1.0))
      set_default.(:rz, rand(0.0..1.0))
      set_default.(:width, 60)
      set_default.(:height, 60)
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
              'blender -b -P render.py')
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
      puts "Total series size: #{end_index}"
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
        core_sets[core_num] = []
      end
      final_set.each do |val|
        core_sets[last_core] << val
        last_core += 1
        last_core = 0 if last_core >= num_cores
      end
      threads = []
      img_num = start_index
      core_sets.values.each do |core_set|
        threads << Thread.new do
          begin
            core_set.clone.each do |rot|
              rx = rot[0]
              ry = rot[1]
              rz = rot[2]
              pose = {}
              pose[:img_filename] = "#{data_directory}/#{img_num.to_s.rjust(7, '0')}.png"
              if File.exist?(pose[:img_filename])
                img_num += 1
                puts "Skipping pose that already exists: #{[rx, ry, rz]} : #{pose[:img_filename]}"
                next
              end
              puts "Rotation: #{[rx, ry, rz]}"
              puts "Rendering #{options[:img_filename]}"
              pose[:width] = options[:width] if options[:width]
              pose[:height] = options[:height] if options[:height]
              pose[:rx] = rx.to_s.to_f.to_s
              pose[:ry] = ry.to_s.to_f.to_s
              pose[:rz] = rz.to_s.to_f.to_s
              pose[:model] = options[:model] if options[:model]
              generated_pose = RAPTOR::DataGenerator.generate_pose(pose)
              RAPTOR::DataGenerator.render_pose(generated_pose)
              img_num += 1
            end
          rescue => err
            puts "An error occured while generating image ##{img_num}"
            Thread.exit
            raise err
          end
          Thread.exit
        end
      end
      threads.each {|t| t.join}
      puts "Successfully rendered #{final_set.size} samples!"
      true
    end

    class UnsupportedParamError < StandardError
    end

    class MissingRequiredParamError < StandardError
    end

  end
end
