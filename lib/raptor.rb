require 'oily_png'
require 'fileutils'
require 'util'
require 'kmeans_intensity'
require 'dataset'
require 'grid_hash'
require 'rcolor'

Dataset.register_model :hamina, 'data/models/hamina_no_antenna.3ds'
