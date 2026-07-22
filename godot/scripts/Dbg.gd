extends Node
## Debug toast helper. Call Dbg.toast("...") from anywhere to flash a message in the
## React shell's on-screen toast stack (debounced there so repeats don't spam). Always
## also prints to the Godot output, so it works in the editor / non-web too.
##
## Usage:
##   Dbg.toast("robot jumped")
##   Dbg.toast("hp now %d" % b.hp)
##   Dbg.toast("seek", "robot-fsm")   # 2nd arg = debounce key (defaults to the text)

func toast(text: Variant, key: String = "") -> void:
	var msg := str(text)
	print("[toast] ", msg)
	JsBridge.emit_event("game:debug_toast", {
		"text": msg,
		"key": key if key != "" else msg,
	})
