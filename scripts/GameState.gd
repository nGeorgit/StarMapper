extends Node
## Autoload singleton: which mode Main.tscn should run in, set by MainMenu before
## the scene switch. Also reads a --mode= CLI flag as a dev-only shortcut so the sky
## scene can be screenshot-tested headlessly without clicking through the menu.

enum Mode { EXPLORE, QUIZ }
enum QuizType { CONSTELLATIONS }
enum Difficulty { EASY, MEDIUM, HARD }
enum SkyChoice { NORTH, SOUTH, LOCATION }
enum Season { WINTER, SUMMER, CURRENT }

var mode: Mode = Mode.EXPLORE
var quiz_type: QuizType = QuizType.CONSTELLATIONS
var difficulty: Difficulty = Difficulty.EASY
var sky_choice: SkyChoice = SkyChoice.LOCATION
var season: Season = Season.CURRENT

func _ready() -> void:
	for arg in OS.get_cmdline_args():
		if arg == "--mode=quiz":
			mode = Mode.QUIZ
		elif arg == "--mode=explore":
			mode = Mode.EXPLORE
