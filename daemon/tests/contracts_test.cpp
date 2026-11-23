// Every contracts/v1 golden file parses with the daemon's JSON layer; requests
// decode into the daemon's structs; the daemon's encoders reproduce the golden
// results and notifications.

#include <map>
#include <string>

#include "Common/Cpp/Filesystem/FileIO.h"
#include "Common/Cpp/Filesystem/Filesystem.h"
#include "check.h"
#include "rpc.h"

namespace pa = PokemonAutomation;
using namespace gamepilot;

namespace {

std::map<std::string, pa::JsonValue> load_contracts() {
  std::map<std::string, pa::JsonValue> files;
  const pa::Filesystem::Path dir(GAMEPILOT_CONTRACTS_DIR);
  for (const auto& path : pa::Filesystem::list_directory(dir)) {
    const std::string name = path.filename().string();
    if (!name.ends_with(".json")) {
      continue;
    }
    const std::string text = pa::file_to_string(path.string());
    // One message per line: a golden file is one line (plus its final LF).
    const auto newline = text.find('\n');
    CHECK(newline == std::string::npos || newline + 1 == text.size());
    try {
      files.emplace(name, parse_message(text));
    } catch (const RpcError&) {
      std::fprintf(stderr, "does not parse: %s\n", name.c_str());
      CHECK(false);
    }
  }
  return files;
}

pa::JsonObject result_of(const pa::JsonValue& message) {
  return message.to_object()->get_object_throw("result").clone();
}

void check_requests(const std::map<std::string, pa::JsonValue>& files) {
  const Request hello = decode_request(files.at("01-hello.request.json"));
  CHECK(hello.method == "hello" && hello.has_id);
  CHECK(decode_hello(hello.params).protocol == 1);
  CHECK(decode_hello(hello.params).client == "gamepilot-programs/0.1");

  const Request load = decode_request(files.at("03-load_state.request.json"));
  CHECK(load.method == "backend.load_state");
  CHECK(decode_load_state(load.params).path.ends_with("overworld.ss"));

  const Request subscribe =
      decode_request(files.at("05-subscribe.request.json"));
  const SubscribeParams probes = decode_subscribe(subscribe.params);
  CHECK(probes.probes.size() == 1);
  CHECK(probes.probes[0].id == "menu_panel");
  CHECK(probes.probes[0].kind == kColorStatsKind);
  CHECK(probes.probes[0].box.x == 0.7 && probes.probes[0].box.h == 0.5);
  CHECK(probes.probes[0].delivery == "every");

  const Request submit = decode_request(files.at("08-submit.request.json"));
  const SubmitParams batch = decode_submit(submit.params);
  CHECK(batch.batch_id == "b1");
  CHECK(batch.commands.size() == 2);
  CHECK(batch.commands[0].buttons == button_mask("Start"));
  CHECK(batch.commands[0].hold_ms == 100 &&
        batch.commands[0].cooldown_ms == 100);
  CHECK(batch.commands[1].is_wait && batch.commands[1].wait_ms == 250);

  const Request cancel = decode_request(files.at("12-cancel.request.json"));
  CHECK(cancel.method == "cancel");
  decode_cancel(cancel.params);
}

void check_encoders(const std::map<std::string, pa::JsonValue>& files) {
  const BackendInfo mgba{"mgba", "BPRE", 59.7275, 240, 160};
  CHECK(hello_result(mgba) == result_of(files.at("02-hello.response.json")));
  CHECK(load_state_result(1200) ==
        result_of(files.at("04-load_state.response.json")));
  CHECK(subscribe_result({"menu_panel"}) ==
        result_of(files.at("06-subscribe.response.json")));
  CHECK(submit_result("b1", 1203) ==
        result_of(files.at("09-submit.response.json")));
  CHECK(cancel_result(1240) == result_of(files.at("13-cancel.response.json")));

  CHECK(result_message(pa::JsonValue(std::int64_t{4}),
                       submit_result("b1", 1203)) ==
        files.at("09-submit.response.json"));

  const ColorStats stats{{248.1, 248.0, 247.9}, {6.2, 6.1, 6.3}};
  const pa::JsonValue frame =
      frame_notification(1201, 20113.6, {{"menu_panel", stats}});
  CHECK(frame == files.at("07-frame.notification.json"));
  CHECK(batch_done_notification("b1", 1230, 20599.0) ==
        files.at("10-batch_done.notification.json"));

  pa::JsonObject data;
  data["kind"] = "core.ocr@1";
  const RpcError unknown(kUnknownProbeKind, "unknown probe kind",
                         std::move(data));
  CHECK(error_message(pa::JsonValue(std::int64_t{5}), unknown) ==
        files.at("11-error.unknown_kind.response.json"));

  CHECK(wire_log_line("out", 20113.7, frame.clone()) ==
        files.at("14-wire_log.line.json"));
  // The wire log line round-trips through the daemon's one-line encoding.
  CHECK(parse_message(to_line(files.at("14-wire_log.line.json"))) ==
        files.at("14-wire_log.line.json"));
}

void check_errors() {
  bool threw = false;
  try {
    parse_message("{not json");
  } catch (const RpcError& error) {
    threw = error.code() == kParseError;
  }
  CHECK(threw);

  threw = false;
  try {
    decode_request(
        parse_message(R"({"jsonrpc":"1.0","id":1,"method":"hello"})"));
  } catch (const RpcError& error) {
    threw = error.code() == kInvalidRequest;
  }
  CHECK(threw);

  threw = false;
  try {
    decode_submit(
        parse_message(
            R"({"batch_id":"x","commands":[{"press":["Z"],"hold_ms":10}]})")
            .to_object_throw());
  } catch (const RpcError& error) {
    threw = error.code() == kInvalidParams;
  }
  CHECK(threw);
}

}  // namespace

int main() {
  const auto files = load_contracts();
  CHECK(files.size() == 14);
  if (files.size() == 14) {
    check_requests(files);
    check_encoders(files);
  }
  check_errors();
  return TEST_RESULT();
}
