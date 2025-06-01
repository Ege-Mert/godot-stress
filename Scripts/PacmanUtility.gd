extends Node
class_name PacmanUtility

# Utility functions for grid/world coordinate conversion and bounds checking

@export var tile_size: int = 32
@export var use_bounds_checking: bool = false
@export var map_width: int = 20
@export var map_height: int = 20

func grid_to_world(grid_pos: Vector2) -> Vector2:
	return grid_pos * float(tile_size) + Vector2(float(tile_size)/2.0, float(tile_size)/2.0)

func world_to_grid(world_pos: Vector2) -> Vector2:
	return Vector2(
		int(round(world_pos.x / float(tile_size))), 
		int(round(world_pos.y / float(tile_size)))
	)

func is_within_bounds(grid_pos: Vector2) -> bool:
	if not use_bounds_checking:
		return true
	
	return (grid_pos.x >= 0 and grid_pos.x < map_width and 
			grid_pos.y >= 0 and grid_pos.y < map_height)

func get_nearby_positions(center: Vector2, radius: int = 1) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	
	for x_offset in range(-radius, radius + 1):
		for y_offset in range(-radius, radius + 1):
			if x_offset == 0 and y_offset == 0:
				continue  # Skip center position
			positions.append(center + Vector2(x_offset, y_offset))
	
	return positions

func get_adjacent_positions(center: Vector2) -> Array[Vector2]:
	return [
		center + Vector2(1, 0),   # Right
		center + Vector2(-1, 0),  # Left
		center + Vector2(0, 1),   # Down
		center + Vector2(0, -1)   # Up
	]

func calculate_distance(pos1: Vector2, pos2: Vector2) -> float:
	return pos1.distance_to(pos2)

func get_direction_vector(from: Vector2, to: Vector2) -> Vector2:
	return (to - from).normalized()

func clamp_to_grid(world_pos: Vector2) -> Vector2:
	var grid_pos = world_to_grid(world_pos)
	return grid_to_world(grid_pos)

func set_tile_size(new_size: int):
	tile_size = new_size

func set_map_bounds(width: int, height: int, enable_bounds: bool = true):
	map_width = width
	map_height = height
	use_bounds_checking = enable_bounds
