extends Node
class_name TickInterpolator
# TODO: Add as feature

class PropertyEntry:
	var _path: String
	var node: Node
	var property: String
	var interpolate: Callable
	
	func get_value() -> Variant:
		return node.get(property)
	
	func set_value(value):
		node.set(property, value)
	
	func is_valid() -> bool:
		if node == null:
			return false
			
		if node.get(property) == null:
			return false
		
		return true
	
	func _to_string() -> String:
		return _path
	
	static func parse(root: Node, path: String) -> PropertyEntry:
		var result = PropertyEntry.new()
		result.node = root.get_node(NodePath(path))
		result.property = path.erase(0, path.find(":") + 1)
		result._path = path
		result.interpolate = Interpolators.find_for(result.get_value())
		return result

@export var root: Node = get_parent()
@export var enabled: bool = true
@export var properties: Array[String]
@export var record_first_state: bool = true

var _state_from: Dictionary = {}
var _state_to: Dictionary = {}
var _props: Array[PropertyEntry] = []

var _pe_cache: Dictionary = {}

## Process settings.
##
## Call this after any change to configuration.
func process_settings():
	_pe_cache.clear()
	
	_state_from = {}
	_state_to = {}

	for property in properties:
		var pe = _get_pe(property)
		_props.push_back(pe)

## Check if interpolation can be done.
##
## Even if it's enabled, no interpolation will be done if there are no
## properties to interpolate.
func can_interpolate() -> bool:
	return enabled and not properties.is_empty()

func push_state():
	_state_from = _state_to
	_state_to = _extract(_props)

func _ready():
	process_settings()
	NetworkTime.before_tick_loop.connect(_before_tick_loop)
	NetworkTime.after_tick_loop.connect(_after_tick_loop)

	# Wait a frame for any initial setup before recording first state
	if record_first_state:
		await get_tree().process_frame
		push_state()
		push_state()

func _process(delta):
	_interpolate(_state_from, _state_to, NetworkTime.tick_factor, delta)

func _before_tick_loop():
	_apply(_state_to)

func _after_tick_loop():
	push_state()

func _interpolate(from: Dictionary, to: Dictionary, f: float, delta: float):
	if not can_interpolate():
		return

	for property in from:
		if not to.has(property): continue
		
		var pe = _get_pe(property)
		var a = from[property]
		var b = to[property]
		
		pe.set_value(pe.interpolate.call(a, b, f))

func _extract(properties: Array[PropertyEntry]) -> Dictionary:
	var result = {}
	for property in properties:
		result[property.to_string()] = property.get_value()
	result.make_read_only()
	return result

func _apply(properties: Dictionary):
	for property in properties:
		var pe = _get_pe(property)
		var value = properties[property]
		pe.set_value(value)

func _get_pe(path: String) -> PropertyEntry:
	if not _pe_cache.has(path):
		var parsed = PropertyEntry.parse(root, path)
		if not parsed.is_valid():
			push_warning("Invalid property path: %s" % path)
		_pe_cache[path] = parsed
	return _pe_cache[path]
