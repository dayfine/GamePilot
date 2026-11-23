// Every contracts/v1 golden file parses with the daemon's JSON layer; requests
// decode into the daemon's structs; the daemon's encoders reproduce the golden
// results and notifications.

#include <array>
#include <cstdint>
#include <map>
#include <optional>
#include <string>

#include "Common/Cpp/Filesystem/FileIO.h"
#include "Common/Cpp/Filesystem/Filesystem.h"
#include "check.h"
#include "rpc.h"
#include "template_store.h"

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

  const Request templated =
      decode_request(files.at("17-subscribe.template_match.request.json"));
  const SubscribeParams cursor = decode_subscribe(templated.params);
  CHECK(cursor.probes.size() == 1);
  CHECK(cursor.probes[0].kind == kTemplateMatchKind);
  CHECK(cursor.probes[0].delivery == "latest");
  CHECK(cursor.probes[0].template_hash ==
        *result_of(files.at("16-upload_template.response.json"))
             .get_string("template"));

  const Request counted =
      decode_request(files.at("19-subscribe.color_count.request.json"));
  const SubscribeParams arrow = decode_subscribe(counted.params);
  CHECK(arrow.probes.size() == 2);
  CHECK(arrow.probes[0].kind == kColorCountKind);
  CHECK(arrow.probes[1].box.y == 0.84375);
  CHECK(arrow.probes[1].color_range.min ==
        (std::array<std::uint8_t, 3>{160, 0, 0}));
  CHECK(arrow.probes[1].color_range.max ==
        (std::array<std::uint8_t, 3>{255, 120, 120}));

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

// The golden upload decodes to a 3x2 PNG whose hash is the golden response's.
void check_upload(const std::map<std::string, pa::JsonValue>& files) {
  const Request upload =
      decode_request(files.at("15-upload_template.request.json"));
  CHECK(upload.method == "probe.upload_template");
  TemplateStore store;
  const auto hash = store.add_png(decode_upload_template(upload.params).png);
  CHECK(hash.has_value());
  if (!hash) {
    return;
  }
  CHECK(result_message(pa::JsonValue(std::int64_t{7}),
                       upload_template_result(*hash)) ==
        files.at("16-upload_template.response.json"));
  const cv::Mat* image = store.find(*hash);
  CHECK(image != nullptr && image->cols == 3 && image->rows == 2);
  if (image != nullptr) {
    // Top-right pixel is pure red: BGR (0, 0, 255).
    CHECK(image->at<cv::Vec3b>(0, 2) == cv::Vec3b(0, 0, 255));
  }
  CHECK(store.add_png(decode_upload_template(upload.params).png) == hash);
}

void check_encoders(const std::map<std::string, pa::JsonValue>& files) {
  const BackendInfo mgba{"mgba", "BPRE", 59.7275,
                         240,    160,    Viewport{Box{0, 0, 1, 1}, 240, 160}};
  CHECK(hello_result(mgba) == result_of(files.at("02-hello.response.json")));
  CHECK(load_state_result(1200, 1) ==
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
      frame_notification(1201, 1, 20113.6, {{"menu_panel", stats}});
  CHECK(frame == files.at("07-frame.notification.json"));
  const ProbeResult cursor = TemplateMatch{0.000412, 0.75, 0.0625};
  CHECK(frame_notification(1260, 1, 21101.4, {{"cursor", cursor}}) ==
        files.at("18-frame.template_match.notification.json"));
  const ProbeResult no_arrow = ColorCount{0.0, std::nullopt};
  const ProbeResult arrow =
      ColorCount{0.013333, std::array<double, 3>{224.0, 48.5, 40.25}};
  CHECK(
      frame_notification(1302, 1, 21804.7,
                         {{"arrow_line1", no_arrow}, {"arrow_line2", arrow}}) ==
      files.at("20-frame.color_count.notification.json"));
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

  threw = false;
  try {
    decode_subscribe(
        parse_message(
            R"({"probes":[{"id":"p","kind":"core.template_match@1","delivery":"every","box":{"x":0,"y":0,"w":1,"h":1}}]})")
            .to_object_throw());
  } catch (const RpcError& error) {
    threw = error.code() == kInvalidParams;
  }
  CHECK(threw);  // a template match needs its template

  const auto subscribe_error = [](const char* probe) {
    try {
      decode_subscribe(
          parse_message(std::string(R"({"probes":[)") + probe + "]}")
              .to_object_throw());
    } catch (const RpcError& error) {
      return error.code() == kInvalidParams;
    }
    return false;
  };
  const char* const kBox =
      R"("box":{"x":0,"y":0,"w":1,"h":1},"delivery":"every")";
  CHECK(subscribe_error(
      (std::string(R"({"id":"p","kind":"core.color_count@1",)") + kBox +
       R"(,"min":[0,0,0]})")
          .c_str()));  // a color count needs both ends
  CHECK(subscribe_error(
      (std::string(R"({"id":"p","kind":"core.color_count@1",)") + kBox +
       R"(,"min":[0,0,0],"max":[0,256,0]})")
          .c_str()));  // channels are 0..255
  CHECK(subscribe_error(
      (std::string(R"({"id":"p","kind":"core.color_count@1",)") + kBox +
       R"(,"min":[9,0,0],"max":[8,0,0]})")
          .c_str()));  // min above max
  CHECK(subscribe_error(
      (std::string(R"({"id":"p","kind":"core.color_stats@1",)") + kBox +
       R"(,"min":[0,0,0],"max":[1,1,1]})")
          .c_str()));  // a range only for color counts

  threw = false;
  try {
    decode_upload_template(
        parse_message(R"({"png":"not base64"})").to_object_throw());
  } catch (const RpcError& error) {
    threw = error.code() == kInvalidParams;
  }
  CHECK(threw);
}

}  // namespace

int main() {
  const auto files = load_contracts();
  CHECK(files.size() == 20);
  if (files.size() == 20) {
    check_requests(files);
    check_upload(files);
    check_encoders(files);
  }
  check_errors();
  return TEST_RESULT();
}
