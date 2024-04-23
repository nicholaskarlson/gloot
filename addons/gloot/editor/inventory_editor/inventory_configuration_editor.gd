@tool
extends Control

const Undoables = preload("res://addons/gloot/editor/undoables.gd")

@export var inventory: Inventory :
    set(new_inventory):
        if new_inventory == inventory:
            return
        _disconnect_inventory_signals()
        inventory = new_inventory
        _connect_inventory_signals()
        _refresh()


func _connect_inventory_signals() -> void:
    if !is_instance_valid(inventory):
        return

    inventory.constraint_enabled.connect(_on_constraint_enabled)
    inventory.pre_constraint_disabled.connect(_on_pre_constraint_disabled)


func _disconnect_inventory_signals() -> void:
    if !is_instance_valid(inventory):
        return

    inventory.constraint_enabled.disconnect(_on_constraint_enabled)
    inventory.pre_constraint_disabled.disconnect(_on_pre_constraint_disabled)


func _on_constraint_enabled(constraint: int) -> void:
    _enable_constraint_editing(constraint)
    if constraint == Inventory.Constraint.WEIGHT:
        _safe_connect(inventory.get_weight_constraint().capacity_changed, _on_capacity_changed)
    elif constraint == Inventory.Constraint.GRID:
        _safe_connect(inventory.get_grid_constraint().size_changed, _on_size_changed)


func _on_pre_constraint_disabled(constraint: int) -> void:
    _disable_constraint_editing(constraint)
    if constraint == Inventory.Constraint.WEIGHT:
        _safe_disconnect(inventory.get_weight_constraint().capacity_changed, _on_capacity_changed)
    elif constraint == Inventory.Constraint.GRID:
        _safe_disconnect(inventory.get_grid_constraint().size_changed, _on_size_changed)


func _enable_constraint_editing(constraint: int) -> void:
    _disconnect_ui_signals()

    if constraint == Inventory.Constraint.WEIGHT:
        if !%CheckBoxWeightConstraint.button_pressed:
            %CheckBoxWeightConstraint.button_pressed = true
        %LineEditCapacity.editable = true
        %LineEditCapacity.text = str(inventory.get_weight_constraint().capacity)
    elif constraint == Inventory.Constraint.STACKS:
        if !%CheckBoxStacksConstraint.button_pressed:
            %CheckBoxStacksConstraint.button_pressed = true
    elif constraint == Inventory.Constraint.GRID:
        var grid_constraint := inventory.get_grid_constraint()
        if !%CheckBoxGridConstraint.button_pressed:
            %CheckBoxGridConstraint.button_pressed = true
        %LineEditSizeX.editable = true
        %LineEditSizeX.text = str(grid_constraint.size.x)
        %LineEditSizeY.editable = true
        %LineEditSizeY.text = str(grid_constraint.size.y)

    _connect_ui_signals()


func _disable_constraint_editing(constraint: int) -> void:
    _disconnect_ui_signals()

    if constraint == Inventory.Constraint.WEIGHT:
        if %CheckBoxWeightConstraint.button_pressed:
            %CheckBoxWeightConstraint.button_pressed = false
        %LineEditCapacity.editable = false
        %LineEditCapacity.text = ""
    elif constraint == Inventory.Constraint.STACKS:
        if %CheckBoxStacksConstraint.button_pressed:
            %CheckBoxStacksConstraint.button_pressed = false
    elif constraint == Inventory.Constraint.GRID:
        if %CheckBoxGridConstraint.button_pressed:
            %CheckBoxGridConstraint.button_pressed = false
        %LineEditSizeX.editable = false
        %LineEditSizeX.text = ""
        %LineEditSizeY.editable = false
        %LineEditSizeY.text = ""

    _connect_ui_signals()


func _on_capacity_changed() -> void:
    _disconnect_ui_signals()

    var str_capacity := str(inventory.get_weight_constraint().capacity)
    if %LineEditCapacity.text != str_capacity:
        %LineEditCapacity.text = str_capacity

    _connect_ui_signals()


func _on_size_changed() -> void:
    _disconnect_ui_signals()

    var str_size_x := str(inventory.get_grid_constraint().size.x)
    var str_size_y := str(inventory.get_grid_constraint().size.y)
    if %LineEditSizeX.text != str_size_x:
        %LineEditSizeX.text = str_size_x
    if %LineEditSizeY.text != str_size_y:
        %LineEditSizeY.text = str_size_y

    _connect_ui_signals()


func _ready() -> void:
    _refresh()


func _refresh() -> void:
    _disconnect_ui_signals()

    %CheckBoxWeightConstraint.disabled = true
    %CheckBoxStacksConstraint.disabled = true
    %CheckBoxGridConstraint.disabled = true
    _disable_constraint_editing(Inventory.Constraint.WEIGHT)
    _disable_constraint_editing(Inventory.Constraint.STACKS)
    _disable_constraint_editing(Inventory.Constraint.GRID)
    
    if !is_instance_valid(inventory):
        return

    %CheckBoxWeightConstraint.disabled = false
    %CheckBoxStacksConstraint.disabled = false
    %CheckBoxGridConstraint.disabled = false
    if is_instance_valid(inventory.get_weight_constraint()):
        _enable_constraint_editing(Inventory.Constraint.WEIGHT)
    if is_instance_valid(inventory.get_stacks_constraint()):
        _enable_constraint_editing(Inventory.Constraint.STACKS)
    if is_instance_valid(inventory.get_grid_constraint()):
        _enable_constraint_editing(Inventory.Constraint.GRID)

    _connect_ui_signals()


func _connect_ui_signals() -> void:
    _safe_connect(%CheckBoxWeightConstraint.toggled, _on_weight_constraint_toggled)
    _safe_connect(%CheckBoxStacksConstraint.toggled, _on_stacks_constraint_toggled)
    _safe_connect(%CheckBoxGridConstraint.toggled, _on_grid_constraint_toggled)

    _safe_connect(%LineEditCapacity.text_submitted, _set_capacity)
    _safe_connect(%LineEditCapacity.focus_exited, _on_capacity_focus_exited)
    _safe_connect(%LineEditSizeX.text_submitted, _set_size_x)
    _safe_connect(%LineEditSizeX.focus_exited, _on_size_x_focus_exited)
    _safe_connect(%LineEditSizeY.text_submitted, _set_size_y)
    _safe_connect(%LineEditSizeY.focus_exited, _on_size_y_focus_exited)


func _disconnect_ui_signals() -> void:
    _safe_disconnect(%CheckBoxWeightConstraint.toggled, _on_weight_constraint_toggled)
    _safe_disconnect(%CheckBoxStacksConstraint.toggled, _on_stacks_constraint_toggled)
    _safe_disconnect(%CheckBoxGridConstraint.toggled, _on_grid_constraint_toggled)

    _safe_disconnect(%LineEditCapacity.text_submitted, _set_capacity)
    _safe_disconnect(%LineEditCapacity.focus_exited, _on_capacity_focus_exited)
    _safe_disconnect(%LineEditSizeX.text_submitted, _set_size_x)
    _safe_disconnect(%LineEditSizeX.focus_exited, _on_size_x_focus_exited)
    _safe_disconnect(%LineEditSizeY.text_submitted, _set_size_y)
    _safe_disconnect(%LineEditSizeY.focus_exited, _on_size_y_focus_exited)


func _on_weight_constraint_toggled(toggled_on: bool) -> void:
    if toggled_on:
        Undoables.exec_inventory_undoable([inventory], "Enable Weight Constraint", func():
            if !is_instance_valid(inventory.get_weight_constraint()):
                inventory.enable_weight_constraint()
                return true
            return false
        )
    else:
        Undoables.exec_inventory_undoable([inventory], "Disable Weight Constraint", func():
            if is_instance_valid(inventory.get_weight_constraint()):
                inventory.disable_weight_constraint()
                return true
            return false
        )


func _on_stacks_constraint_toggled(toggled_on: bool) -> void:
    if toggled_on:
        Undoables.exec_inventory_undoable([inventory], "Enable Stacks Constraint", func():
            if !is_instance_valid(inventory.get_stacks_constraint()):
                inventory.enable_stacks_constraint()
                return true
            return false
        )
    else:
        Undoables.exec_inventory_undoable([inventory], "Disable Stacks Constraint", func():
            if is_instance_valid(inventory.get_stacks_constraint()):
                inventory.disable_stacks_constraint()
                return true
            return false
        )

            
func _on_grid_constraint_toggled(toggled_on: bool) -> void:
    if toggled_on:
        Undoables.exec_inventory_undoable([inventory], "Enable Grid Constraint", func():
            if !is_instance_valid(inventory.get_grid_constraint()):
                inventory.enable_grid_constraint()
                return true
            return false
        )
    else:
        Undoables.exec_inventory_undoable([inventory], "Disable Grid Constraint", func():
            if is_instance_valid(inventory.get_grid_constraint()):
                inventory.disable_grid_constraint()
                return true
            return false
        )


func _set_capacity(str_capacity: String) -> void:
    if is_instance_valid(inventory.get_weight_constraint()):
        inventory.get_weight_constraint().capacity = float(str_capacity)
        _on_capacity_changed()


func _set_size_x(str_size_x: String) -> void:
    if is_instance_valid(inventory.get_grid_constraint()):
        inventory.get_grid_constraint().size = Vector2i(int(str_size_x), inventory.get_grid_constraint().size.y)
        _on_size_changed()


func _set_size_y(str_size_y: String) -> void:
    if is_instance_valid(inventory.get_grid_constraint()):
        inventory.get_grid_constraint().size = Vector2i(inventory.get_grid_constraint().size.x, int(str_size_y))
        _on_size_changed()


func _on_capacity_focus_exited() -> void:
    _set_capacity(%LineEditCapacity.text)


func _on_size_x_focus_exited() -> void:
    _set_size_x(%LineEditSizeX.text)


func _on_size_y_focus_exited() -> void:
    _set_size_y(%LineEditSizeY.text)


func _safe_connect(s: Signal, c: Callable) -> void:
    if !s.is_connected(c):
        s.connect(c)


func _safe_disconnect(s: Signal, c: Callable) -> void:
    if s.is_connected(c):
        s.disconnect(c)

