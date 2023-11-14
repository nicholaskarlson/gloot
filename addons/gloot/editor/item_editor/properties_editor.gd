@tool
extends Window

const Undoables = preload("res://addons/gloot/editor/undoables.gd")
const GridConstraint = preload("res://addons/gloot/core/constraints/grid_constraint.gd")
const DictEditor = preload("res://addons/gloot/editor/common/dict_editor.tscn")
const EditorIcons = preload("res://addons/gloot/editor/common/editor_icons.gd")
const COLOR_OVERRIDDEN = Color.GREEN
const COLOR_INVALID = Color.RED
var IMMUTABLE_KEYS: Array[String] = [ItemProtoset.KEY_ID]

@onready var _margin_container: MarginContainer = $"MarginContainer"
@onready var _dict_editor: Control = $"MarginContainer/DictEditor"
var item: InventoryItem = null :
    set(new_item):
        if new_item == null:
            return
        item = new_item
        _refresh()


func _ready() -> void:
    about_to_popup.connect(func(): _refresh())
    close_requested.connect(func(): hide())
    _dict_editor.value_changed.connect(func(key: String, new_value): _on_value_changed(key, new_value))
    _dict_editor.value_removed.connect(func(key: String): _on_value_removed(key))
    hide()


func _on_value_changed(key: String, new_value) -> void:
    Undoables.exec_item_undoable(item, "Set Item Property", func():
        item.set_property(key, new_value)
        return true
    )
    _refresh()


func _on_value_removed(key: String) -> void:
    Undoables.exec_item_undoable(item, "Clear Item Property", func():
        item.clear_property(key)
        return true
    )
    _refresh()


func _refresh() -> void:
    if _dict_editor.btn_add:
        _dict_editor.btn_add.icon = EditorIcons.get_icon("Add")
    _dict_editor.dictionary = _get_dictionary()
    _dict_editor.color_map = _get_color_map()
    _dict_editor.remove_button_map = _get_remove_button_map()
    _dict_editor.immutable_keys = IMMUTABLE_KEYS
    _dict_editor.refresh()


func _get_dictionary() -> Dictionary:
    if item == null:
        return {}

    if !item.protoset:
        return {}

    if !item.protoset.has_prototype(item.prototype_id):
        return {}

    var result: Dictionary = item.protoset.get_prototype(item.prototype_id).duplicate()
    for key in item.get_properties():
        result[key] = item.get_property(key)
    return result


func _get_color_map() -> Dictionary:
    if item == null:
        return {}

    if !item.protoset:
        return {}

    var result: Dictionary = {}
    var dictionary: Dictionary = _get_dictionary()
    for key in dictionary.keys():
        if item.is_property_overridden(key):
            result[key] = COLOR_OVERRIDDEN
        if key == ItemProtoset.KEY_ID && !item.protoset.has_prototype(dictionary[key]):
            result[key] = COLOR_INVALID

    return result
            

func _get_remove_button_map() -> Dictionary:
    if item == null:
        return {}

    if !item.protoset:
        return {}

    var result: Dictionary = {}
    var dictionary: Dictionary = _get_dictionary()
    for key in dictionary.keys():
        result[key] = {}
        if item.protoset.get_prototype(item.prototype_id).has(key):
            result[key]["text"] = ""
            result[key]["icon"] = EditorIcons.get_icon("Reload")
        else:
            result[key]["text"] = ""
            result[key]["icon"] = EditorIcons.get_icon("Remove")

        result[key]["disabled"] = (not item.is_property_overridden(key)) or (key in IMMUTABLE_KEYS)
    return result

