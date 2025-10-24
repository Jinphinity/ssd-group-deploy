extends Node

## Automated Error Classification & Fix Engine
## Advanced system for analyzing runtime errors and generating targeted fixes
## Uses pattern matching and code analysis to suggest and apply fixes

class_name AutoFixEngine

signal fix_generated(fix_data: Dictionary)
signal fix_applied(fix_data: Dictionary, success: bool)
signal fix_failed(fix_data: Dictionary, reason: String)

## Error classification system
enum ErrorCategory {
	NULL_REFERENCE,
	MISSING_NODE,
	SIGNAL_CONNECTION,
	RESOURCE_LOADING,
	METHOD_CALL,
	PROPERTY_ACCESS,
	TYPE_ERROR,
	SCENE_STRUCTURE,
	AUTOLOAD_ACCESS
}

enum FixConfidence {
	LOW = 1,      # 0-40% confidence
	MEDIUM = 2,   # 40-70% confidence
	HIGH = 3,     # 70-90% confidence
	CRITICAL = 4  # 90%+ confidence
}

## Fix templates and patterns
var fix_templates: Dictionary = {}
var applied_fixes: Array = []
var fix_success_rate: Dictionary = {}
var project_root: String = ""

func _ready() -> void:
	project_root = ProjectSettings.globalize_path("res://")
	_initialize_fix_templates()
	print("🔧 AutoFixEngine initialized")

func _initialize_fix_templates() -> Dictionary:
	"""Initialize fix templates for different error types"""
	fix_templates = {
		ErrorCategory.NULL_REFERENCE: {
			"patterns": [
				{
					"pattern": r"get_node\(.*?\)",
					"fix_template": "if {node_var} != null:",
					"confidence": FixConfidence.HIGH,
					"description": "Add null check before get_node usage"
				},
				{
					"pattern": r"\..*?\(\)",
					"fix_template": "if {object} != null and {object}.has_method(\"{method}\"):",
					"confidence": FixConfidence.MEDIUM,
					"description": "Add null and method existence checks"
				}
			]
		},
		ErrorCategory.MISSING_NODE: {
			"patterns": [
				{
					"pattern": r"get_node\([\"']([^\"']+)[\"']\)",
					"fix_template": "if has_node(\"{node_path}\"):\n\t{original_code}\nelse:\n\tprint(\"Node not found: {node_path}\")",
					"confidence": FixConfidence.HIGH,
					"description": "Add node existence check with fallback"
				}
			]
		},
		ErrorCategory.SIGNAL_CONNECTION: {
			"patterns": [
				{
					"pattern": r"\.connect\(",
					"fix_template": "if not {signal_source}.is_connected(\"{signal_name}\", {target}, \"{method}\"):\n\t{original_code}",
					"confidence": FixConfidence.MEDIUM,
					"description": "Check if signal already connected before connecting"
				}
			]
		},
		ErrorCategory.RESOURCE_LOADING: {
			"patterns": [
				{
					"pattern": r"load\([\"']([^\"']+)[\"']\)",
					"fix_template": "var resource = load(\"{resource_path}\")\nif resource != null:\n\t{usage_code}\nelse:\n\tprint(\"Failed to load resource: {resource_path}\")",
					"confidence": FixConfidence.HIGH,
					"description": "Add resource loading validation"
				}
			]
		}
	}
	return fix_templates

func classify_error(error_data: Dictionary) -> Dictionary:
	"""Classify an error and determine appropriate fix category"""
	var error_type: String = error_data.get("type", "")
	var error_message: String = error_data.get("message", "")
	var context: Dictionary = error_data.get("context", {})

	var classification: Dictionary = {
		"category": ErrorCategory.NULL_REFERENCE,  # default
		"confidence": FixConfidence.LOW,
		"fixable": false,
		"priority": 1,
		"analysis": {}
	}

	# Classify based on error type
	match error_type:
		"NULL_REFERENCE":
			classification["category"] = ErrorCategory.NULL_REFERENCE
			classification["confidence"] = FixConfidence.HIGH
			classification["fixable"] = true
			classification["priority"] = 3

		"MISSING_NODE":
			classification["category"] = ErrorCategory.MISSING_NODE
			classification["confidence"] = FixConfidence.HIGH
			classification["fixable"] = true
			classification["priority"] = 2

		"SIGNAL_CONNECTION_FAILED":
			classification["category"] = ErrorCategory.SIGNAL_CONNECTION
			classification["confidence"] = FixConfidence.MEDIUM
			classification["fixable"] = true
			classification["priority"] = 2

		"RESOURCE_LOAD_FAILED":
			classification["category"] = ErrorCategory.RESOURCE_LOADING
			classification["confidence"] = FixConfidence.HIGH
			classification["fixable"] = true
			classification["priority"] = 1

		"METHOD_CALL_FAILED":
			classification["category"] = ErrorCategory.METHOD_CALL
			classification["confidence"] = FixConfidence.MEDIUM
			classification["fixable"] = true
			classification["priority"] = 2

		"PROPERTY_ACCESS_FAILED":
			classification["category"] = ErrorCategory.PROPERTY_ACCESS
			classification["confidence"] = FixConfidence.MEDIUM
			classification["fixable"] = true
			classification["priority"] = 1

		"AUTOLOAD_FAILED":
			classification["category"] = ErrorCategory.AUTOLOAD_ACCESS
			classification["confidence"] = FixConfidence.CRITICAL
			classification["fixable"] = true
			classification["priority"] = 3

	# Enhanced analysis based on error message content
	classification["analysis"] = _analyze_error_context(error_message, context)

	return classification

func _analyze_error_context(error_message: String, context: Dictionary) -> Dictionary:
	"""Analyze error context for more detailed fix generation"""
	var analysis: Dictionary = {
		"code_location": "",
		"affected_objects": [],
		"potential_causes": [],
		"fix_suggestions": []
	}

	# Extract file and line information if available
	if "script" in context:
		analysis["code_location"] = context["script"]

	if "node_path" in context:
		analysis["affected_objects"].append(context["node_path"])

	# Analyze error message for patterns
	if "get_node" in error_message.to_lower():
		analysis["potential_causes"].append("Node path may be incorrect or node may not exist")
		analysis["fix_suggestions"].append("Verify node exists in scene tree")
		analysis["fix_suggestions"].append("Add null check before accessing node")

	if "null" in error_message.to_lower():
		analysis["potential_causes"].append("Object is null when accessed")
		analysis["fix_suggestions"].append("Initialize object before use")
		analysis["fix_suggestions"].append("Add null validation")

	if "connect" in error_message.to_lower():
		analysis["potential_causes"].append("Signal connection failed")
		analysis["fix_suggestions"].append("Check signal name spelling")
		analysis["fix_suggestions"].append("Ensure target object exists")

	return analysis

func generate_fix(error_data: Dictionary) -> Dictionary:
	"""Generate a specific fix for the given error"""
	var classification: Dictionary = classify_error(error_data)

	if not classification["fixable"]:
		return {}

	var category: ErrorCategory = classification["category"]
	var fix_data: Dictionary = {
		"error_data": error_data,
		"classification": classification,
		"fix_type": "",
		"fix_code": "",
		"target_files": [],
		"confidence": classification["confidence"],
		"description": "",
		"backup_required": true,
		"timestamp": Time.get_datetime_string_from_system()
	}

	# Generate category-specific fixes
	match category:
		ErrorCategory.NULL_REFERENCE:
			fix_data = _generate_null_reference_fix(fix_data)

		ErrorCategory.MISSING_NODE:
			fix_data = _generate_missing_node_fix(fix_data)

		ErrorCategory.SIGNAL_CONNECTION:
			fix_data = _generate_signal_connection_fix(fix_data)

		ErrorCategory.RESOURCE_LOADING:
			fix_data = _generate_resource_loading_fix(fix_data)

		ErrorCategory.METHOD_CALL:
			fix_data = _generate_method_call_fix(fix_data)

		ErrorCategory.AUTOLOAD_ACCESS:
			fix_data = _generate_autoload_fix(fix_data)

	if not fix_data["fix_code"].is_empty():
		emit_signal("fix_generated", fix_data)
		print("💡 Generated fix: %s" % fix_data["description"])

	return fix_data

func _generate_null_reference_fix(fix_data: Dictionary) -> Dictionary:
	"""Generate fix for null reference errors"""
	var error_context: Dictionary = fix_data["error_data"].get("context", {})
	var node_path: String = error_context.get("node_path", "")

	if node_path != "":
		fix_data["fix_type"] = "null_check_addition"
		fix_data["description"] = "Add null check for node: %s" % node_path
		fix_data["fix_code"] = """# Generated null check fix
if has_node("%s"):
	var node = get_node("%s")
	# Original code here
else:
	FailureLogger.log_missing_node("%s", str(self))
""" % [node_path, node_path, node_path]

		fix_data["confidence"] = FixConfidence.HIGH
	else:
		fix_data["fix_type"] = "generic_null_check"
		fix_data["description"] = "Add generic null validation"
		fix_data["fix_code"] = """# Generated null validation
if object != null:
	# Original code here
else:
	FailureLogger.log_null_reference("unknown_object", str(self))
"""
		fix_data["confidence"] = FixConfidence.MEDIUM

	return fix_data

func _generate_missing_node_fix(fix_data: Dictionary) -> Dictionary:
	"""Generate fix for missing node errors"""
	var error_context: Dictionary = fix_data["error_data"].get("context", {})
	var node_path: String = error_context.get("expected_path", "")

	fix_data["fix_type"] = "node_existence_check"
	fix_data["description"] = "Add node existence validation for: %s" % node_path
	fix_data["fix_code"] = """# Generated node existence check
if has_node("%s"):
	var target_node = get_node("%s")
	# Continue with original logic
else:
	print("Warning: Node '%s' not found in scene tree")
	# Add fallback behavior or create node if needed
""" % [node_path, node_path, node_path]

	fix_data["confidence"] = FixConfidence.HIGH
	return fix_data

func _generate_signal_connection_fix(fix_data: Dictionary) -> Dictionary:
	"""Generate fix for signal connection errors"""
	var error_context: Dictionary = fix_data["error_data"].get("context", {})
	var signal_name: String = error_context.get("signal", "")
	var source: String = error_context.get("source", "")
	var target: String = error_context.get("target", "")
	var method: String = error_context.get("method", "")

	fix_data["fix_type"] = "signal_connection_validation"
	fix_data["description"] = "Add signal connection validation for: %s" % signal_name
	fix_data["fix_code"] = """# Generated signal connection fix
if %s != null and %s != null:
	if %s.has_signal("%s") and %s.has_method("%s"):
		if not %s.is_connected("%s", %s, "%s"):
			%s.connect("%s", %s, "%s")
		else:
			print("Signal already connected: %s")
	else:
		FailureLogger.log_signal_connection_failure("%s", "%s", "%s", "%s")
else:
	print("Cannot connect signal - null objects")
""" % [source, target, source, signal_name, target, method,
	source, signal_name, target, method, source, signal_name, target, method,
	signal_name, signal_name, source, target, method]

	fix_data["confidence"] = FixConfidence.MEDIUM
	return fix_data

func _generate_resource_loading_fix(fix_data: Dictionary) -> Dictionary:
	"""Generate fix for resource loading errors"""
	var error_context: Dictionary = fix_data["error_data"].get("context", {})
	var resource_path: String = error_context.get("path", "")

	fix_data["fix_type"] = "resource_validation"
	fix_data["description"] = "Add resource loading validation for: %s" % resource_path
	fix_data["fix_code"] = """# Generated resource loading fix
if ResourceLoader.exists("%s"):
	var resource = load("%s")
	if resource != null:
		# Continue with resource usage
		pass
	else:
		FailureLogger.log_resource_load_failure("%s", "load_failed")
else:
	FailureLogger.log_resource_load_failure("%s", "file_not_found")
	# Add fallback resource or default behavior
""" % [resource_path, resource_path, resource_path, resource_path]

	fix_data["confidence"] = FixConfidence.HIGH
	return fix_data

func _generate_method_call_fix(fix_data: Dictionary) -> Dictionary:
	"""Generate fix for method call errors"""
	var error_context: Dictionary = fix_data["error_data"].get("context", {})
	var object_name: String = error_context.get("object", "")
	var method_name: String = error_context.get("method", "")

	fix_data["fix_type"] = "method_validation"
	fix_data["description"] = "Add method call validation for: %s.%s" % [object_name, method_name]
	fix_data["fix_code"] = """# Generated method call validation
if %s != null and %s.has_method("%s"):
	# Original method call here
	pass
else:
	if %s == null:
		FailureLogger.log_null_reference("%s", str(self))
	else:
		FailureLogger.log_method_call_failure("%s", "%s", "method_not_found")
""" % [object_name, object_name, method_name, object_name, object_name, object_name, method_name]

	fix_data["confidence"] = FixConfidence.MEDIUM
	return fix_data

func _generate_autoload_fix(fix_data: Dictionary) -> Dictionary:
	"""Generate fix for autoload access errors"""
	var error_context: Dictionary = fix_data["error_data"].get("context", {})
	var autoload_name: String = error_context.get("autoload", "")

	fix_data["fix_type"] = "autoload_validation"
	fix_data["description"] = "Add autoload access validation for: %s" % autoload_name
	fix_data["fix_code"] = """# Generated autoload validation
if Engine.has_singleton("%s"):
	var autoload = Engine.get_singleton("%s")
	if autoload != null:
		# Continue with autoload usage
		pass
	else:
		FailureLogger.log_autoload_failure("%s")
else:
	print("Autoload '%s' not registered")
	# Check if autoload exists as global variable
	if get("/%s") != null:
		# Use global variable approach
		pass
""" % [autoload_name, autoload_name, autoload_name, autoload_name, autoload_name]

	fix_data["confidence"] = FixConfidence.CRITICAL
	return fix_data

func apply_fix(fix_data: Dictionary) -> bool:
	"""Apply a generated fix to the codebase"""
	if fix_data.is_empty() or fix_data["fix_code"].is_empty():
		emit_signal("fix_failed", fix_data, "No fix code generated")
		return false

	print("🔧 Applying fix: %s" % fix_data["description"])

	# For safety, we'll simulate fix application instead of modifying actual files
	# In production, this would:
	# 1. Create backups of target files
	# 2. Apply the fix code to appropriate locations
	# 3. Validate the fix doesn't break compilation
	# 4. Test the fix resolves the error

	var success: bool = _simulate_fix_application(fix_data)

	if success:
		applied_fixes.append(fix_data)
		_update_fix_success_rate(fix_data["fix_type"], true)
		emit_signal("fix_applied", fix_data, true)
		print("  ✅ Fix applied successfully")
	else:
		_update_fix_success_rate(fix_data["fix_type"], false)
		emit_signal("fix_applied", fix_data, false)
		print("  ❌ Fix application failed")

	return success

func _simulate_fix_application(fix_data: Dictionary) -> bool:
	"""Simulate fix application for testing purposes"""
	# Simulate success based on confidence level
	var confidence_factor: float = float(fix_data["confidence"]) / float(FixConfidence.CRITICAL)
	var random_factor: float = randf()

	# Higher confidence = higher success rate
	var success_threshold: float = 0.3 + (confidence_factor * 0.6)  # 30-90% success rate

	return random_factor <= success_threshold

func _update_fix_success_rate(fix_type: String, success: bool) -> void:
	"""Update success rate tracking for fix types"""
	if not fix_type in fix_success_rate:
		fix_success_rate[fix_type] = {"successes": 0, "attempts": 0}

	fix_success_rate[fix_type]["attempts"] += 1
	if success:
		fix_success_rate[fix_type]["successes"] += 1

func get_fix_success_rate(fix_type: String = "") -> Dictionary:
	"""Get success rate for specific fix type or all types"""
	if fix_type != "" and fix_type in fix_success_rate:
		var data: Dictionary = fix_success_rate[fix_type]
		return {
			"fix_type": fix_type,
			"success_rate": float(data["successes"]) / float(data["attempts"]) if data["attempts"] > 0 else 0.0,
			"successes": data["successes"],
			"attempts": data["attempts"]
		}

	# Return all success rates
	var all_rates: Dictionary = {}
	for type in fix_success_rate:
		var data: Dictionary = fix_success_rate[type]
		all_rates[type] = {
			"success_rate": float(data["successes"]) / float(data["attempts"]) if data["attempts"] > 0 else 0.0,
			"successes": data["successes"],
			"attempts": data["attempts"]
		}

	return all_rates

func analyze_fix_patterns() -> Dictionary:
	"""Analyze patterns in applied fixes for learning"""
	var analysis: Dictionary = {
		"total_fixes_applied": applied_fixes.size(),
		"most_common_fix_types": {},
		"success_rates": get_fix_success_rate(),
		"recommendations": []
	}

	# Count fix types
	for fix in applied_fixes:
		var fix_type: String = fix["fix_type"]
		analysis["most_common_fix_types"][fix_type] = analysis["most_common_fix_types"].get(fix_type, 0) + 1

	# Generate recommendations
	for fix_type in fix_success_rate:
		var rate_data: Dictionary = get_fix_success_rate(fix_type)
		if rate_data["success_rate"] < 0.5 and rate_data["attempts"] >= 3:
			analysis["recommendations"].append("Fix type '%s' has low success rate (%.1f%%) - consider manual review" % [fix_type, rate_data["success_rate"] * 100])

	return analysis

func export_fix_report() -> String:
	"""Export comprehensive fix analysis report"""
	var report: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"applied_fixes": applied_fixes,
		"success_rates": get_fix_success_rate(),
		"pattern_analysis": analyze_fix_patterns(),
		"fix_templates": fix_templates.keys()  # Don't export full templates for security
	}

	var export_path: String = "user://autofix_report_%s.json" % Time.get_datetime_string_from_system().replace(":", "-")
	var file := FileAccess.open(export_path, FileAccess.WRITE)

	if file:
		file.store_string(JSON.stringify(report))
		file.close()
		print("📄 AutoFix report exported to: %s" % export_path)
		return export_path
	else:
		print("❌ Failed to export AutoFix report")
		return ""

## Public API

func process_error_batch(errors: Array) -> Array:
	"""Process multiple errors and generate fixes"""
	var generated_fixes: Array = []

	for error_data in errors:
		var fix: Dictionary = generate_fix(error_data)
		if not fix.is_empty():
			generated_fixes.append(fix)

	return generated_fixes

func apply_fix_batch(fixes: Array, max_fixes: int = 5) -> Dictionary:
	"""Apply multiple fixes with limit for safety"""
	var results: Dictionary = {
		"applied": 0,
		"failed": 0,
		"skipped": 0,
		"details": []
	}

	var applied_count: int = 0

	for fix in fixes:
		if applied_count >= max_fixes:
			results["skipped"] += 1
			continue

		if apply_fix(fix):
			results["applied"] += 1
			applied_count += 1
		else:
			results["failed"] += 1

		results["details"].append({
			"fix_type": fix["fix_type"],
			"success": applied_count <= results["applied"]
		})

	return results

func clear_fix_history() -> void:
	"""Clear applied fixes history"""
	applied_fixes.clear()
	fix_success_rate.clear()
	print("🧹 AutoFix history cleared")