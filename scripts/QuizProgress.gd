extends Node
## Autoload: persists the player's best score for every (culture, difficulty, sky,
## season, quiz length) combo they've run, and derives each culture's completion %
## from it. A difficulty+sky+season combo only counts as "done" once ALL THREE
## lengths (30/50/100%) have each been beaten with a perfect score -- a partial-length
## perfect run alone isn't enough, since it necessarily skips some constellations.
## Sky=LOCATION and Season=CURRENT are excluded from the completion % entirely: their
## pool depends on real position/date rather than a fixed, repeatable quiz, so
## "completing" them isn't a comparable milestone the way North/South + Winter/Summer
## are. Their best scores are still tracked/shown, just not counted toward %.

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

## % of this culture's difficulty+sky+season combos (North/South x Winter/Summer x
## Easy/Medium/Hard) that have been perfected at all three quiz lengths. Combos whose
## sky/season pairing has nothing to quiz for this culture don't count toward the total.
func culture_completion_pct(culture_id: String) -> float:
	var constellations := QuizAvailability.load_culture_raw(culture_id)
	if constellations.is_empty():
		return 0.0
	var culture_data: Dictionary = _data.get(culture_id, {})
	var total_combos := 0
	var completed_combos := 0
	for sky in TRACKED_SKIES:
		for season in TRACKED_SEASONS:
			if QuizAvailability.visible_count(constellations, sky, season) == 0:
				continue
			for difficulty in DIFFICULTIES:
				total_combos += 1
				var all_lengths_perfect := true
				for length in LENGTHS:
					var best: Dictionary = culture_data.get(_key(difficulty, sky, season, length), {})
					if best.is_empty() or int(best["best_correct"]) != int(best["best_total"]) or int(best["best_total"]) == 0:
						all_lengths_perfect = false
						break
				if all_lengths_perfect:
					completed_combos += 1
	return 0.0 if total_combos == 0 else 100.0 * completed_combos / total_combos

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
