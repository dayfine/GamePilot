// The Switch's controller states: a wired controller as the PABotBase2 board
// takes it, in CoreLib's own message (Common/PABotBase2/Controllers/
// PABotBase2_Controller_NS_WiredController.h). BoardSession sends them.

#pragma once

#include <cstdint>

#include "Common/ControllerStates/NintendoSwitch_WiredController_State.h"
#include "Common/PABotBase2/Controllers/PABotBase2_Controller_NS_WiredController.h"
#include "backend.h"

namespace gamepilot {

namespace pa = PokemonAutomation;

using WiredState = ::pabb_NintendoSwitch_WiredController_State;
using WiredStateMessage =
    pa::PABotBase2::pabb2_Message_Command_NS_WiredController_State;

// Nothing pressed, sticks centred (the C++'s NEUTRAL_STATE in
// Common/ControllerStates/NintendoSwitch_WiredController_State.c, which CoreLib
// does not compile).
WiredState neutral_wired_state();

// The wired controller state for GBA keys as the Switch's GBA app reads them:
// A, B, L, R as themselves, Start as Plus, Select as Minus, the arrows as the
// D-pad. Opposite arrows cancel, as in the C++'s execute_state()
// (NintendoSwitch_PABotBase2_WiredController.cpp).
WiredState wired_state_for_keys(KeyMask keys);

// One state command: hold `state` for `milliseconds` (the device runs queued
// commands back to back). `id` is the command queue's sequence number.
WiredStateMessage wired_state_message(const WiredState& state,
                                      std::uint16_t milliseconds,
                                      std::uint8_t id);

}  // namespace gamepilot
