extends "res://ThreeKingdom/systems/tianshu_system.gd"

# 金币只在当前一局内有效，不进入永久养成结算。
const INITIAL_GOLD := 200
const ROUND_BASE_INCOME := 100
const ROUND_INCOME_GROWTH := 50
const BASE_INTEREST_CAP := 50
const TIANSHU_DRAW_COST := 500
const TIANSHU_REPLACE_COST := 300
const RESERVE_SELL_PRICE := 100
const DEPLOYED_SELL_PRICE := 70
const FREE_TIANSHU_ROUNDS := [3, 6, 9, 12, 15]

var gold := 0
var economy_income_round := 0
var tianshu_replacements_this_round := 0

func _reset_economy_run() -> void:
	gold = INITIAL_GOLD
	economy_income_round = 0
	tianshu_replacements_this_round = 0

func _end_economy_run() -> void:
	gold = 0
	economy_income_round = 0
	tianshu_replacements_this_round = 0

func _round_base_gold_income() -> int:
	var result := ROUND_BASE_INCOME + maxi(0, round_number - 1) * ROUND_INCOME_GROWTH
	result += 50 * _tianshu_level("tuntian_kaifu")
	if _tianshu_level("fujia_tianxia") >= 2:
		result += 20
	return result

func _gold_interest_cap() -> int:
	var result := BASE_INTEREST_CAP
	var rich_level := _tianshu_level("fujia_tianxia")
	if rich_level == 1:
		result += 20
	elif rich_level >= 2:
		result += 40
	return result

func _settle_round_economy() -> Dictionary:
	if economy_income_round == round_number:
		return {"interest":0, "income":0, "total":0}
	tianshu_replacements_this_round = 0
	var interest := mini(floori(float(gold) / 10.0), _gold_interest_cap())
	var income := _round_base_gold_income()
	gold += interest + income
	economy_income_round = round_number
	_log("[color=#e8c96e]【金币】第 %d 回合：利息 +%d，基础收入 +%d，当前 %d。[/color]" % [round_number, interest, income, gold])
	return {"interest":interest, "income":income, "total":interest + income}

func _earn_gold(amount: int, reason := "") -> int:
	var earned := maxi(0, amount)
	if earned <= 0:
		return 0
	gold += earned
	if not reason.is_empty():
		_log("[color=#e8c96e]【金币】%s +%d，当前 %d。[/color]" % [reason, earned, gold])
	if has_method("_refresh_economy_ui"):
		call_deferred("_refresh_economy_ui")
	return earned

func _spend_gold(amount: int, reason := "") -> bool:
	var cost := maxi(0, amount)
	if gold < cost:
		_log("[color=#e07070]金币不足：%s需要 %d，当前仅有 %d。[/color]" % [reason, cost, gold])
		return false
	gold -= cost
	if not reason.is_empty():
		_log("[color=#e8c96e]【金币】%s -%d，剩余 %d。[/color]" % [reason, cost, gold])
	if has_method("_refresh_economy_ui"):
		call_deferred("_refresh_economy_ui")
	return true

func _is_free_tianshu_round() -> bool:
	return round_number in FREE_TIANSHU_ROUNDS

func _can_use_tianshu_pavilion() -> bool:
	return _tianshu_enabled() and not battle_running and phase in ["draft", "placement"]

func _buy_tianshu_draw() -> bool:
	if not _can_use_tianshu_pavilion():
		return false
	var available_count := TIANSHU_BOOKS.keys().filter(func(book_id): return _tianshu_level(str(book_id)) < 2).size()
	if available_count < 3:
		_log("[color=#e07070]可选天书不足三本，无法继续购买。[/color]")
		return false
	if not _spend_gold(TIANSHU_DRAW_COST, "购买天书三选一"):
		return false
	var return_phase := phase
	_begin_tianshu_draw(1, "purchase", return_phase, false)
	_render()
	return true

func _tianshu_replace_cost() -> int:
	var discount := 0
	var level := _tianshu_level("maidu_huanzhu")
	if level == 1:
		discount = 80
	elif level >= 2:
		discount = 200
	return maxi(0, TIANSHU_REPLACE_COST - discount)

func _replace_tianshu(book_id: String) -> bool:
	if not _can_use_tianshu_pavilion() or not tianshu_levels.has(book_id):
		return false
	if tianshu_replacements_this_round >= 1:
		_log("[color=#e07070]本回合已经替换过一次天书。[/color]")
		return false
	var cost := _tianshu_replace_cost()
	if not _spend_gold(cost, "替换天书"):
		return false
	var removed_level := clampi(_tianshu_level(book_id), 1, 2)
	tianshu_levels.erase(book_id)
	if str(tianshu_pool_effect.get("book_id", "")) == book_id:
		tianshu_pool_effect.clear()
	tianshu_replacements_this_round += 1
	_log("[color=#e5a8ff]已替换【%s %s】，获得 %d 次天书三选一。[/color]" % [_tianshu_name(book_id), "Ⅱ" if removed_level == 2 else "Ⅰ", removed_level])
	var return_phase := phase
	_begin_tianshu_draw(removed_level, "replace", return_phase, false)
	_render()
	return true

func _unit_sell_price(unit: Dictionary) -> int:
	return DEPLOYED_SELL_PRICE if int(unit.get("row", -1)) >= 0 else RESERVE_SELL_PRICE

func _economy_save_state() -> Dictionary:
	return {
		"gold":gold,
		"income_round":economy_income_round,
		"replacements_this_round":tianshu_replacements_this_round
	}

func _load_economy_state(value) -> void:
	if not value is Dictionary:
		gold = 0
		economy_income_round = round_number
		tianshu_replacements_this_round = 0
		return
	gold = maxi(0, int(value.get("gold", 0)))
	economy_income_round = clampi(int(value.get("income_round", round_number)), 0, ROUND_LIMIT)
	tianshu_replacements_this_round = clampi(int(value.get("replacements_this_round", 0)), 0, 1)
