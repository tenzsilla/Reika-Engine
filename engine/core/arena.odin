package core

import "core:fmt"
import "core:mem"
import "core:os"

// Arena
//
// A linear allocator backed by a single OS allocation made at init.
// All memory is bumped forward and there is no per allocation free
// Reset moves the offset back to zero

Arena :: struct {
	data:   []byte,
	offset: int,

	// Debug tracking
	debug:  Arena_Debug,
}

Arena_Debug :: struct {
	label:       string,
	peak_bytes:  int,
	alloc_count: int,
	entries:     []Arena_Debug_Entry, // nil in release
	entry_count: int,
}

Arena_Debug_Entry :: struct {
	label: string,
	size:  int,
	loc:   Source_Location,
}

// Source_Location mirrors runtime.Source_Code_Location (for portability)
Source_Location :: struct {
	file:      string,
	line:      i32,
	column:    i32,
	procedure: string,
}

// Max number of individual allocation entries tracked per arena in debug
ARENA_DEBUG_MAX_ENTRIES :: 1024

// Init / Destroy

// arena_init allocates `size` bytes from the os and prepares the arena
arena_init :: proc(a: ^Arena, size: int, label: string = "") -> bool {
	raw := make([]byte, size)
	if raw == nil {
		log_error("arena_init: OS allocation failed for '%s' (%d bytes)", label, size)
		return false
	}

	a.data = raw
	a.offset = 0
	a.debug = {}

	when ODIN_DEBUG {
		a.debug.label = label
		a.debug.entries = make([]Arena_Debug_Entry, ARENA_DEBUG_MAX_ENTRIES)
	}

	return true
}

arena_destroy :: proc(a: ^Arena) {
	when ODIN_DEBUG {
		if a.debug.entries != nil {
			delete(a.debug.entries)
			a.debug.entries = nil
		}
	}
	if a.data != nil {
		delete(a.data)
		a.data = nil
	}
	a.offset = 0
}

// Allocation

// arena_alloc bumps the offset forward by `size` bytes (aligned to `align`)
arena_alloc :: proc(
	a: ^Arena,
	size: int,
	align: int = 16,
	label: string = "",
	loc: Source_Location = {},
) -> rawptr {
	aligned_offset := mem.align_forward_int(a.offset, align)
	end := aligned_offset + size

	if end > len(a.data) {
		when ODIN_DEBUG {
			log_error(
				"arena_alloc: out of memory in '%s' (requested %d, used %d / %d)",
				a.debug.label,
				size,
				a.offset,
				len(a.data),
			)
		} else {
			log_error(
				"arena_alloc: out of memory (requested %d, used %d / %d)",
				size,
				a.offset,
				len(a.data),
			)
		}
		return nil
	}

	ptr := &a.data[aligned_offset]
	a.offset = end

	when ODIN_DEBUG {
		if a.offset > a.debug.peak_bytes {
			a.debug.peak_bytes = a.offset
		}
		a.debug.alloc_count += 1

		if a.debug.entry_count < ARENA_DEBUG_MAX_ENTRIES {
			a.debug.entries[a.debug.entry_count] = Arena_Debug_Entry {
				label = label,
				size  = size,
				loc   = loc,
			}
			a.debug.entry_count += 1
		}
	}

	return ptr
}

// arena_push is a typed wrapper over arena_alloc
arena_push :: proc(a: ^Arena, $T: typeid, label: string = "", loc: Source_Location = {}) -> ^T {
	ptr := arena_alloc(a, size_of(T), align_of(T), label, loc)
	if ptr == nil do return nil
	result := cast(^T)ptr
	result^ = {}
	return result
}

// arena_push_slice allocates a contiguous slice of `count` elements of type T
arena_push_slice :: proc(
	a: ^Arena,
	$T: typeid,
	count: int,
	label: string = "",
	loc: Source_Location = {},
) -> []T {
	if count <= 0 do return nil
	ptr := arena_alloc(a, size_of(T) * count, align_of(T), label, loc)
	if ptr == nil do return nil
	s := transmute([]T)mem.Raw_Slice{ptr, count}
	mem.zero_slice(s)
	return s
}

// Reset

// arena_reset resets the bump pointer to zero
arena_reset :: proc(a: ^Arena) {
	a.offset = 0

	when ODIN_DEBUG {
		a.debug.alloc_count = 0
		a.debug.entry_count = 0
		// peak_bytes is preserved across resets
	}
}

// Debug

// arena_debug_print logs a summary of the arena's current state
arena_debug_print :: proc(a: ^Arena) {
	when ODIN_DEBUG {
		used_kb := f32(a.offset) / 1024.0
		total_kb := f32(len(a.data)) / 1024.0
		peak_kb := f32(a.debug.peak_bytes) / 1024.0

		log_debug(
			"Arena '%s': %.1f / %.1f KB used (peak %.1f KB), %d allocs",
			a.debug.label,
			used_kb,
			total_kb,
			peak_kb,
			a.debug.alloc_count,
		)

		for i in 0 ..< a.debug.entry_count {
			e := a.debug.entries[i]
			if e.label != "" {
				log_debug(
					"  [%d] %s — %d bytes (%s:%d)",
					i,
					e.label,
					e.size,
					e.loc.file,
					e.loc.line,
				)
			}
		}
	}
}

// arena_bytes_used returns the current offset (bytes consumed)
arena_bytes_used :: proc(a: ^Arena) -> int {return a.offset}

// arena_bytes_remaining returns how many bytes are still available
arena_bytes_remaining :: proc(a: ^Arena) -> int {return len(a.data) - a.offset}
