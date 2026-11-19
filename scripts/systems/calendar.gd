class_name Calendar
## Calendário do jogo, calculado a partir do dia absoluto (Game.day, começa em 1).
## 4 estações de SEASON_LENGTH dias = 1 ano.

const SEASON_LENGTH := 20
const SEASONS := ["spring", "summer", "autumn", "winter"]
const WEEKDAYS := ["Seg", "Ter", "Qua", "Qui", "Sex", "Sáb", "Dom"]


static func season_index(day: int) -> int:
	return ((day - 1) / SEASON_LENGTH) % 4


static func season_id(day: int) -> String:
	return SEASONS[season_index(day)]


static func day_of_season(day: int) -> int:
	return (day - 1) % SEASON_LENGTH + 1


static func year(day: int) -> int:
	return (day - 1) / (SEASON_LENGTH * 4) + 1


static func week_of_season(day: int) -> int:
	return (day_of_season(day) - 1) / 7 + 1


static func weekday(day: int) -> String:
	return WEEKDAYS[(day - 1) % 7]


## Dias que faltam até a próxima estação (contando o de hoje como 0 se for o último).
static func days_left(day: int) -> int:
	return SEASON_LENGTH - day_of_season(day)


static func season_name(day: int) -> String:
	return CropDB.season(season_id(day)).name


static func short_text(day: int) -> String:
	return "%s %d" % [CropDB.season(season_id(day)).short_name, day_of_season(day)]


## Dá tempo de colher antes da estação acabar? (para o painel de planejamento)
static func fits_in_season(c: CropData, day: int) -> bool:
	var remaining := days_left(day) + 1
	var next := season_id(day + remaining)
	if c.grows_in(next):
		return true
	return c.total_days() <= remaining
