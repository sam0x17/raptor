require 'spec_helper'
require 'raptor'
require 'raptor/grid_hash'
require 'oily_png'
require 'ostruct'

describe :grid_hash do

  def accumulate_samples(path)
    img = ChunkyPNG::Image.from_file path
    $gh = RAPTOR::GridHash.new(grid_width: img.dimension.width, grid_height: img.dimension.height) if $gh.nil?
    rot = OpenStruct.new({rx: rand(0.0..Math::PI), ry: rand(0.0..Math::PI), rz: rand(0.0..Math::PI)})
    img.dimension.width.times do |col|
      img.dimension.height.times do |row|
        color = img[col, row]
        next if color == 0
        $gh.add_sample(x: col, y: row, color: color, rx: rot.rx, ry: rot.ry, rz: rot.rz)
      end
    end
  end

  it 'default grid size should be 128 x 128' do
    gh = RAPTOR::GridHash.new
    expect(gh.grid_width).to eq 128
    expect(gh.grid_height).to eq 128
  end

  it 'should be able to using a non default grid size' do
    gh = RAPTOR::GridHash.new(grid_height: 100, grid_width: 100)
    expect(gh.grid_width).to eq 100
    expect(gh.grid_height).to eq 100
  end

  it 'should be able to use a non default grid size where w != h' do
    gh = RAPTOR::GridHash.new(grid_height: 50, grid_width: 200)
    expect(gh.grid_height).to eq 50
    expect(gh.grid_width).to eq 200
  end

  it 'should be able to accumulate samples from test rotation A' do
    accumulate_samples 'test_data/heli_rotA.png'
  end

  it 'should be able to accumulate samples from test rotation B' do
    accumulate_samples 'test_data/heli_rotB.png'
  end

  it 'should be able to accumultae samples from test rotation C' do
    accumulate_samples 'test_data/heli_rotC.png'
  end

  it 'should be able to accumulate samples from test rotation D' do
    accumulate_samples 'test_data/heli_rotD.png'
  end

  it 'should be able to compile accumulated samples' do
    $gh.compile
  end

end
