class_name DebugLogger
extends RefCounted

static var log_buffer: Array[String] = []
static var max_buffer_size: int = 50
static var on_log_callback: Callable

static func error(func_name: String, message: String, context: Dictionary = {}) -> String:
    var ctx_str = ""
    if not context.is_empty():
        ctx_str = " | Context: %s" % JSON.stringify(context)
    var formatted = "[ERROR] [%s] %s%s" % [func_name, message, ctx_str]
    printerr(formatted)
    _record_log(formatted)
    return formatted

static func warn(func_name: String, message: String, context: Dictionary = {}) -> String:
    var ctx_str = ""
    if not context.is_empty():
        ctx_str = " | Context: %s" % JSON.stringify(context)
    var formatted = "[WARN] [%s] %s%s" % [func_name, message, ctx_str]
    print(formatted)
    _record_log(formatted)
    return formatted

static func info(func_name: String, message: String, context: Dictionary = {}) -> String:
    var ctx_str = ""
    if not context.is_empty():
        ctx_str = " | Context: %s" % JSON.stringify(context)
    var formatted = "[INFO] [%s] %s%s" % [func_name, message, ctx_str]
    print(formatted)
    _record_log(formatted)
    return formatted


static func _record_log(entry: String) -> void:
    log_buffer.append(entry)
    if log_buffer.size() > max_buffer_size:
        log_buffer.pop_front()
    if on_log_callback.is_valid():
        on_log_callback.call(entry)

static func get_all_logs_text() -> String:
    return "\n".join(log_buffer)

static func copy_to_clipboard() -> bool:
    var text = get_all_logs_text()
    if text.is_empty():
        return false
    DisplayServer.clipboard_set(text)
    return true
