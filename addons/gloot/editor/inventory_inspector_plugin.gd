extends EditorInspectorPlugin

const _InventoryInspector = preload("res://addons/gloot/editor/inventory_editor/inventory_inspector.tscn")
const _ItemSlotInspector = preload("res://addons/gloot/editor/item_slot_editor/item_slot_inspector.tscn")


func _can_handle(object: Object) -> bool:
    return (object is Inventory) || \
            (object is InventoryItem) || \
            (object is ItemSlot)


func _parse_begin(object: Object) -> void:
    if object is Inventory:
        var inventory_inspector := _InventoryInspector.instantiate()
        inventory_inspector.init(object as Inventory)
        add_custom_control(inventory_inspector)
    if object is ItemSlot:
        var item_slot_inspector := _ItemSlotInspector.instantiate()
        item_slot_inspector.init(object as ItemSlot)
        add_custom_control(item_slot_inspector)
