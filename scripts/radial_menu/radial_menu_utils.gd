extends Object
class_name RadialMenuUtils

## Creates a segment polygon (annular sector) between two radii.
##
## [b]Description:[/b]
##   Generates a polygon in the shape of a circular segment (portion of a ring)
##   defined by inner and outer radii and start/end angles. Useful for creating
##   pie charts, radar segments, or circular progress indicators.
##
## [b]Parameters:[/b]
##   [code]center[/code] [Vector2] - Center point of the segment
##   [code]radius_a[/code] [float] - Outer radius of the segment
##   [code]radius_b[/code] [float] - Inner radius of the segment  
##   [code]radius_padding[/code] [float] - Padding applied to radii
##   [code]start_angle[/code] [float] - Starting angle in radians (0 = right, PI/2 = down)
##   [code]end_angle[/code] [float] - Ending angle in radians
##   [code]angle_padding[/code] [float] - Padding applied to angles
##   [code]point_count[/code] [int] - Number of points per arc for smoothness
##
## [b]Returns:[/b]
##   [PackedVector2Array] - Array of polygon points forming the segment in clockwise order
##
## [b]How it works:[/b]
##   The function creates two concentric arcs:
##   • Outer arc from [code]start_angle[/code] to [code]end_angle[/code] with radius [code]radius_a + radius_padding[/code]
##   • Inner arc from [code]end_angle[/code] to [code]start_angle[/code] with radius [code]radius_b - radius_padding[/code]
##
##   Padding adjustments:
##   • [code]radius_padding[/code]: Positive increases segment size, negative decreases
##   • [code]angle_padding[/code]: Positive widens the angle, negative narrows it
##
## [b]Example:[/b]
##   [codeblock]
##   # Create a 90-degree segment with outer radius 80, inner radius 40
##   var polygon = create_segment_polygon(
##       Vector2(100, 100),  # center
##       80.0,               # outer radius
##       40.0,               # inner radius  
##       5.0,                # radius padding
##       0.0,                # start angle
##       PI/2,               # end angle (90°)
##       0.1,                # angle padding
##       20                  # points per arc
##   )
##   [/codeblock]
##
## [b]Note:[/b] Points are arranged in clockwise order suitable for Godot's polygon rendering.
static func create_segment_polygon(center: Vector2, radius_a: float, radius_b: float,radius_padding: float, start_angle: float, end_angle: float,angle_padding:float, point_count: int)->PackedVector2Array:
	var points := PackedVector2Array()
	points.resize(point_count*2+3)
	var a := Vector2((radius_a+radius_padding),0).rotated(start_angle+angle_padding)
	var b := Vector2((radius_b-radius_padding),0).rotated(end_angle-angle_padding)

	var step_angle := ((end_angle-angle_padding)-(start_angle+angle_padding))/point_count
	var pi = 0
	for i:int in range(point_count+1):
		points[pi] = (center+a)
		pi+=1
		a = a.rotated(step_angle)
	for i:int in range(point_count+1):
		points[pi] = (center+b)
		pi+=1
		b = b.rotated(-step_angle)
	points[pi] = points[0]
	return points
	
static func segment_releative_point(center: Vector2, radius_a: float, radius_b: float,radius_padding: float, start_angle: float, end_angle: float,angle_padding:float,radius_t:float,angle_t:float)->Vector2:
	return center+Vector2((radius_a+radius_padding)+((radius_b-radius_padding)-(radius_a+radius_padding))/2*(radius_t+1),0).rotated((start_angle+angle_padding)+((end_angle-angle_padding)-(start_angle+angle_padding))/2*(angle_t+1))
