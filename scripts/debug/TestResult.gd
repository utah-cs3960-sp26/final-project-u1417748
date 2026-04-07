extends RefCounted
class_name TestResult

enum Status {
	PASSED,
	FAILED,
	SKIPPED,
}

var test_id: String = ""
var category: String = ""
var status: Status = Status.SKIPPED
var details: PackedStringArray = PackedStringArray()
var artifacts: PackedStringArray = PackedStringArray()
var duration_seconds: float = 0.0

static func passed(id: String, category_name: String, detail_lines: PackedStringArray = PackedStringArray()) -> TestResult:
	var result := TestResult.new()
	result.test_id = id
	result.category = category_name
	result.status = Status.PASSED
	result.details = detail_lines
	return result

static func failed(id: String, category_name: String, detail_lines: PackedStringArray = PackedStringArray()) -> TestResult:
	var result := TestResult.new()
	result.test_id = id
	result.category = category_name
	result.status = Status.FAILED
	result.details = detail_lines
	return result

static func skipped(id: String, category_name: String, detail_lines: PackedStringArray = PackedStringArray()) -> TestResult:
	var result := TestResult.new()
	result.test_id = id
	result.category = category_name
	result.status = Status.SKIPPED
	result.details = detail_lines
	return result

func status_text() -> String:
	return Status.keys()[status]

func to_dictionary() -> Dictionary:
	return {
		"test_id": test_id,
		"category": category,
		"status": status_text(),
		"details": details,
		"artifacts": artifacts,
		"duration_seconds": duration_seconds,
	}
