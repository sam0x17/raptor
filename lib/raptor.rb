require 'oily_png'
require 'fileutils'
require 'util'
require 'facter'
require 'benchmark'
require 'kmeans_intensity'
require 'dataset'
require 'grid_hash'
require 'rcolor'

Dataset.register_model :hamina, 'data/models/hamina_no_antenna.3ds'

def experiment(num_test_samples=200, num_centroids=8, output_file="output.txt", options={})
  writeline = Proc.new {|line| open('results.txt', 'a') { |f| f.puts(line) }}

  puts "Generating test set"
  test_set = Dataset.render_test_set(num_test_samples, options)

  # generate dataset or load existing from archive
  puts "Generating dataset"
  dataset = Dataset.new(options)

  # create grid hash from data
  puts "Constructing grid hash"
  gh = GridHash.new(dataset, num_centroids)
  output_dir = "data/results/#{File.basename(dataset.imgs_dir)} c-#{num_centroids}"

  # delete existing results data
  puts "Result data will be output to '#{output_dir}'..."
  puts "Deleting existing results" if Dir.exist?(output_dir)
  FileUtils.rm_rf(output_dir) if Dir.exist?(output_dir)
  Dir.mkdir(output_dir)

  # spread out tests over available CPU cores
  puts "Running tests"
  num_cores = Facter.value('processors')['count']
  last_core = 0
  core_sets = {}
  num_cores.times {|core_num| core_sets[core_num] = {} }
  i = 1
  test_set.each do |val|
    core_sets[last_core][i] = val
    last_core += 1
    last_core = 0 if last_core >= num_cores
    i += 1
  end

  # initialize and run testing threads
  threads = []
  core_num = 0
  max_width = 80
  avg_id_time = 0.0
  num_done = 0
  avg_err = 0.0
  min_err = 1.0
  max_err = 0.0
  print_lock = Mutex.new
  avg_id_lock = Mutex.new
  core_sets.each do |core_set|
    core_num += 1
    threads << Thread.new(core_num, core_set, num_cores, test_set.size) do |cnum, cset, nc, total|
      cnum_st = cnum.to_s
      cnum_st = "0" + cnum_st if nc > 9
      cset = cset[1].values
      cset.each do |img_path|
        $stdout.flush
        img = ChunkyPNG::Image.from_file(img_path)
        expected_rx = img.metadata['rx'].to_f
        expected_ry = img.metadata['ry'].to_f
        expected_rz = img.metadata['rz'].to_f
        orientation_id = File.basename(img_path, '.png').to_i
        expected_orientation = [expected_rx, expected_ry, expected_rz]
        expected_st = [expected_rx.round(3), expected_ry.round(3), expected_rz.round(3)].to_s
        actual = nil
        avg_time_addition = Benchmark.measure do
          actual = gh.identify_orientation(img)
        end
        percent_error = orientation_percent_error(expected_orientation, actual[:orientation])
        actual_rx = actual[:orientation][0]
        actual_ry = actual[:orientation][1]
        actual_rz = actual[:orientation][2]
        actual_st = [actual_rx.round(3), actual_ry.round(3), actual_rz.round(3)].to_s
        avg_time_addition = avg_time_addition.utime
        avg_id_lock.lock
        num_done += 1
        tmp_num_done = num_done
        avg_id_time += avg_time_addition
        avg_time_tmp = avg_id_time / num_done.to_f
        avg_err += percent_error
        min_err = percent_error if percent_error < min_err
        max_err = percent_error if percent_error > max_err
        avg_err_tmp = avg_err / num_done.to_f
        avg_id_lock.unlock
        print_lock.lock
        puts "core: #{cnum_st} #{tmp_num_done}/#{total} (#{orientation_id}) #{(percent_error * 100).round(3)}% #{expected_st}  => #{actual_st}"
        print_lock.unlock
      end
      Thread.exit
    end
  end
  threads.each {|t| t.join}
  sleep(0.0001)
  $stdout.flush
  puts "Ran #{test_set.size} tests!"
  avg_err /= test_set.size.to_f
  puts "Avg percent error: #{(avg_err * 100.0).round(4)}%"
  puts "Min percent error: #{(min_err * 100.0).round(4)}%"
  puts "Max percent error: #{(max_err * 100.0).round(4)}%"
  avg_id_time /= test_set.size.to_f
  puts "Average id time: #{(avg_id_time * 1000.0).round(4)} ms"
  true
end
