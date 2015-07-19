import bpy
import os
import random
import math
import sys
import ntpath
import subprocess
import mathutils
from mathutils import Vector
from mathutils import Matrix
from mathutils import Quaternion

pi = 3.14159265
deg_to_rad = 0.0174532925
rad_to_deg = 57.2957795

# utility functions:
# compute 3D distance between two points
def dist3d(v1, v2):
	xd = v2[0] - v1[0]
	yd = v2[1] - v1[1]
	zd = v2[2] - v1[2]
	return math.sqrt(xd * xd + yd * yd + zd * zd)

# divides a 3D vector by a scalar
def v3d_div_scal(v1, s1):
	return ((v1[0] / s1, v1[1] / s1, v1[2] / s1))

# divides a scalar by a 3D vector
def scal_div_v3d(s1, v1):
	return ((s1 / v1[0], s1 / v1[1], s1 / v1[2]))

# adds a scalar and a 3D vector
def v3d_add_scal(v1, s1):
	return ((v1[0] + s1, v1[1] + s1, v1[2] + s1))

# adds a scalar and a 3D vector
def scal_add_v3d(s1, v1):
	return v3d_add_scal(v1, s1)

# adds a 3D vector to a 3D vector
def v3d_add_v3d(v1, v2):
	return ((v1[0] + v2[0], v1[1] + v2[1], v1[2] + v2[2]))

# subtracts a 3D vector from a 3D vector
def v3d_sub_v3d(v1, v2):
	return ((v1[0] - v2[0], v1[1] - v2[1], v1[2] - v2[2]))

# multiplies a 3D vector by a 3D vector (not cross product)
def v3d_mul_v3d(v1, v2):
	return ((v1[0] * v2[0], v1[1] * v2[1], v1[2] * v2[2]))

# divides a 3D vector by a 3D vector
def v3d_div_v3d(v1, v2):
	return ((v1[0] / v2[0], v1[1] / v2[1], v1[2] / v2[2]))

# subtracts a scalar from a 3D vector
def v3d_sub_scal(v1, s1):
	return ((v1[0] - s1, v1[1] - s1, v1[2] - s1))

# subtracts a 3D vector from a scalar
def scal_sub_v3d(s1, v1):
	return ((s1 - v1[0], s1 - v1[1], s1 - v1[2]))

# multiplies a 3D vector by a scalar
def v3d_mul_scal(v1, s1):
	return ((v1[0] * s1, v1[1] * s1, v1[2] * s1))

# multiplies a 3D vector by a scalar
def scal_mul_v3d(s1, v1):
	return v3d_mul_scal(v1, s1)

# compute 3D magnitude of v1
def mag3d(v1):
	return math.sqrt(v1[0] * v1[0] + v1[1] * v1[1] + v1[2] * v1[2])

def unit3d(v1):
	return v3d_div_scal(v1, mag3d(v1))

def v3d_floor(v1):
	return ((math.floor(v1[0]), math.floor(v1[1]), math.floor(v1[2])))

def normrot(v1):
	v2 = v3d_mul_scal(v3d_floor(v3d_div_scal(v1, deg_to_rad * 360.0)), deg_to_rad * 360.0)
	return v3d_sub_v3d(v1, v2)

# end utility functions

# delete default cube
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_by_type(type='MESH')
bpy.ops.object.delete(use_global=False)
for item in bpy.data.meshes:
	bpy.data.meshes.remove(item)

# load 3ds file
model = os.getenv('model')
raptor_rx = float(os.getenv('rx'))
raptor_ry = float(os.getenv('ry'))
raptor_rz = float(os.getenv('rz'))
width = int(os.getenv('width'))
height = int(os.getenv('height'))
img_filename = os.getenv('img_filename')
rot = ((raptor_rx * deg_to_rad, raptor_ry * deg_to_rad, raptor_rz * deg_to_rad))
bpy.ops.import_scene.autodesk_3ds(filepath=model, filter_glob="*.3ds", constrain_size=50.0, use_image_search=True, use_apply_transform=True, axis_forward='Y', axis_up='Z')

# set up scene and render variables
scene = bpy.context.scene
render = scene.render

# select all meshes
bpy.ops.object.select_by_type(type='MESH')

# average world location of component objects
avg_loc = ((0.0, 0.0, 0.0)) 

# average of component bounding boxes
avg_bb = ((0.0, 0.0, 0.0))

# true center of overall object in object coordinates
center_obj = ((0.0, 0.0, 0.0))

# true center of overall object in world coordinates
center_world = ((0.0, 0.0, 0.0))

# true bounding box
true_bb = ((0.0, 0.0, 0.0))

# value of maximum dimension
max_dim = 0.0

# computes above statistics on selected object(s)
def compute_bb():
	global avg_loc, avg_bb, center_obj, center_world, true_bb, max_dim
	bb_x = 0.0
	bb_y = 0.0
	bb_z = 0.0
	loc_x = 0.0 
	loc_y = 0.0
	loc_z = 0.0
	mb_x = 0.0
	mb_y = 0.0
	mb_z = 0.0
	num_objects = 0
	for obj in bpy.context.selected_objects:
		obj_dim = obj.dimensions
		bb_x += obj_dim[0]
		bb_y += obj_dim[1]
		bb_z += obj_dim[2]
		mb_x = max(obj_dim[0], mb_x)
		mb_y = max(obj_dim[1], mb_y)
		mb_z = max(obj_dim[2], mb_z)
		obj_loc = obj.location.xyz
		loc_x = obj_loc[0]
		loc_y = obj_loc[1]
		loc_z = obj_loc[2]
		num_objects += 1
	bb_x = bb_x / num_objects
	bb_y = bb_y / num_objects
	bb_z = bb_z / num_objects
	loc_x = loc_x / num_objects
	loc_y = loc_y / num_objects
	loc_z = loc_z / num_objects
	avg_loc = ((loc_x, loc_y, loc_z))
	avg_bb = ((bb_x, bb_y, bb_z))
	center_obj = ((bb_x / 2.0, bb_y / 2.0, bb_z / 2.0))
	center_world = ((center_obj[0] + loc_x, center_obj[1] + loc_y, center_obj[2] + loc_z))
	true_bb = ((mb_x, mb_y, mb_z))
	max_dim = max(mb_x, mb_y, mb_z)
	
# get v3d
def areas_tuple():
    res = {}                                                               
    count = 0
    for area in bpy.context.screen.areas:                                  
        res[area.type] = count                                             
        count += 1
    return res
areas = areas_tuple()
view3d = bpy.context.screen.areas[areas['VIEW_3D']].spaces[0]

# fit model to viewport
compute_bb()
scale_factor = 8.0 / max_dim
view3d.pivot_point = "CURSOR"
view3d.cursor_location = center_world
for obj in bpy.context.selected_objects:
	obj.scale = ((scale_factor * obj.scale[0], scale_factor * obj.scale[1], scale_factor * obj.scale[2]))
bpy.ops.object.transform_apply(scale=True)
compute_bb()

# rotate model
for obj in bpy.context.selected_objects:
  obj.rotation_mode = 'QUATERNION'
  obj.rotation_quaternion = Quaternion((1.0, raptor_rx, raptor_ry, raptor_rz))
bpy.ops.object.transform_apply(rotation=True)
first_run = False

# render pose
bpy.data.worlds['World'].light_settings.use_environment_light = True
bpy.data.worlds['World'].light_settings.environment_energy = 0.75
render.resolution_x = width
render.resolution_y = height
render.resolution_percentage = 100
render.alpha_mode = 'TRANSPARENT' #PREMUL
render.bake_type = 'ALPHA'
render.image_settings.color_mode = 'RGBA'
render.use_antialiasing = True
render.image_settings.file_format='PNG'
render.filepath = img_filename
bpy.ops.render.render(write_still = True)

