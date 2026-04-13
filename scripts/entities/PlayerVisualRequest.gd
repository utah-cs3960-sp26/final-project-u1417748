class_name PlayerVisualRequest
extends RefCounted

var animation_family: String = "no_ball_idle"
var variant_index: int = 0
var mirror_west: bool = false
var show_outline: bool = false
var force_restart: bool = false
var allow_dunk_contact_hold: bool = false


func _init(
	p_animation_family: String = "no_ball_idle",
	p_variant_index: int = 0,
	p_mirror_west: bool = false,
	p_show_outline: bool = false,
	p_force_restart: bool = false,
	p_allow_dunk_contact_hold: bool = false
) -> void:
	animation_family = p_animation_family
	variant_index = p_variant_index
	mirror_west = p_mirror_west
	show_outline = p_show_outline
	force_restart = p_force_restart
	allow_dunk_contact_hold = p_allow_dunk_contact_hold
