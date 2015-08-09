require 'oily_png'
require 'fileutils'
require 'util'
require 'facter'
require 'rmagick'
require 'benchmark'
require 'kmeans_intensity'
require 'intensity_space'
require 'dataset'
require 'grid_hash'
require 'spatial_scattering_hash'
require 'rcolor'

Dataset.register_model :hamina, 'data/models/hamina_no_antenna.3ds'
Dataset.register_model :kirov, 'data/models/Kirov.3ds'
Dataset.register_model :kuznet, 'data/models/Kuznet.3ds'
Dataset.register_model :sovddg, 'data/models/SovDDG.3ds'
Dataset.register_model :udaloy, 'data/models/Udaloy_l.3ds'
Dataset.register_model :halifax, 'data/models/Halifax.3ds'

Dataset.register_model :m4a1_s, 'data/models/m4a1.3ds'

Dataset.register_model :sphere, 'data/models/sphere.3ds'

def super_experiment(m_vals=[5,10,15,20,25,30,35,40,45,50])
  writeline = Proc.new {|line, model| open("results-#{model}.txt", 'a') { |f| f.puts(line) }}
  models = [:m4a1_s, :udaloy, :kuznet, :kirov, :sovddg, :halifax, :hamina]
  m_vals.each do |m|
    models.each do |model|
      puts "beginning tests for #{model}..."
      results = experiment(1000, m: m, model: model, autocrop: false)
      writeline.("#{results}", model)
      results = experiment(1000, m: m, model: model, autocrop: true)
      writeline.("#{results}", model)
    end
  end
end

def experiment(num_test_samples=500, options={})
  writeline = Proc.new {|line| open('results.txt', 'a') { |f| f.puts(line) }}

  puts "Generating test set"
  test_set = Dataset.render_test_set(num_test_samples, options)

  # generate dataset or load existing from archive
  puts "Generating dataset"
  dataset = Dataset.new(options)

  # create grid hash from data
  puts "Constructing grid hash"
  gh = GridHash.new(dataset)
  output_dir = "data/results/#{File.basename(dataset.imgs_dir)}"

  # delete existing results data
  puts "Result data will be output to '#{output_dir}'..."
  puts "Deleting existing results" if Dir.exist?(output_dir)
  FileUtils.rm_rf(output_dir) if Dir.exist?(output_dir)
  Dir.mkdir(output_dir)

  puts "Performing garbage collection"
  GC.start
  puts "Disabling garbage collection"
  GC.disable
  # spread out tests over available CPU cores
  puts "Running tests"

  max_width = 80
  avg_id_time = 0.0
  num_done = 0
  avg_err = 0.0
  min_err = 1.0
  max_err = 0.0
  i = 0
  test_set.each do |img|
    $stdout.flush
    i += 1
    expected_rx = img.metadata['rx'].to_f
    expected_ry = img.metadata['ry'].to_f
    expected_rz = img.metadata['rz'].to_f
    orientation_id = i
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
    num_done += 1
    tmp_num_done = num_done
    avg_id_time += avg_time_addition
    avg_time_tmp = avg_id_time / num_done.to_f
    avg_err += percent_error
    min_err = percent_error if percent_error < min_err
    max_err = percent_error if percent_error > max_err
    avg_err_tmp = avg_err / num_done.to_f
    puts "#{num_done}/#{test_set.size} (#{orientation_id}) #{(percent_error * 100).round(3)}% #{expected_st} => #{actual_st} (train-#{actual[:id]} : #{actual[:confidence]})"
  end
  puts "Ran #{test_set.size} tests!"
  avg_err /= test_set.size.to_f
  puts "Avg percent error: #{(avg_err * 100.0).round(4)}%"
  puts "Min percent error: #{(min_err * 100.0).round(4)}%"
  puts "Max percent error: #{(max_err * 100.0).round(4)}%"
  avg_id_time /= test_set.size.to_f
  puts "Average id time: #{(avg_id_time * 1000.0).round(4)} ms"
  puts "Re-enabling garbage collection"
  GC.enable
  {model: options[:model], m: options[:m], average_error: avg_err, average_id_time: avg_id_time, min_error: min_err, max_error: max_err}
end
