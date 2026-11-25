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
// GBA keys use, Home, X and Y, and both sticks (encode_joystick() in
// NintendoSwitch_PABotBase2_OemController.h, with the JoystickTools.h helpers
// it calls). Left out: the gyro (always off, so the C++ also sends the
// buttons-only report) and the rumble.

#pragma once

#include <array>
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
// Switch-only keys (kSwitchOnlyKeys) as Home, X, Y, ZL and ZR.
// Opposite arrows cancel: the C++'s D-pad is one position, which cannot hold
// both.
ProButtons pro_buttons_for_keys(KeyMask keys);

// pro_buttons_for_keys() with the sticks tilted: execute_state()'s report.
ProButtons pro_buttons_for_state(KeyMask keys, const Sticks& sticks);

// A stick's three report bytes, as the Pro Controller's
// encode_joystick<1874, 320>() packs them: two 12-bit axes, 2048 centred, +y
// up. A tilt inside the unit circle is scaled onto 1874..320 off centre (where
// the console starts to register it, and where it is at full); one on or
// beyond it is pushed out to the square's edge.
std::array<std::uint8_t, 3> pro_stick_bytes(StickPosition position);

// The 12-bit axes of a stick's report bytes, for reading a report back.
struct StickAxes {
  std::uint16_t x = 0;
  std::uint16_t y = 0;
};
StickAxes pro_stick_axes(const std::uint8_t (&bytes)[3]);

// One buttons command: hold `buttons` for `milliseconds` (issue_report()'s
// request, before the command queue numbers it).
ProButtonsMessage pro_buttons_message(const ProButtons& buttons,
                                      std::uint16_t milliseconds);

}  // namespace gamepilot
