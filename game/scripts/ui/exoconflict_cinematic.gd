extends Control
signal finished
signal skipped

var _timer: float = 0.0
var _duration: float = 6.0
var _skipped: bool = false

func _process(delta: float) -> void:
	if _skipped:
		return
	_timer += delta
	if _timer >= _duration:
		emit_finished()


func emit_finished() -> void:
	if _skipped:
		return
	_skipped = true
	finished.emit()


func _on_skip_pressed() -> void:
	_skipped = true
	skipped.emit()
	finished.emit()
