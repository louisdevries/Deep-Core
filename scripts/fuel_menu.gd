extends CanvasLayer

@onready var money_label: Label = $Panel/VBox/HeaderHBox/MoneyLabel
@onready var fuel_bar: ProgressBar = $Panel/VBox/FuelBar
@onready var buttons_container: VBoxContainer = $Panel/VBox/ButtonsContainer
@onready var close_button: Button = $Panel/VBox/CloseButton

const FUEL_PRICE_PER_UNIT: float = 2.0

var player: Node = null


func _ready() -> void:
	visible = false
	close_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()


func open(target_player: Node) -> void:
	player = target_player
	visible = true
	get_tree().paused = true
	rebuild()


func close() -> void:
	visible = false
	get_tree().paused = false


func rebuild() -> void:
	money_label.text = "$" + str(player.money)
	fuel_bar.max_value = player.max_fuel
	fuel_bar.value = player.fuel

	for c in buttons_container.get_children():
		buttons_container.remove_child(c)
		c.queue_free()

	var fractions := [0.25, 0.5, 0.75, 1.0]
	var labels_text := ["1/4 Tank", "1/2 Tank", "3/4 Tank", "Full Tank"]

	for i in fractions.size():
		var target_fuel: float = fractions[i] * player.max_fuel
		var amount: float = maxf(0.0, target_fuel - player.fuel)
		var cost: int = int(ceil(amount * FUEL_PRICE_PER_UNIT))

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var info := Label.new()
		info.text = "%s  (+%.0f fuel)  $%d" % [labels_text[i], amount, cost]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var btn := Button.new()
		btn.text = "Buy"
		btn.disabled = player.money < cost or amount <= 0.0
		btn.pressed.connect(_on_buy_fuel.bind(target_fuel, cost))
		row.add_child(btn)

		buttons_container.add_child(row)


func _on_buy_fuel(target_fuel: float, cost: int) -> void:
	if player.money < cost:
		return
	player.money -= cost
	player.fuel = minf(player.max_fuel, target_fuel)
	rebuild()
