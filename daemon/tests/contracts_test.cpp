// Every protocol/v1 golden file parses with the daemon's JSON layer; requests
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
#include "sent_results.h"
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

  const Request save_state =
      decode_request(files.at("24-save_state.request.json"));
  CHECK(save_state.method == "backend.save_state");
  CHECK(decode_save(save_state.params).path.ends_with("mg-02.start.ss"));
  const Request save_frame =
      decode_request(files.at("26-save_frame.request.json"));
  CHECK(save_frame.method == "backend.save_frame");
  CHECK(decode_save(save_frame.params).path.ends_with("failure.png"));

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
  CHECK(cursor.probes.size() == 2);
  CHECK(cursor.probes[0].kind == kTemplateMatchKind);
  CHECK(cursor.probes[0].delivery == "latest");
  CHECK(cursor.probes[0].template_hash ==
        *result_of(files.at("16-upload_template.response.json"))
             .get_string("template"));
  CHECK(!cursor.probes[0].ink);
  CHECK(cursor.probes[1].ink &&
        cursor.probes[1].ink->max ==
            (std::array<std::uint8_t, 3>{144, 144, 255}));

  const Request unsubscribe =
      decode_request(files.at("21-unsubscribe.request.json"));
  CHECK(unsubscribe.method == "unsubscribe");
  CHECK(decode_unsubscribe(unsubscribe.params).ids ==
        (std::vector<std::string>{"bag.1/TM CASE", "gone"}));

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

  const SubscribeParams shares_and_blobs = decode_subscribe(
      decode_request(files.at("46-subscribe.line_shares_find.request.json"))
          .params);
  CHECK(shares_and_blobs.probes.size() == 3);
  const ProbeSpec& glyph = shares_and_blobs.probes[0];
  CHECK(glyph.kind == kLineSharesKind && glyph.pixel_test.size() == 3);
  CHECK(glyph.pixel_test[2].weights == (std::array<int, 3>{-1, 0, 1}) &&
        glyph.pixel_test[2].op == ChannelComparison::Op::kGreater &&
        glyph.pixel_test[2].value == 60);
  const ProbeSpec& chevron = shares_and_blobs.probes[1];
  CHECK(chevron.kind == kFindKind && chevron.find);
  if (chevron.find) {
    CHECK(chevron.find->filters.size() == 2);
    CHECK(chevron.find->filters[0].min ==
          (std::array<std::uint8_t, 3>{235, 235, 220}));
    CHECK(chevron.find->min_area == 1 && !chevron.find->max_area);
    CHECK(chevron.find->min_size == (std::array<double, 2>{26, 15}));
    CHECK(chevron.find->max_size == (std::array<double, 2>{40, 24}));
    CHECK(chevron.find->margin == 4.0);
    CHECK(chevron.find->template_hash.empty() &&
          chevron.find->shape_hash.size() == 64);
  }
  const ProbeSpec& choice = shares_and_blobs.probes[2];
  CHECK(choice.find && choice.find->max_area == 5000.0 &&
        choice.find->template_hash.size() == 64 &&
        choice.find->shape_hash.empty() && !choice.find->margin);
  CHECK(!chevron.find || !chevron.find->masked);

  // v1.15: a find scored with the pixels outside its filter black.
  const SubscribeParams masked = decode_subscribe(
      decode_request(files.at("49-subscribe.find_masked.request.json")).params);
  CHECK(masked.probes.size() == 1 && masked.probes[0].find &&
        masked.probes[0].find->masked &&
        masked.probes[0].find->template_hash.size() == 64);

  const Request submit = decode_request(files.at("08-submit.request.json"));
  const SubmitParams batch = decode_submit(submit.params);
  CHECK(batch.batch_id == "b1");
  CHECK(batch.commands.size() == 2);
  CHECK(batch.commands[0].buttons == button_mask("Start"));
  CHECK(batch.commands[0].hold_ms == 100 &&
        batch.commands[0].cooldown_ms == 100);
  CHECK(batch.commands[1].is_wait && batch.commands[1].wait_ms == 250);

  // The Switch's Home, and its refusal by a backend without it.
  const SubmitParams home = decode_submit(
      decode_request(files.at("42-submit.home.request.json")).params);
  CHECK(home.commands.size() == 1 &&
        home.commands[0].buttons == button_mask("Home") &&
        (home.commands[0].buttons & kSwitchOnlyKeys) != 0);
  CHECK((button_mask("X") | button_mask("Y") | button_mask("ZL") |
         button_mask("ZR") | button_mask("Plus") | button_mask("Minus") |
         button_mask("LStick")) == (kSwitchOnlyKeys & ~button_mask("Home")));
  CHECK((button_mask("L") & kSwitchOnlyKeys) == 0);
  // v1.17: the Switch's own Plus and Minus, Switch-only like Home.
  const SubmitParams skip = decode_submit(
      decode_request(files.at("51-submit.plus.request.json")).params);
  CHECK(skip.commands.size() == 2 &&
        skip.commands[0].buttons == button_mask("Plus") &&
        skip.commands[1].buttons == button_mask("Minus"));
  // v1.18: the left stick's click, the Switch keyboard's Shift.
  const SubmitParams shift = decode_submit(
      decode_request(files.at("52-submit.lstick.request.json")).params);
  CHECK(shift.commands.size() == 2 &&
        shift.commands[0].buttons == button_mask("LStick") &&
        (shift.commands[0].buttons & kSwitchOnlyKeys) != 0 &&
        shift.commands[1].buttons == button_mask("A"));
  // v1.16: ZL then ZL with ZR, PLZA's ball throw.
  const SubmitParams aim = decode_submit(
      decode_request(files.at("50-submit.zl_zr.request.json")).params);
  CHECK(aim.commands.size() == 2 &&
        aim.commands[0].buttons == button_mask("ZL") &&
        aim.commands[1].buttons == (button_mask("ZL") | button_mask("ZR")) &&
        aim.commands[1].cooldown_ms == 8000);
  CHECK(error_message(pa::JsonValue(std::int64_t{42}),
                      switch_button_refusal("mgba", button_mask("Home"))) ==
        files.at("43-error.switch_button.response.json"));

  // A run: B with the left stick, chained by cooldown 0; then the right stick
  // alone. A stick left out is not set; its refusal by mGBA names it.
  const SubmitParams run = decode_submit(
      decode_request(files.at("44-submit.sticks.request.json")).params);
  CHECK(run.commands.size() == 3);
  if (run.commands.size() == 3) {
    const InputCommand& ahead = run.commands[0];
    CHECK(ahead.buttons == button_mask("B") && ahead.hold_ms == 1200 &&
          ahead.cooldown_ms == 0);
    CHECK(ahead.left_stick.has_value() && ahead.left_stick->x == 0 &&
          ahead.left_stick->y == 1 && !ahead.right_stick.has_value());
    CHECK(run.commands[1].left_stick.has_value() &&
          run.commands[1].left_stick->x == 0.5 &&
          run.commands[1].left_stick->y == 0.866);
    const InputCommand& look = run.commands[2];
    CHECK(look.buttons == 0 && !look.left_stick.has_value() &&
          look.right_stick.has_value() && look.right_stick->x == -1 &&
          look.right_stick->y == 0 && look.cooldown_ms == 100);
  }
  CHECK(error_message(pa::JsonValue(std::int64_t{44}),
                      switch_stick_refusal("mgba", "left_stick")) ==
        files.at("45-error.switch_stick.response.json"));

  const Request cancel = decode_request(files.at("12-cancel.request.json"));
  CHECK(cancel.method == "cancel");
  CHECK(!decode_cancel(cancel.params).then);
  const Request then = decode_request(files.at("48-cancel.then.request.json"));
  const CancelParams replaced = decode_cancel(then.params);
  CHECK(replaced.then && replaced.then->batch_id == "move" &&
        replaced.then->commands.size() == 2 &&
        replaced.then->commands[0].buttons ==
            (button_mask("ZL") | button_mask("X")));

  const Request status = decode_request(files.at("28-status.request.json"));
  CHECK(status.method == "status" && status.has_id);

  const Request acquire =
      decode_request(files.at("35-lease_acquire.request.json"));
  CHECK(acquire.method == "lease.acquire");
  const LeaseAcquireParams lease = decode_lease_acquire(acquire.params);
  CHECK(lease.owner == "ctl:bring-up" && lease.ttl_ms == 30000);
  const Request release =
      decode_request(files.at("37-lease_release.request.json"));
  CHECK(release.method == "lease.release");
}

// The lease's results and refusal reproduce the goldens; status shows the
// holder.
void check_lease(const std::map<std::string, pa::JsonValue>& files) {
  const LeaseHolder holder{2, "ctl:bring-up", "gamepilot-ctl/0.1",
                           1000,  1000,         30000};
  CHECK(lease_acquire_result(holder, 1000) ==
        result_of(files.at("36-lease_acquire.response.json")));
  CHECK(lease_release_result(true) ==
        result_of(files.at("38-lease_release.response.json")));
  CHECK(error_message(pa::JsonValue(std::int64_t{16}),
                      lease_refusal(holder, 5200)) ==
        files.at("39-error.lease_held.response.json"));
  // A view-only backend's refusal.
  CHECK(error_message(pa::JsonValue(std::int64_t{3}),
                      view_only_refusal("view", "submit")) ==
        files.at("41-error.view_only.response.json"));
  pa::JsonObject no_ttl;
  no_ttl["owner"] = "pad";
  CHECK(decode_lease_acquire(no_ttl).ttl_ms == kDefaultLeaseTtlMs);
  for (const double ttl : {0.0, -5.0}) {
    pa::JsonObject bad;
    bad["owner"] = "pad";
    bad["ttl_ms"] = ttl;
    bool threw = false;
    try {
      decode_lease_acquire(bad);
    } catch (const RpcError& error) {
      threw = error.code() == kInvalidParams;
    }
    CHECK(threw);
  }
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
  const BackendInfo mgba{.kind = "mgba",
                         .game_code = "BPRE",
                         .frame_rate = 59.7275,
                         .width = 240,
                         .height = 160,
                         .viewport = Viewport{Box{0, 0, 1, 1}, 240, 160},
                         .timing = Timing::kLockstep,
                         .takes_input = true};
  CHECK(hello_result(mgba) == result_of(files.at("02-hello.response.json")));
  CHECK(load_state_result(1200, 1) ==
        result_of(files.at("04-load_state.response.json")));
  CHECK(save_result(5400) ==
        result_of(files.at("25-save_state.response.json")));
  CHECK(save_result(5460) ==
        result_of(files.at("27-save_frame.response.json")));
  CHECK(subscribe_result({"menu_panel"}) ==
        result_of(files.at("06-subscribe.response.json")));
  CHECK(submit_result("b1", 1203) ==
        result_of(files.at("09-submit.response.json")));
  CHECK(cancel_result(1240) == result_of(files.at("13-cancel.response.json")));

  DaemonStatus status;
  status.t_ms = 60012.5;
  status.backend = "switch";
  status.client = "gamepilot-programs/0.1";
  status.clients = 2;
  status.lease = LeaseHolder{1,   "gamepilot-programs/0.1",
                             "gamepilot-programs/0.1", 212.5, 212.5, 60000};
  status.fidelity = "latest";
  status.health.threads = {ThreadBeat{"capture", 3601, 60010.2},
                           ThreadBeat{"server", 3599, 60011.9}};
  status.health.ring_depth = 2;
  status.health.ring_capacity = 8;
  status.health.gaps = 1;
  status.health.gap_frames = 3;
  CHECK(status_result(status) ==
        result_of(files.at("29-status.response.json")));
  status.client.reset();
  CHECK(status_result(status).get_value("client")->is_null());
  status.lease.reset();
  CHECK(status_result(status).get_value("lease")->is_null());

  CHECK(result_message(pa::JsonValue(std::int64_t{4}),
                       submit_result("b1", 1203)) ==
        files.at("09-submit.response.json"));

  CHECK(stop_notification("stopped by user") ==
        files.at("32-stop.notification.json"));
  // The program's watch notes are notifications the daemon passes to the page.
  for (const char* name :
       {"30-watch_plan.notification.json", "31-watch_log.notification.json",
        "33-watch_run.notification.json"}) {
    const Request note = decode_request(files.at(name));
    CHECK(!note.has_id && note.method.starts_with("watch."));
  }

  const ColorStats stats{{248.1, 248.0, 247.9}, {6.2, 6.1, 6.3}};
  const pa::JsonValue frame = frame_notification(
      1201, 1, 20113.6, probe_results_json({{"menu_panel", stats}}));
  CHECK(frame == files.at("07-frame.notification.json"));
  const ProbeResult cursor = TemplateMatch{0.000412, 0.75, 0.0625};
  const ProbeResult word = TemplateMatch{0.021875, 0.39167, 0.06875};
  CHECK(frame_notification(1260, 1, 21101.4,
                           probe_results_json({{"cursor", cursor},
                                               {"bag.1/TM CASE", word}})) ==
        files.at("18-frame.template_match.notification.json"));
  CHECK(result_message(pa::JsonValue(std::int64_t{10}),
                       unsubscribe_result({"bag.1/TM CASE"})) ==
        files.at("22-unsubscribe.response.json"));
  const ProbeResult no_arrow = ColorCount{0.0, std::nullopt};
  const ProbeResult arrow =
      ColorCount{0.013333, std::array<double, 3>{224.0, 48.5, 40.25}};
  CHECK(frame_notification(1302, 1, 21804.7,
                           probe_results_json({{"arrow_line1", no_arrow},
                                               {"arrow_line2", arrow}})) ==
        files.at("20-frame.color_count.notification.json"));
  FindResult chevron;
  Blob blob;
  blob.filter = 1;
  blob.box = cv::Rect(1418, 982, 32, 20);
  blob.area = 230;  // 0.359375 of 32 x 20
  blob.stray = 0.0;
  blob.overlap = 0.585443;
  chevron.blobs.push_back(blob);
  const ProbeResult glyph = LineShares{
      {3.0 / 8, 4.0 / 8, 2.0 / 8, 2.0 / 8, 4.0 / 8, 3.0 / 8, 2.0 / 8},
      {1.0 / 7, 3.0 / 7, 4.0 / 7, 3.0 / 7, 2.0 / 7, 3.0 / 7, 3.0 / 7,
       1.0 / 7}};
  CHECK(frame_notification(
            5120, 0, 85337.2,
            probe_results_json({{"controls_hint.glyph", glyph},
                                {"advance_arrow", chevron},
                                {"choice_arrow", FindResult{}}})) ==
        files.at("47-frame.line_shares_find.notification.json"));
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
  // The keep-awake press, the daemon's own line.
  CHECK(wire_log_line("daemon", 180412.5,
                      keepawake_notification("B", 180000)) ==
        files.at("34-keepawake.line.json"));
  // An input line names its connection and the lease owner.
  const pa::JsonValue& input_line =
      files.at("40-wire_log.input_owner.line.json");
  CHECK(wire_log_line("in", 30512.4,
                      input_line.to_object()->get_value_throw("msg").clone(),
                      2, std::string("ctl:bring-up")) == input_line);
}

// The first frame sends every result; a later one only the results that
// changed; a forgotten probe is sent again.
void check_changed_results(const std::map<std::string, pa::JsonValue>& files) {
  const ProbeResult word = TemplateMatch{0.021875, 0.39167, 0.06875};
  const ProbeResult cursor_up = TemplateMatch{0.000412, 0.75, 0.0625};
  const ProbeResult cursor_down = TemplateMatch{0.000412, 0.75, 0.125};
  SentResults sent;
  CHECK(frame_notification(1260, 1, 21101.4,
                           sent.take_changed({{"cursor", cursor_up},
                                              {"bag.1/TM CASE", word}})) ==
        files.at("18-frame.template_match.notification.json"));
  CHECK(frame_notification(1261, 1, 21118.1,
                           sent.take_changed({{"cursor", cursor_down},
                                              {"bag.1/TM CASE", word}})) ==
        files.at("23-frame.changed_only.notification.json"));
  CHECK(sent.take_changed({{"cursor", cursor_down}, {"bag.1/TM CASE", word}})
            .empty());
  sent.forget("bag.1/TM CASE");
  CHECK(sent.take_changed({{"cursor", cursor_down}, {"bag.1/TM CASE", word}})
            .size() == 1);
  sent.forget_all();
  CHECK(sent.take_changed({{"cursor", cursor_down}, {"bag.1/TM CASE", word}})
            .size() == 2);
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
  const std::string shares =
      std::string(R"({"id":"p","kind":"core.line_shares@1",)") + kBox;
  CHECK(subscribe_error((shares + "}").c_str()));  // a test is required
  CHECK(subscribe_error((shares + R"(,"test":[]})").c_str()));  // not empty
  CHECK(subscribe_error(
      (shares + R"(,"test":[{"weights":[1,0],"op":">","value":1}]})")
          .c_str()));  // three weights
  CHECK(subscribe_error(
      (shares + R"(,"test":[{"weights":[1,0,0],"op":"=","value":1}]})")
          .c_str()));  // > >= < <= only
  CHECK(subscribe_error(
      (shares + R"(,"test":[{"weights":[1,0,0],"op":">","value":1.5}]})")
          .c_str()));  // integers
  CHECK(subscribe_error(
      (std::string(R"({"id":"p","kind":"core.color_stats@1",)") + kBox +
       R"(,"test":[{"weights":[1,0,0],"op":">","value":1}]})")
          .c_str()));  // a test only for line shares
  const std::string find =
      std::string(R"({"id":"p","kind":"core.find@1",)") + kBox;
  const std::string filter = R"(,"filters":[{"min":[0,0,0],"max":[9,9,9]}])";
  CHECK(subscribe_error((find + filter + "}").c_str()));  // min_area needed
  CHECK(subscribe_error(
      (find + R"(,"filters":[],"min_area":1})").c_str()));  // a filter
  CHECK(subscribe_error((find + filter + R"(,"min_area":0})").c_str()));
  CHECK(subscribe_error(
      (find + filter + R"(,"min_area":5,"max_area":4})").c_str()));
  CHECK(subscribe_error(
      (find + filter + R"(,"min_area":1,"min_size":[1]})").c_str()));
  CHECK(subscribe_error(
      (find + filter + R"(,"min_area":1,"margin":-1})").c_str()));
  CHECK(subscribe_error(
      (find + filter + R"(,"min_area":1,"ink":{"min":[0,0,0],"max":[1,1,1]}})")
          .c_str()));  // ink only for template_match
  CHECK(subscribe_error(
      (std::string(R"({"id":"p","kind":"core.template_match@1",)") + kBox +
       R"(,"template":"t","ink":{"min":[9,0,0],"max":[8,0,0]}})")
          .c_str()));  // ink min above max
  CHECK(subscribe_error(
      (std::string(R"({"id":"p","kind":"core.color_stats@1",)") + kBox +
       R"(,"ink":{"min":[0,0,0],"max":[1,1,1]}})")
          .c_str()));  // ink only for template matches

  // A stick is [x, y], each a number in -1..1.
  const auto stick_error = [](const char* stick) {
    try {
      decode_submit(
          parse_message(
              std::string(
                  R"({"batch_id":"b","commands":[{"press":[],"left_stick":)") +
              stick + R"(,"hold_ms":1}]})")
              .to_object_throw());
    } catch (const RpcError& error) {
      return error.code() == kInvalidParams;
    }
    return false;
  };
  CHECK(stick_error("[1.5,0]"));
  CHECK(stick_error("[0,-1.01]"));
  CHECK(stick_error("[0]"));
  CHECK(stick_error("[0,0,0]"));
  CHECK(stick_error(R"(["up",0])"));
  CHECK(!stick_error("[-1,1]"));

  threw = false;
  try {
    decode_unsubscribe(parse_message(R"({"ids":[1]})").to_object_throw());
  } catch (const RpcError& error) {
    threw = error.code() == kInvalidParams;
  }
  CHECK(threw);

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
  // One per protocol/v1 golden file. The checks below index files by name,
  // so they run only when every one is there.
  constexpr std::size_t kGoldenFiles = 52;
  CHECK(files.size() == kGoldenFiles);
  if (files.size() == kGoldenFiles) {
    check_requests(files);
    check_lease(files);
    check_upload(files);
    check_encoders(files);
    check_changed_results(files);
  }
  check_errors();
  return TEST_RESULT();
}
