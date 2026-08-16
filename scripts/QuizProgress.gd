extends Node
## Autoload: persists the player's best score for every (culture, difficulty, sky,
## season, quiz length) combo they've run, and derives each menu level's progress %
## purely from its own direct children, one level down, recursively:
##   length (leaf) -- best_correct/best_total of that exact combo, 0 if never attempted
##   season         -- avg of its 3 quiz-length children
##   difficulty     -- avg of its Winter/Summer season children
##   culture (+sky) -- avg of its Easy/Medium/Hard difficulty children
##   sky            -- avg of its culture children (every culture visible in that sky)
##   overall        -- avg of its North/South sky children
## An unattempted child counts as 0 in its parent's average (it's not skipped), so a
## single 50%-correct run already pulls its season/difficulty/etc above 0%.
## Sky=LOCATION and Season=CURRENT are excluded from every average entirely: their
## pool depends on real position/date rather than a fixed, repeatable quiz, so they
## aren't a comparable milestone the way North/South + Winter/Summer are. Their best
## scores are still tracked/shown, just never counted as a child in any average.

const SAVE_PATH := "user://quiz_progress.json"
const TRACKED_SKIES := [GameState.SkyChoice.NORTH, GameState.SkyChoice.SOUTH]
const TRACKED_SEASONS := [GameState.Season.WINTER, GameState.Season.SUMMER]
const LENGTHS := [GameState.QuizLength.THIRTY, GameState.QuizLength.FIFTY, GameState.QuizLength.HUNDRED]
const DIFFICULTIES := [GameState.Difficulty.EASY, GameState.Difficulty.MEDIUM, GameState.Difficulty.HARD]

var _data: Dictionary = {}  ## culture_id -> "DIFFICULTY|SKY|SEASON|LENGTH" -> {"best_correct", "best_total"}

func _ready() -> void:
	_load()

## Records a finished quiz's score, keeping only the best (highest-correct) run per
## exact combo. Called for every run regardless of sky/season, since QuizLengthMenu
## shows the best score even for untracked (Location/Current) combos.
func record_result(culture_id: String, difficulty: GameState.Difficulty, sky: GameState.SkyChoice,
		season: GameState.Season, length: GameState.QuizLength, correct: int, total: int) -> void:
	if not _data.has(culture_id):
		_data[culture_id] = {}
	var key := _key(difficulty, sky, season, length)
	var existing: Dictionary = _data[culture_id].get(key, {})
	if existing.is_empty() or correct > int(existing["best_correct"]):
		_data[culture_id][key] = {"best_correct": correct, "best_total": total}
		_save()

## {"best_correct", "best_total"} for this exact combo+length, or {} if never attempted.
func get_best(culture_id: String, difficulty: GameState.Difficulty, sky: GameState.SkyChoice,
		season: GameState.Season, length: GameState.QuizLength) -> Dictionary:
	var culture_data: Dictionary = _data.get(culture_id, {})
	return culture_data.get(_key(difficulty, sky, season, length), {})

## Leaf: this exact combo's best score %, or 0 if never attempted. Used by
## QuizLengthMenu.
func length_pct(culture_id: String, difficulty: GameState.Difficulty, sky: GameState.SkyChoice,
		season: GameState.Season, length: GameState.QuizLength) -> float:
	var best := get_best(culture_id, difficulty, sky, season, length)
	return 0.0 if best.is_empty() or int(best["best_total"]) == 0 \
		else 100.0 * int(best["best_correct"]) / int(best["best_total"])

## Avg of the 3 quiz lengths under this exact combo. Used by SeasonMenu.
func season_pct(culture_id: String, difficulty: GameState.Difficulty, sky: GameState.SkyChoice, season: GameState.Season) -> float:
	var values: Array[float] = []
	for length in LENGTHS:
		values.append(length_pct(culture_id, difficulty, sky, season, length))
	return _avg(values)

## Avg of the Winter/Summer seasons under this culture+difficulty+sky (only seasons
## that actually have something visible to quiz -- a season with nothing visible for
## this culture+sky was never a real child to begin with). Used by DifficultyMenu.
func difficulty_pct(culture_id: String, difficulty: GameState.Difficulty, sky: GameState.SkyChoice) -> float:
	var constellations := QuizAvailability.load_culture_raw(culture_id)
	var values: Array[float] = []
	for season in TRACKED_SEASONS:
		if QuizAvailability.visible_count(constellations, sky, season) > 0:
			values.append(season_pct(culture_id, difficulty, sky, season))
	return _avg(values)

## Avg of Easy/Medium/Hard under this culture+sky. Used by CultureMenu -- sky is
## already fixed by that point (Sky is picked before Culture).
func culture_pct(culture_id: String, sky: GameState.SkyChoice) -> float:
	var values: Array[float] = []
	for difficulty in DIFFICULTIES:
		values.append(difficulty_pct(culture_id, difficulty, sky))
	return _avg(values)

## Avg of every culture visible under this sky. Used by SkyMenu, picked before any
## culture.
func sky_pct(sky: GameState.SkyChoice) -> float:
	var values: Array[float] = []
	for culture in ConstellationSets.available:
		var raw := QuizAvailability.load_culture_raw(culture["id"])
		if QuizAvailability.has_any_visible(raw, sky):
			values.append(culture_pct(culture["id"], sky))
	return _avg(values)

## Avg of North/South. Used by QuizTypeMenu, the first step.
func overall_pct() -> float:
	var values: Array[float] = []
	for sky in TRACKED_SKIES:
		values.append(sky_pct(sky))
	return _avg(values)

func _avg(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sum := 0.0
	for v in values:
		sum += v
	return sum / values.size()

func _key(difficulty: GameState.Difficulty, sky: GameState.SkyChoice, season: GameState.Season, length: GameState.QuizLength) -> String:
	return "%d|%d|%d|%d" % [difficulty, sky, season, length]

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	_data = parsed if parsed is Dictionary else {}

func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_data))
