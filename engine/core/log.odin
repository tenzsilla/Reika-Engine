package core

import "core:fmt"
import "core:os"

Log_Level :: enum u8 {
	Debug,
	Info,
	Warn,
	Error,
}

// Debug builds default to .Debug while release builds default to .Info
@(private)
g_log_level: Log_Level = .Debug

log_set_level :: proc(level: Log_Level) {
	g_log_level = level
}

log_debug :: proc(fmt_str: string, args: ..any) {
	if g_log_level <= .Debug {
		_log_write(.Debug, fmt_str, ..args)
	}
}

log_info :: proc(fmt_str: string, args: ..any) {
	if g_log_level <= .Info {
		_log_write(.Info, fmt_str, ..args)
	}
}

log_warn :: proc(fmt_str: string, args: ..any) {
	if g_log_level <= .Warn {
		_log_write(.Warn, fmt_str, ..args)
	}
}

log_error :: proc(fmt_str: string, args: ..any) {
	if g_log_level <= .Error {
		_log_write(.Error, fmt_str, ..args)
	}
}

@(private)
_log_write :: proc(level: Log_Level, fmt_str: string, args: ..any) {
	prefix: string
	handle := os.stdout

	switch level {
	case .Debug:
		prefix = "[DEBUG] "
	case .Info:
		prefix = "[INFO] "
	case .Warn:
		prefix = "[WARN] "
		handle = os.stderr
	case .Error:
		prefix = "[ERROR] "
		handle = os.stderr
	}

	msg := fmt.tprintf(fmt_str, ..args)
	fmt.fprintln(handle, "%s %s", prefix, msg)
}
