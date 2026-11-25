// A started session with FakeSwitch's board, in NS1 Wired Pro Controller mode,
// for tests that need a controller but not the board itself.

#pragma once

#include "board_session.h"
#include "fake_switch.h"

namespace gamepilot::test {

struct FakeConsole {
  explicit FakeConsole(const Clock& clock) : board(clock), session(board, log) {
    session.start();
  }

  FakeSwitch board;
  BoardLog log{/*quiet=*/true};
  BoardSession session;
};

}  // namespace gamepilot::test
