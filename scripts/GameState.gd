extends Node
## Autoload singleton: which mode Main.tscn should run in, set by MainMenu before
## the scene switch. Also reads a --mode= CLI flag as a dev-only shortcut so the sky
## scene can be screenshot-tested headlessly without clicking through the menu.

enum Mode { EXPLORE, QUIZ }
enum QuizType { CONSTELLATIONS }
enum Difficulty { EASY, MEDIUM, HARD }
enum SkyChoice { NORTH, SOUTH, LOCATION }
enum Season { WINTER, SUMMER, CURRENT }
enum QuizLength { THIRTY, FIFTY, HUNDRED }

const NORTH_LAT_DEG := 60.0
const SOUTH_LAT_DEG := -60.0
const MIN_VISIBLE_ALTITUDE_DEG := 10.0

var mode: Mode = Mode.EXPLORE
var quiz_type: QuizType = QuizType.CONSTELLATIONS
var difficulty: Difficulty = Difficulty.EASY
var sky_choice: SkyChoice = SkyChoice.LOCATION
var season: Season = Season.CURRENT
var quiz_length: QuizLength = QuizLength.HUNDRED
var quiz_round_count: int = 10
var dev_mode: bool = false

## AR (point-the-phone) mode, persisted across scene reloads since CameraRig is
## re-instantiated per scene. In-memory only -- doesn't need to survive an app
## restart the way QuizProgress does.
var ar_mode_enabled: bool = false
var ar_heading_offset_deg: float = 0.0

func _ready() -> void:
	for arg in OS.get_cmdline_args():
		if arg == "--mode=quiz":
			mode = Mode.QUIZ
		elif arg == "--mode=explore":
			mode = Mode.EXPLORE
