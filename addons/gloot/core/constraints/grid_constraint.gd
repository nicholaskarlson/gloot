extends "res://addons/gloot/core/constraints/inventory_constraint.gd"
class_name GridConstraint

const Verify = preload("res://addons/gloot/core/verify.gd")
const StackManager = preload("res://addons/gloot/core/stack_manager.gd")
const QuadTree = preload("res://addons/gloot/core/constraints/quadtree.gd")

const KEY_SIZE: String = "size"
const KEY_ROTATED: String = "rotated"
const KEY_POSITIVE_ROTATION: String = "positive_rotation"
const KEY_ITEM_POSITIONS: String = "item_positions"
const DEFAULT_SIZE: Vector2i = Vector2i(10, 10)

var _swap_positions: Array[Vector2i]
var _item_positions := {}
var _quad_tree := QuadTree.new(size)

@export var size: Vector2i = DEFAULT_SIZE :
    set(new_size):
        assert(new_size.x > 0, "Inventory width must be positive!")
        assert(new_size.y > 0, "Inventory height must be positive!")
        var old_size = size
        size = new_size
        if !Engine.is_editor_hint():
            if _bounds_broken():
                size = old_size
        if size != old_size:
            _refresh_quad_tree()
            changed.emit()


func _refresh_quad_tree() -> void:
    _quad_tree = QuadTree.new(size)
    if !is_instance_valid(inventory):
        return
    for item in inventory.get_items():
        _quad_tree.add(get_item_rect(item), item)


func _on_inventory_set() -> void:
    _refresh_quad_tree()


func _on_item_added(item: InventoryItem) -> void:
    if item == null:
        return
    _quad_tree.add(get_item_rect(item), item)


func _on_item_removed(item: InventoryItem) -> void:
    _quad_tree.remove(item)
    _item_positions.erase(item)

    
func _on_item_property_changed(item: InventoryItem, property: String) -> void:
    if property == KEY_SIZE:
        _refresh_quad_tree()


func _on_pre_item_swap(item1: InventoryItem, item2: InventoryItem) -> bool:
    var inv1 = item1.get_inventory()
    var inv2 = item2.get_inventory()
    var grid_constraint1: GridConstraint = null
    var grid_constraint2: GridConstraint = null
    var pos1 = Vector2i.ZERO
    var pos2 = Vector2i.ZERO
    if is_instance_valid(inv1):
        grid_constraint1 = inv1.get_constraint(GridConstraint)
        if is_instance_valid(grid_constraint1):
            pos1 = grid_constraint1.get_item_position(item1)
    if is_instance_valid(inv2):
        grid_constraint2 = inv2.get_constraint(GridConstraint)
        if is_instance_valid(grid_constraint2):
            pos2 = grid_constraint2.get_item_position(item2)
    
    _swap_positions = [pos1, pos2]
    if is_instance_valid(grid_constraint1) || is_instance_valid(grid_constraint2):
        return get_item_size(item1) == get_item_size(item2)
    return true


func _on_post_item_swap(item1: InventoryItem, item2: InventoryItem) -> void:
    const ITEM1_IDX = 0
    const ITEM2_IDX = 1
    if is_instance_valid(item1.get_inventory()) && is_instance_valid(item1.get_inventory().get_constraint(GridConstraint)):
        item1.get_inventory().get_constraint(GridConstraint).set_item_position(item1, _swap_positions[ITEM2_IDX])
    if is_instance_valid(item2.get_inventory()) && is_instance_valid(item2.get_inventory().get_constraint(GridConstraint)):
        item2.get_inventory().get_constraint(GridConstraint).set_item_position(item2, _swap_positions[ITEM1_IDX])


func _bounds_broken() -> bool:
    if !is_instance_valid(inventory):
        return false
    for item in inventory.get_items():
        if !rect_free(get_item_rect(item), item):
            return true

    return false


func get_item_position(item: InventoryItem) -> Vector2i:
    if !_item_positions.has(item):
        return Vector2i.ZERO
    return _item_positions[item]


func set_item_position(item: InventoryItem, new_position: Vector2i) -> bool:
    var new_rect := Rect2i(new_position, get_item_size(item))
    if inventory.has_item(item) and !rect_free(new_rect, item):
        return false

    set_item_position_unsafe(item, new_position)
    return true


func set_item_position_unsafe(item: InventoryItem, new_position: Vector2i) -> void:
    if new_position == get_item_position(item):
        return

    _item_positions[item] = new_position
    _refresh_quad_tree()
    changed.emit()


func get_item_size(item: InventoryItem) -> Vector2i:
    var result: Vector2i = item.get_property(KEY_SIZE, Vector2i.ONE)
    if is_item_rotated(item):
        var temp := result.x
        result.x = result.y
        result.y = temp
    return result


static func is_item_rotated(item: InventoryItem) -> bool:
    return item.get_property(KEY_ROTATED, false)


static func is_item_rotation_positive(item: InventoryItem) -> bool:
    return item.get_property(KEY_POSITIVE_ROTATION, false)


# TODO: Consider making a static "unsafe" version of this
func set_item_size(item: InventoryItem, new_size: Vector2i) -> bool:
    if new_size.x < 1 || new_size.y < 1:
        return false

    var new_rect := Rect2i(get_item_position(item), new_size)
    if inventory.has_item(item) and !rect_free(new_rect, item):
        return false

    item.set_property(KEY_SIZE, new_size)
    return true


func set_item_rotation(item: InventoryItem, rotated: bool) -> bool:
    if is_item_rotated(item) == rotated:
        return false
    if !can_rotate_item(item):
        return false

    if rotated:
        item.set_property(KEY_ROTATED, true)
    else:
        item.clear_property(KEY_ROTATED)

    return true


func rotate_item(item: InventoryItem) -> bool:
    return set_item_rotation(item, !is_item_rotated(item))


static func set_item_rotation_direction(item: InventoryItem, positive: bool) -> void:
    if positive:
        item.set_property(KEY_POSITIVE_ROTATION, true)
    else:
        item.clear_property(KEY_POSITIVE_ROTATION)


func can_rotate_item(item: InventoryItem) -> bool:
    var rotated_rect := get_item_rect(item)
    var temp := rotated_rect.size.x
    rotated_rect.size.x = rotated_rect.size.y
    rotated_rect.size.y = temp
    return rect_free(rotated_rect, item)


func get_item_rect(item: InventoryItem) -> Rect2i:
    var item_pos := get_item_position(item)
    var item_size := get_item_size(item)
    return Rect2i(item_pos, item_size)


func set_item_rect(item: InventoryItem, new_rect: Rect2i) -> bool:
    if !rect_free(new_rect, item):
        return false
    if !set_item_position(item, new_rect.position):
        return false
    if !set_item_size(item, new_rect.size):
        return false
    return true


func _get_prototype_size(prototype_path: String) -> Vector2i:
    assert(inventory != null, "Inventory not set!")
    assert(inventory.prototree_json != null, "Inventory prototree is null!")
    var size: Vector2i = inventory.get_prototree().get_prototype_property(prototype_path, KEY_SIZE, Vector2i.ONE)
    return size


func add_item_at(item: InventoryItem, position: Vector2i) -> bool:
    assert(inventory != null, "Inventory not set!")

    var item_size := get_item_size(item)
    var rect := Rect2i(position, item_size)
    if rect_free(rect):
        if not inventory.add_item(item):
            return false
        assert(move_item_to(item, position), "Can't move the item to the given place!")
        return true

    return false


func create_and_add_item_at(prototype_path: String, position: Vector2i) -> InventoryItem:
    assert(inventory != null, "Inventory not set!")
    var item_rect := Rect2i(position, _get_prototype_size(prototype_path))
    if !rect_free(item_rect):
        return null

    var item = inventory.create_and_add_item(prototype_path)
    if item == null:
        return null

    if not move_item_to(item, position):
        inventory.remove_item(item)
        return null

    return item


func get_item_at(position: Vector2i) -> InventoryItem:
    assert(inventory != null, "Inventory not set!")
    var first = _quad_tree.get_first(position)
    if first == null:
        return null
    return first.metadata


func get_items_under(rect: Rect2i) -> Array[InventoryItem]:
    assert(inventory != null, "Inventory not set!")
    var result: Array[InventoryItem]
    for item in inventory.get_items():
        var item_rect := get_item_rect(item)
        if item_rect.intersects(rect):
            result.append(item)
    return result


func move_item_to(item: InventoryItem, position: Vector2i) -> bool:
    assert(inventory != null, "Inventory not set!")
    var item_size := get_item_size(item)
    var rect := Rect2i(position, item_size)
    if rect_free(rect, item):
        set_item_position_unsafe(item, position)
        inventory.contents_changed.emit()
        return true

    return false


func move_item_to_free_spot(item: InventoryItem) -> bool:
    if rect_free(get_item_rect(item), item):
        return true

    var free_place := find_free_place(item, item)
    if not free_place.success:
        return false

    return move_item_to(item, free_place.position)


func _merge_to(item: InventoryItem, destination: GridConstraint, position: Vector2i) -> bool:
    var item_dst := destination._get_mergable_item_at(item, position)
    if item_dst == null:
        return false

    return StackManager.merge_stacks(item_dst, item)
    

func _get_mergable_item_at(item: InventoryItem, position: Vector2i) -> InventoryItem:
    var rect := Rect2i(position, get_item_size(item))
    var mergable_items := _get_mergable_items_under(item, rect)
    for mergable_item in mergable_items:
        if StackManager.can_merge_stacks(mergable_item, item):
            return mergable_item
    return null


func _get_mergable_items_under(item: InventoryItem, rect: Rect2i) -> Array[InventoryItem]:
    var result: Array[InventoryItem]

    for item_dst in get_items_under(rect):
        if item_dst == item:
            continue
        if StackManager.can_merge_stacks(item_dst, item):
            result.append(item_dst)

    return result


func rect_free(rect: Rect2i, exception: InventoryItem = null) -> bool:
    assert(inventory != null, "Inventory not set!")

    if rect.position.x < 0 || rect.position.y < 0 || rect.size.x < 1 || rect.size.y < 1:
        return false
    if rect.position.x + rect.size.x > size.x:
        return false
    if rect.position.y + rect.size.y > size.y:
        return false

    return _quad_tree.get_first(rect, exception) == null


# TODO: Check if this is needed after adding find_free_space
func find_free_place(item: InventoryItem, exception: InventoryItem = null) -> Dictionary:
    var result := {success = false, position = Vector2i(-1, -1)}
    var item_size = get_item_size(item)
    for x in range(size.x - (item_size.x - 1)):
        for y in range(size.y - (item_size.y - 1)):
            var rect := Rect2i(Vector2i(x, y), item_size)
            if rect_free(rect, exception):
                result.success = true
                result.position = Vector2i(x, y)
                return result

    return result


func _compare_items(item1: InventoryItem, item2: InventoryItem) -> bool:
    var rect1 := Rect2i(get_item_position(item1), get_item_size(item1))
    var rect2 := Rect2i(get_item_position(item2), get_item_size(item2))
    return rect1.get_area() > rect2.get_area()


func sort() -> bool:
    assert(inventory != null, "Inventory not set!")

    var item_array: Array[InventoryItem]
    for item in inventory.get_items():
        item_array.append(item)
    item_array.sort_custom(_compare_items)

    for item in item_array:
        set_item_position_unsafe(item, -get_item_size(item))

    for item in item_array:
        var free_place := find_free_place(item)
        if !free_place.success:
            return false
        move_item_to(item, free_place.position)

    return true


func get_space_for(item: InventoryItem) -> ItemCount:
    var result = _get_free_space_for(item).mul(StackManager.get_item_max_stack_size(item))

    for i in inventory.get_items():
        if StackManager.can_merge_stacks(i, item, true):
            result.add(StackManager.get_free_stack_space(i))

    return result


func _get_free_space_for(item: InventoryItem) -> ItemCount:
    var item_size = get_item_size(item)
    var occupied_rects: Array[Rect2i]
    var free_space := find_free_space(item_size, occupied_rects)

    while free_space.success:
        occupied_rects.append(Rect2i(free_space.position, item_size))
        free_space = find_free_space(item_size, occupied_rects)
    return ItemCount.new(occupied_rects.size())
    


func has_space_for(item: InventoryItem) -> bool:
    var item_size = get_item_size(item)

    if find_free_space(item_size).success:
        return true

    var total_free_stack_space = ItemCount.zero()
    for i in inventory.get_items():
        total_free_stack_space.add(StackManager.get_free_stack_space(i))
    return total_free_stack_space.ge(StackManager.get_item_stack_size(item))


# TODO: Check if find_free_place is needed
func find_free_space(item_size: Vector2i, occupied_rects: Array[Rect2i] = []) -> Dictionary:
    var result := {success = false, position = Vector2i(-1, -1)}
    for x in range(size.x - (item_size.x - 1)):
        for y in range(size.y - (item_size.y - 1)):
            var rect := Rect2i(Vector2i(x, y), item_size)
            if rect_free(rect) and not _rect_intersects_rect_array(rect, occupied_rects):
                result.success = true
                result.position = Vector2i(x, y)
                return result

    return result


static func _rect_intersects_rect_array(rect: Rect2i, occupied_rects: Array[Rect2i] = []) -> bool:
    for occupied_rect in occupied_rects:
        if rect.intersects(occupied_rect):
            return true
    return false


func enforce(item: InventoryItem) -> void:
    if !move_item_to_free_spot(item):
        StackManager.inv_pack_stack(inventory, item)


func reset() -> void:
    size = DEFAULT_SIZE
    _quad_tree = QuadTree.new(size)
    _item_positions.clear()


func serialize() -> Dictionary:
    var result := {}

    # Store Vector2i as string to make JSON conversion easier later
    result[KEY_SIZE] = var_to_str(size)
    result[KEY_ITEM_POSITIONS] = _serialize_item_positions()

    return result


func _serialize_item_positions() -> Dictionary:
    var result = {}
    for item in _item_positions.keys():
        var str_item_index := var_to_str(inventory.get_item_index(item))
        var str_item_position = var_to_str(_item_positions[item])
        result[str_item_index] = str_item_position
    return result


func deserialize(source: Dictionary) -> bool:
    if !Verify.dict(source, true, KEY_SIZE, TYPE_STRING):
        return false

    reset()
    _deserialize_item_positions(source[KEY_ITEM_POSITIONS])
    size = str_to_var(source[KEY_SIZE])

    return true


func _deserialize_item_positions(source: Dictionary) -> bool:
    for str_item_index in source.keys():
        var item_index: int = str_to_var(str_item_index)
        var item := inventory.get_items()[item_index]
        var item_position = str_to_var(source[str_item_index])
        set_item_position_unsafe(item, item_position)
    return false

