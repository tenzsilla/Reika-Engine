# Reika Engine
Reika is a high-performance, open-source PS1-style 3D game engine. It is developed using the Odin programming language along with the Raylib graphics library.

## Premature Checklist
The following is the list of layers to be implemented in-order.
- [x] Core package/loop + window
- [x] Memory Management
- [x] Math Package (RMath)
- [x] ECS (Entity Component System)
- [x] Basic Renderer
- [x] Camera System
- [ ] Profiler (bound to F1) <- we're here
- [ ] Material Service
- [ ] Asset Pipeline
- [ ] PS1 Style Renderer
- [ ] Scene/world Management
- [ ] Lua Scripting
- [ ] Polish Systems (Animation, Physics...)
- [ ] Tooling

## ⚠️ — Disclaimer
This game engine is extremely premature. I personally have only tested it on my system (a Ubuntu-based distro), so build instructions for your system may be missing.

Furthermore, you need the **Odin programming language** installed on your system and linked to PATH. Otherwise, the project will simply not build. Here is the official Odin installing guide:
https://odin-lang.org/docs/install/

## Build Instructions
Once you've cloned the repository, execute the following commands from root to build:

### Linux
```sh
# Debug build
odin build . -debug
# Or
# Release build
odin build . -o:speed

# Run executable
./Reika
```

