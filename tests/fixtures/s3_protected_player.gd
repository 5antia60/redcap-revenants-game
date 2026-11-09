extends "res://src/player/player.gd"
## Apenas ensaio: corpo/movimento/desenho originais, dano recusado para durar60s.
var attempted_hits: int = 0
func receive_hit(_amount: int) -> bool:
	attempted_hits += 1
	return false
