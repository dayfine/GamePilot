# GamePilot

Layered game automation. A small Qt-free C++ daemon owns the console (capture card, controller
board via PABotBase2, mGBA, or recorded frames) and serves probe measurements over JSON-RPC; game
programs are written in OCaml and run unchanged against the console, a replay, or a simulation.

Status: Week 0. See `docs/design/Layered-Automation-Stack.md`.

    git clone --recurse-submodules https://github.com/dayfine/GamePilot
