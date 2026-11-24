// The Switch's controller states: a Nintendo Switch 1 Pro Controller as the
// PABotBase2 board takes it in its NS1 Wired Pro Controller mode, the mode the
// lab app drives console B's board in. The message is CoreLib's own
// (Common/PABotBase2/Controllers/PABotBase2_Controller_NS1_OemController.h);
// BoardSession sends it.
//
// Ported from the fork's PABotBase2_ProController::execute_state()
// (SerialPrograms/Source/NintendoSwitch/Controllers/PABotBase2/
// NintendoSwitch_PABotBase2_ProController.h) and
// PABotBase2_OemController::populate_report_buttons() and issue_report()
// (NintendoSwitch_PABotBase2_OemController.cpp), for the buttons and D-pad the
// GBA keys use, and Home, X and Y. Left out: the sticks (always centred), the
// gyro (always off, so the C++ also sends the buttons-only report) and the
// rumble.

#pragma once

#include <cstdint>

#include "Common/ControllerStates/NintendoSwitch_OemController_State.h"
#include "Common/PABotBase2/Controllers/PABotBase2_Controller_NS1_OemController.h"
#include "backend.h"

namespace gamepilot {

namespace pa = PokemonAutomation;

using ProButtons = pa::NintendoSwitch::OemController_State0x30_Buttons;
using ProButtonsMessage =
    pa::PABotBase2::Message_Command_NS1_OemController_Buttons;

// Nothing pressed, sticks centred: the report execute_state() starts from.
ProButtons neutral_pro_buttons();

// The Pro Controller report for GBA keys as the Switch's GBA app reads them:
// A, B, L, R as themselves, Start as Plus, Select as Minus, the arrows as the
// D-pad (populate_report_buttons() and execute_state()'s split D-pad); the
// Switch-only keys (kSwitchOnlyKeys) as Home, X and Y.
// Opposite arrows cancel: the C++'s D-pad is one position, which cannot hold
// both.
ProButtons pro_buttons_for_keys(KeyMask keys);

// One buttons command: hold `buttons` for `milliseconds` (issue_report()'s
// request, before the command queue numbers it).
ProButtonsMessage pro_buttons_message(const ProButtons& buttons,
                                      std::uint16_t milliseconds);

}  // namespace gamepilot
