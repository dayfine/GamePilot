// Who holds the input lease after a sequence of acts: one case per rule, each
// a name, the input (the acts, in order) and the expectation (the holder, and
// which acts were refused).

#include "input_lease.h"

#include <cstdio>
#include <optional>
#include <string>
#include <vector>

#include "check.h"

using namespace gamepilot;

namespace {

enum class Act { kAcquire, kInput, kRelease, kExpire };

struct Step {
  Act act = Act::kInput;
  int connection = 1;
  double now_ms = 0;
  std::string owner = {};  // kAcquire
  double ttl_ms = 1000;     // kAcquire
  bool busy = false;        // kExpire: the holder's batches are pending
};

struct Input {
  std::vector<Step> steps;
};

struct Expectation {
  std::optional<int> holder;  // its connection; none = free
  std::string owner = {};
  double since_ms = 0;
  // Per step: refused (acquire, input) or did nothing (release).
  std::vector<bool> refused;
};

struct Case {
  std::string name;
  Input input;
  Expectation expect;
};

const std::vector<Case> kCases = {
    {"the first input takes the free lease, owned by the hello name",
     {{{.act = Act::kInput, .connection = 1, .now_ms = 5}}},
     {.holder = 1, .owner = "client-1", .since_ms = 5, .refused = {false}}},
    {"another connection's input is refused while it is held",
     {{{.act = Act::kInput, .connection = 1},
       {.act = Act::kInput, .connection = 2, .now_ms = 10}}},
     {.holder = 1, .owner = "client-1", .refused = {false, true}}},
    {"an explicit acquire names the owner",
     {{{.act = Act::kAcquire, .connection = 2, .owner = "ctl:difan"}}},
     {.holder = 2, .owner = "ctl:difan", .refused = {false}}},
    {"an acquire is refused while another holds it",
     {{{.act = Act::kInput, .connection = 1},
       {.act = Act::kAcquire, .connection = 2, .owner = "pad"}}},
     {.holder = 1, .owner = "client-1", .refused = {false, true}}},
    {"the holder's acquire renews it and keeps its start",
     {{{.act = Act::kInput, .connection = 1, .now_ms = 3},
       {.act = Act::kAcquire, .connection = 1, .now_ms = 9, .owner = "mine"}}},
     {.holder = 1, .owner = "mine", .since_ms = 3, .refused = {false, false}}},
    {"release frees it for the next client",
     {{{.act = Act::kInput, .connection = 1},
       {.act = Act::kRelease, .connection = 1},
       {.act = Act::kInput, .connection = 2, .now_ms = 7}}},
     {.holder = 2, .owner = "client-2", .since_ms = 7,
      .refused = {false, false, false}}},
    {"only the holder can release it",
     {{{.act = Act::kInput, .connection = 1},
       {.act = Act::kRelease, .connection = 2}}},
     {.holder = 1, .owner = "client-1", .refused = {false, true}}},
    {"no input for the ttl: it ends",
     {{{.act = Act::kAcquire, .connection = 1, .ttl_ms = 1000},
       {.act = Act::kExpire, .now_ms = 1000}}},
     {.holder = std::nullopt, .refused = {false, false}}},
    {"input renews the ttl",
     {{{.act = Act::kAcquire, .connection = 1, .ttl_ms = 1000},
       {.act = Act::kInput, .connection = 1, .now_ms = 800},
       {.act = Act::kExpire, .now_ms = 1500}}},
     {.holder = 1, .refused = {false, false, false}}},
    {"a batch still running counts as input",
     {{{.act = Act::kAcquire, .connection = 1, .ttl_ms = 1000},
       {.act = Act::kExpire, .now_ms = 5000, .busy = true},
       {.act = Act::kExpire, .now_ms = 5999}}},
     {.holder = 1, .refused = {false, false, false}}},
    {"an implicit lease lasts the default ttl",
     {{{.act = Act::kInput, .connection = 1},
       {.act = Act::kExpire, .now_ms = kDefaultLeaseTtlMs - 1},
       {.act = Act::kExpire, .now_ms = kDefaultLeaseTtlMs}}},
     {.holder = std::nullopt, .refused = {false, false, false}}},
    {"after expiry another client takes it",
     {{{.act = Act::kAcquire, .connection = 1, .ttl_ms = 1000},
       {.act = Act::kExpire, .now_ms = 2000},
       {.act = Act::kInput, .connection = 2, .now_ms = 2000}}},
     {.holder = 2, .refused = {false, false, false}}},
};

// Runs one step; true if it was refused (or a release did nothing).
bool run_step(InputLease& lease, const Step& step) {
  const std::string client = "client-" + std::to_string(step.connection);
  switch (step.act) {
    case Act::kAcquire:
      return lease
          .acquire(step.connection, step.owner, client, step.ttl_ms,
                   step.now_ms)
          .has_value();
    case Act::kInput:
      return lease.input(step.connection, client, step.now_ms).has_value();
    case Act::kRelease:
      return !lease.release(step.connection);
    case Act::kExpire:
      lease.expire(step.now_ms, step.busy);
      return false;
  }
  return false;
}

void check_cases() {
  for (const Case& c : kCases) {
    InputLease lease;
    std::vector<bool> refused;
    for (const Step& step : c.input.steps) {
      refused.push_back(run_step(lease, step));
    }
    const auto& holder = lease.holder();
    const std::optional<int> connection =
        holder ? std::optional<int>(holder->connection) : std::nullopt;
    bool ok = connection == c.expect.holder && refused == c.expect.refused;
    if (holder && !c.expect.owner.empty()) {
      ok = ok && holder->owner == c.expect.owner &&
           holder->since_ms == c.expect.since_ms;
    }
    if (!ok) {
      std::fprintf(stderr, "case \"%s\": holder %d (%s)\n", c.name.c_str(),
                   connection.value_or(0),
                   holder ? holder->owner.c_str() : "free");
    }
    CHECK(ok);
  }
}

void check_unnamed_connection() {
  InputLease lease;
  CHECK(!lease.input(4, "", 0));
  CHECK(lease.holder() && lease.holder()->owner == "connection 4");
}

}  // namespace

int main() {
  check_cases();
  check_unnamed_connection();
  return TEST_RESULT();
}
