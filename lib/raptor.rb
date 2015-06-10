require 'raptor/grid_hash'
require 'raptor/data_generator'
require 'raptor/database'
require 'oily_png'
module RAPTOR
  def self.register_sample(params={})
    x = params[:x]
    y = params[:y]
    color = params[:color]
    rx = params[:rx]
    ry = params[:ry]
    rz = params[:rz]
    samp = RAPTOR::Sample.where(x: x, y: y, color: color, rx: rx, ry: ry, rz: rz).first_or_initialize
    samp.count += 1
    samp.save
    samp
  end
  def self.process_image(img_path)
    rot = File.basename(img_path, ".png").split("_").collect {|e| e.to_i}
    rx = rot[0]
    ry = rot[1]
    rz = rot[2]
    img = ChunkyPNG::Image.from_file img_path
    RAPTOR::Sample.transaction do
      img.dimension.width.times do |col|
        img.dimension.height.times do |row|
          color = img[col, row]
          register_sample(x: col, y: row, color: img[col, row], rx: rx, ry: ry, rz: rz)
          #puts "#{samp.attributes}"
        end
      end
    end
  end
end
RAPTOR::Database.load_db_config
