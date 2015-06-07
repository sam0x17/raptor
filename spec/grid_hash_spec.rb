require 'spec_helper'
require 'raptor'
require 'raptor/grid_hash'
require 'oily_png'

context :grid_hash do

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

  it 'should be able to accumulate samples' do
    img = ChunkyPNG::Image.from_file 'test.png'
    gh = RAPTOR::GridHash.new(grid_width: img.dimension.width, grid_height: img.dimension.height)

    img.dimension.width.times do |col|
      img.dimension.height.times do |row|
        color = img[col, row]
        next if color == 0
        gh.add_sample()
      end
    end
  end

end
