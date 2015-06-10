require 'raptor/grid_hash'
require 'raptor/data_generator'
require 'raptor/database'
require 'oily_png'
module RAPTOR
  def self.register_data(params={})
    x = params[:x]
    y = params[:y]
    color = params[:color]
    rx = params[:rx]
    ry = params[:ry]
    rz = params[:rz]
    act = RAPTOR::Activation.where(x: x, y: y, color: color).first_or_initialize
    data = act.data
    key = [rx, ry, rz]
    data[key] = 0 if !data.has_key?(key)
    data[key] += 1
    act.save
    act
  end
  def self.process_image(img_path)
    rot = File.basename(img_path, ".png").split("_").collect {|e| e.to_i}
    rx = rot[0]
    ry = rot[1]
    rz = rot[2]
    img = ChunkyPNG::Image.from_file img_path
    RAPTOR::Activation.transaction do
      img.dimension.width.times do |col|
        img.dimension.height.times do |row|
          color = img[col, row]
          act = register_data(x: col, y: row, color: img[col, row], rx: rx, ry: ry, rz: rz)
          #puts "#{act.attributes}"
        end
      end
    end
  end
  
  def self.process_images(dir)
    Dir.glob("#{dir}/**/*.png") do |file|
      puts "Adding activations for #{file}..."
      process_image(file)
    end
  end
  
end
RAPTOR::Database.load_db_config
