extends Node
class_name StanceComponent

enum Stance { LOCOMOTION, COMBAT, STEALTH }

signal stance_changed(new_stance: Stance)

var current_stance := Stance.LOCOMOTION:
	set(value):
		if value != current_stance:
			current_stance = value
			stance_changed.emit(current_stance)

func enter_combat():  current_stance = Stance.COMBAT
func enter_stealth(): current_stance = Stance.STEALTH
func enter_normal():  current_stance = Stance.LOCOMOTION
