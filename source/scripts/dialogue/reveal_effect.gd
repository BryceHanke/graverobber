extends RichTextEffect
class_name RevealEffect

# Syntax: [reveal][/reveal]
var bbcode = "reveal"

enum RevealType {
	NONE,
	HOP,
	FADE,
	SLIDE
}

var progress: float = 0.0
var style: int = RevealType.NONE

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var idx = char_fx.absolute_index

	# If the character is not yet reached by progress, hide it.
	if idx >= progress:
		char_fx.color.a = 0.0
		return true

	# Calculate how "deep" we are into the revealed section.
	# t represents how many "characters ago" this was revealed.
	# t = 0 means just revealed. t = 1 means revealed 1 character duration ago.
	var t = progress - idx

	# If t is large, the animation is finished. We can optimize or just clamp.
	# Let's say animations last for 2.0 "character units".
	if t > 2.0:
		return true

	match style:
		RevealType.HOP:
			# Hop: jump up and land.
			# Using a simple sine or parabola.
			# Let's say it hops for 0.5 units of time (half a character duration? might be too fast).
			# Let's make it last 1.0 unit.
			if t < 1.0:
				var y_off = -5.0 * sin(t * PI)
				char_fx.offset.y += y_off

		RevealType.FADE:
			# Fade in alpha.
			if t < 1.0:
				char_fx.color.a = t

		RevealType.SLIDE:
			# Slide from left.
			if t < 1.0:
				var x_off = -10.0 * (1.0 - t)
				char_fx.offset.x += x_off
				char_fx.color.a = t

	return true
