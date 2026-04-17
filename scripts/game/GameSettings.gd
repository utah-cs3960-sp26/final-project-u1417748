extends Node

signal changed(key: String, value: bool)

var show_controls: bool = true
var no_defenders: bool = false
var show_debug: bool = false


func set_show_controls(enabled: bool) -> void:
	if show_controls == enabled:
		return
	show_controls = enabled
	changed.emit("show_controls", enabled)


func set_no_defenders(enabled: bool) -> void:
	if no_defenders == enabled:
		return
	no_defenders = enabled
	changed.emit("no_defenders", enabled)


func set_show_debug(enabled: bool) -> void:
	if show_debug == enabled:
		return
	show_debug = enabled
	changed.emit("show_debug", enabled)
