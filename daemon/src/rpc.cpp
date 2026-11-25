#include "rpc.h"

#include <array>
#include <cmath>
#include <optional>
#include <type_traits>
#include <variant>

#include "base64.h"

namespace gamepilot {

namespace {

const pa::JsonValue& require(const pa::JsonObject& params, const char* key) {
  const pa::JsonValue* value = params.get_value(key);
  if (value == nullptr) {
    throw RpcError(kInvalidParams, std::string("missing param: ") + key);
  }
  return *value;
}

std::string require_string(const pa::JsonObject& params, const char* key) {
  const std::string* value = require(params, key).to_string();
  if (value == nullptr) {
    throw RpcError(kInvalidParams,
                   std::string("param must be a string: ") + key);
  }
  return *value;
}

double require_number(const pa::JsonObject& params, const char* key) {
  const pa::JsonValue& value = require(params, key);
  if (!value.is_float()) {
    throw RpcError(kInvalidParams,
                   std::string("param must be a number: ") + key);
  }
  return value.to_double_default();
}

double optional_ms(const pa::JsonObject& params, const char* key) {
  if (params.get_value(key) == nullptr) {
    return 0;
  }
  const double ms = require_number(params, key);
  if (!(ms >= 0)) {
    throw RpcError(kInvalidParams, std::string("param must be >= 0: ") + key);
  }
  return ms;
}

const pa::JsonArray& require_array(const pa::JsonObject& params,
                                   const char* key) {
  const pa::JsonArray* value = require(params, key).to_array();
  if (value == nullptr) {
    throw RpcError(kInvalidParams,
                   std::string("param must be an array: ") + key);
  }
  return *value;
}

const pa::JsonObject& require_object(const pa::JsonValue& value,
                                     const char* what) {
  const pa::JsonObject* object = value.to_object();
  if (object == nullptr) {
    throw RpcError(kInvalidParams, std::string(what) + " must be an object");
  }
  return *object;
}

// Rounds to 1 / scale (scale 10: one decimal) so lines stay short.
double round_to(double value, double scale) {
  return std::round(value * scale) / scale;
}

// An [r, g, b] param of integers 0..255.
std::array<std::uint8_t, 3> require_rgb(const pa::JsonObject& params,
                                        const char* key) {
  const pa::JsonArray& values = require_array(params, key);
  constexpr std::int64_t kChannelMax = 255;
  std::array<std::uint8_t, 3> rgb{};
  bool ok = values.size() == rgb.size();
  for (std::size_t c = 0; ok && c < rgb.size(); c++) {
    const pa::JsonValue& value = values[c];
    const std::int64_t channel = value.to_integer_default(-1);
    ok = value.is_integer() && channel >= 0 && channel <= kChannelMax;
    rgb[c] = static_cast<std::uint8_t>(channel);
  }
  if (!ok) {
    throw RpcError(kInvalidParams,
                   std::string("param must be [r, g, b] in 0..255: ") + key);
  }
  return rgb;
}

// An optional [x, y] stick param, each a number in -1..1.
std::optional<StickPosition> optional_stick(const pa::JsonObject& params,
                                            const char* key) {
  if (params.get_value(key) == nullptr) {
    return std::nullopt;
  }
  const pa::JsonArray& values = require_array(params, key);
  bool ok = values.size() == 2;
  for (std::size_t i = 0; ok && i < values.size(); i++) {
    const double v = values[i].to_double_default(2);
    ok = values[i].is_float() && v >= -1 && v <= 1;
  }
  if (!ok) {
    throw RpcError(kInvalidParams,
                   std::string("param must be [x, y] in -1..1: ") + key);
  }
  return StickPosition{values[0].to_double_default(),
                       values[1].to_double_default()};
}

// `min` and `max`, [r, g, b] each, with min <= max per channel.
ColorRange require_color_range(const pa::JsonObject& params,
                               const std::string& probe_id) {
  const ColorRange range{require_rgb(params, "min"),
                         require_rgb(params, "max")};
  for (std::size_t c = 0; c < range.min.size(); c++) {
    if (range.min[c] > range.max[c]) {
      throw RpcError(kInvalidParams, "min must not exceed max: " + probe_id);
    }
  }
  return range;
}

// An integer param, required.
int require_int(const pa::JsonObject& params, const char* key) {
  const pa::JsonValue& value = require(params, key);
  if (!value.is_integer()) {
    throw RpcError(kInvalidParams,
                   std::string("param must be an integer: ") + key);
  }
  return static_cast<int>(value.to_integer_default(0));
}

// A number param >= 0 when present.
std::optional<double> optional_size(const pa::JsonObject& params,
                                    const char* key) {
  if (params.get_value(key) == nullptr) {
    return std::nullopt;
  }
  const double value = require_number(params, key);
  if (!(value >= 0)) {
    throw RpcError(kInvalidParams, std::string("param must be >= 0: ") + key);
  }
  return value;
}

// A [w, h] param of numbers >= 0 when present.
std::optional<std::array<double, 2>> optional_pair(const pa::JsonObject& params,
                                                   const char* key) {
  if (params.get_value(key) == nullptr) {
    return std::nullopt;
  }
  const pa::JsonArray& values = require_array(params, key);
  std::array<double, 2> pair{};
  bool ok = values.size() == pair.size();
  for (std::size_t i = 0; ok && i < pair.size(); i++) {
    ok = values[i].is_float() && values[i].to_double_default(-1) >= 0;
    pair[i] = values[i].to_double_default(0);
  }
  if (!ok) {
    throw RpcError(kInvalidParams,
                   std::string("param must be [w, h], each >= 0: ") + key);
  }
  return pair;
}

ChannelComparison::Op require_op(const pa::JsonObject& params) {
  const std::string op = require_string(params, "op");
  if (op == ">") {
    return ChannelComparison::Op::kGreater;
  }
  if (op == ">=") {
    return ChannelComparison::Op::kGreaterEqual;
  }
  if (op == "<") {
    return ChannelComparison::Op::kLess;
  }
  if (op == "<=") {
    return ChannelComparison::Op::kLessEqual;
  }
  throw RpcError(kInvalidParams, "op must be >, >=, < or <=: " + op);
}

// core.line_shares@1's `test`: one or more {weights: [r, g, b], op, value}.
PixelTest require_pixel_test(const pa::JsonObject& probe,
                             const std::string& probe_id) {
  PixelTest test;
  for (const pa::JsonValue& item : require_array(probe, "test")) {
    const pa::JsonObject& entry = require_object(item, "test");
    const pa::JsonArray& weights = require_array(entry, "weights");
    ChannelComparison comparison;
    bool ok = weights.size() == comparison.weights.size();
    for (std::size_t c = 0; ok && c < comparison.weights.size(); c++) {
      ok = weights[c].is_integer();
      comparison.weights[c] =
          static_cast<int>(weights[c].to_integer_default(0));
    }
    if (!ok) {
      throw RpcError(kInvalidParams,
                     "weights must be [r, g, b] integers: " + probe_id);
    }
    comparison.op = require_op(entry);
    comparison.value = require_int(entry, "value");
    test.push_back(comparison);
  }
  if (test.empty()) {
    throw RpcError(kInvalidParams, "test needs a comparison: " + probe_id);
  }
  return test;
}

// core.find@1's params.
FindSpec require_find(const pa::JsonObject& probe,
                      const std::string& probe_id) {
  FindSpec find;
  for (const pa::JsonValue& item : require_array(probe, "filters")) {
    find.filters.push_back(
        require_color_range(require_object(item, "filter"), probe_id));
  }
  if (find.filters.empty()) {
    throw RpcError(kInvalidParams, "filters needs a range: " + probe_id);
  }
  find.min_area = require_number(probe, "min_area");
  find.max_area = optional_size(probe, "max_area");
  if (!(find.min_area >= 1) ||
      (find.max_area && *find.max_area < find.min_area)) {
    throw RpcError(kInvalidParams,
                   "min_area must be >= 1 and <= max_area: " + probe_id);
  }
  find.min_size = optional_pair(probe, "min_size");
  find.max_size = optional_pair(probe, "max_size");
  find.margin = optional_size(probe, "margin");
  if (probe.get_value("template") != nullptr) {
    find.template_hash = require_string(probe, "template");
  }
  if (probe.get_value("shape") != nullptr) {
    find.shape_hash = require_string(probe, "shape");
  }
  if (const pa::JsonValue* masked = probe.get_value("masked")) {
    if (!masked->is_boolean()) {
      throw RpcError(kInvalidParams, "masked must be a boolean: " + probe_id);
    }
    find.masked = masked->to_boolean_default();
  }
  return find;
}

pa::JsonArray rounded_list(const std::vector<double>& values, double scale) {
  pa::JsonArray array;
  for (const double value : values) {
    array.push_back(round_to(value, scale));
  }
  return array;
}

// A blob in game pixels of the picture.
pa::JsonObject blob_json(const FindResult& found, const Blob& blob) {
  constexpr double kPixels = 1e3;
  constexpr double kShares = 1e6;
  pa::JsonObject json;
  json["filter"] = static_cast<std::int64_t>(blob.filter);
  json["x"] = round_to((blob.box.x - found.picture_x) / found.x_scale, kPixels);
  json["y"] = round_to((blob.box.y - found.picture_y) / found.y_scale, kPixels);
  json["w"] = round_to(blob.box.width / found.x_scale, kPixels);
  json["h"] = round_to(blob.box.height / found.y_scale, kPixels);
  json["fill"] =
      round_to(static_cast<double>(blob.area) / blob.box.area(), kShares);
  if (blob.stray) {
    json["stray"] = round_to(*blob.stray, kShares);
  }
  if (blob.score) {
    json["score"] = round_to(*blob.score, kPixels);
  }
  if (blob.overlap) {
    json["overlap"] = round_to(*blob.overlap, kShares);
  }
  return json;
}

pa::JsonArray triple(const std::array<double, 3>& values) {
  pa::JsonArray array;
  for (const double value : values) {
    array.push_back(round_to(value, 100));
  }
  return array;
}

}  // namespace

pa::JsonObject probe_result_json(const ProbeResult& result) {
  pa::JsonObject json;
  std::visit(
      [&json](const auto& value) {
        using T = std::decay_t<decltype(value)>;
        if constexpr (std::is_same_v<T, ColorStats>) {
          json["kind"] = std::string(kColorStatsKind);
          json["mean"] = triple(value.mean);
          json["stddev"] = triple(value.stddev);
        } else if constexpr (std::is_same_v<T, ColorCount>) {
          json["kind"] = std::string(kColorCountKind);
          json["fraction"] = round_to(value.fraction, 1e6);
          json["mean"] =
              value.mean ? pa::JsonValue(triple(*value.mean)) : pa::JsonValue();
        } else if constexpr (std::is_same_v<T, LineShares>) {
          constexpr double kShares = 1e6;
          json["kind"] = std::string(kLineSharesKind);
          json["rows"] = rounded_list(value.rows, kShares);
          json["columns"] = rounded_list(value.columns, kShares);
        } else if constexpr (std::is_same_v<T, FindResult>) {
          json["kind"] = std::string(kFindKind);
          pa::JsonArray blobs;
          for (const Blob& blob : value.blobs) {
            blobs.push_back(blob_json(value, blob));
          }
          json["blobs"] = std::move(blobs);
        } else {
          json["kind"] = std::string(kTemplateMatchKind);
          json["score"] = round_to(value.score, 1e6);
          json["x"] = round_to(value.x, 1e5);
          json["y"] = round_to(value.y, 1e5);
        }
      },
      result);
  return json;
}

pa::JsonValue parse_message(const std::string& line) {
  pa::JsonValue value = pa::parse_json(line);
  if (value.is_null()) {
    // CoreLib's parser returns null for malformed text.
    throw RpcError(kParseError, "parse error");
  }
  return value;
}

Request decode_request(const pa::JsonValue& message) {
  const pa::JsonObject* object = message.to_object();
  if (object == nullptr) {
    throw RpcError(kInvalidRequest, "request must be an object");
  }
  Request request;
  if (const pa::JsonValue* id = object->get_value("id")) {
    request.id = id->clone();
    request.has_id = true;
  }
  const std::string* version = object->get_string("jsonrpc");
  const std::string* method = object->get_string("method");
  if (version == nullptr || *version != "2.0" || method == nullptr) {
    throw RpcError(kInvalidRequest, "invalid request");
  }
  request.method = *method;
  if (const pa::JsonValue* params = object->get_value("params")) {
    const pa::JsonObject* params_object = params->to_object();
    if (params_object == nullptr) {
      throw RpcError(kInvalidParams, "params must be an object");
    }
    request.params = params_object->clone();
  }
  return request;
}

HelloParams decode_hello(const pa::JsonObject& params) {
  HelloParams hello;
  const pa::JsonValue& protocol = require(params, "protocol");
  if (!protocol.is_integer()) {
    throw RpcError(kInvalidParams, "param must be an integer: protocol");
  }
  hello.protocol = protocol.to_integer_default();
  hello.client = require_string(params, "client");
  return hello;
}

LoadStateParams decode_load_state(const pa::JsonObject& params) {
  return LoadStateParams{require_string(params, "path")};
}

SaveParams decode_save(const pa::JsonObject& params) {
  return SaveParams{require_string(params, "path")};
}

UploadTemplateParams decode_upload_template(const pa::JsonObject& params) {
  std::optional<std::string> png = decode_base64(require_string(params, "png"));
  if (!png) {
    throw RpcError(kInvalidParams, "png must be padded base64");
  }
  return UploadTemplateParams{std::move(*png)};
}

SubscribeParams decode_subscribe(const pa::JsonObject& params) {
  SubscribeParams subscribe;
  for (const pa::JsonValue& item : require_array(params, "probes")) {
    const pa::JsonObject& probe = require_object(item, "probe");
    ProbeSpec spec;
    spec.id = require_string(probe, "id");
    spec.kind = require_string(probe, "kind");
    const pa::JsonObject& box = require_object(require(probe, "box"), "box");
    spec.box = Box{require_number(box, "x"), require_number(box, "y"),
                   require_number(box, "w"), require_number(box, "h")};
    if (!is_unit_box(spec.box)) {
      throw RpcError(kInvalidParams,
                     "box must lie in 0..1 with w, h > 0: " + spec.id);
    }
    spec.delivery = require_string(probe, "delivery");
    if (spec.delivery != "every" && spec.delivery != "latest") {
      throw RpcError(kInvalidParams,
                     "delivery must be every or latest: " + spec.id);
    }
    const bool has_template = probe.get_value("template") != nullptr ||
                              probe.get_value("ink") != nullptr;
    if (spec.kind == kTemplateMatchKind) {
      spec.template_hash = require_string(probe, "template");
      if (const pa::JsonValue* ink = probe.get_value("ink")) {
        spec.ink = require_color_range(require_object(*ink, "ink"), spec.id);
      }
    } else if (spec.kind == kFindKind) {
      if (probe.get_value("ink") != nullptr) {
        throw RpcError(kInvalidParams,
                       "ink is only for core.template_match@1: " + spec.id);
      }
      spec.find = require_find(probe, spec.id);
    } else if (has_template) {
      throw RpcError(kInvalidParams,
                     "template and ink are only for core.template_match@1 "
                     "(template also for core.find@1): " +
                         spec.id);
    }
    if (spec.kind == kLineSharesKind) {
      spec.pixel_test = require_pixel_test(probe, spec.id);
    } else if (probe.get_value("test") != nullptr) {
      throw RpcError(kInvalidParams,
                     "test is only for core.line_shares@1: " + spec.id);
    }
    const bool has_range =
        probe.get_value("min") != nullptr || probe.get_value("max") != nullptr;
    if (spec.kind == kColorCountKind) {
      spec.color_range = require_color_range(probe, spec.id);
    } else if (has_range) {
      throw RpcError(kInvalidParams,
                     "min and max are only for core.color_count@1: " + spec.id);
    }
    subscribe.probes.push_back(std::move(spec));
  }
  return subscribe;
}

UnsubscribeParams decode_unsubscribe(const pa::JsonObject& params) {
  UnsubscribeParams unsubscribe;
  for (const pa::JsonValue& item : require_array(params, "ids")) {
    const std::string* id = item.to_string();
    if (id == nullptr) {
      throw RpcError(kInvalidParams, "ids must be strings");
    }
    unsubscribe.ids.push_back(*id);
  }
  return unsubscribe;
}

namespace {

// The buttons by KeyMask bit (backend.h).
constexpr std::array<const char*, 16> kButtons = {
    "A", "B", "Select", "Start", "Right", "Left", "Up", "Down",
    "R", "L", "Home",   "X",     "Y",     "ZL",   "ZR", "LClick"};

}  // namespace

KeyMask button_mask(const std::string& name) {
  for (std::size_t bit = 0; bit < kButtons.size(); bit++) {
    if (name == kButtons[bit]) {
      return static_cast<KeyMask>(1u << bit);
    }
  }
  return 0;
}

RpcError switch_button_refusal(const std::string& backend, KeyMask mask) {
  std::string button;
  for (std::size_t bit = 0; bit < kButtons.size(); bit++) {
    if ((mask & kSwitchOnlyKeys & (1u << bit)) != 0) {
      button = kButtons[bit];
      break;
    }
  }
  pa::JsonObject data;
  data["backend"] = backend;
  data["button"] = button;
  return RpcError(kInvalidParams,
                  button + " is a Switch button: the " + backend +
                      " backend has no " + button,
                  std::move(data));
}

RpcError switch_stick_refusal(const std::string& backend,
                              const std::string& stick) {
  pa::JsonObject data;
  data["backend"] = backend;
  data["stick"] = stick;
  return RpcError(
      kInvalidParams,
      stick + " is a Switch stick: the " + backend + " backend has no sticks",
      std::move(data));
}

SubmitParams decode_submit(const pa::JsonObject& params) {
  SubmitParams submit;
  submit.batch_id = require_string(params, "batch_id");
  for (const pa::JsonValue& item : require_array(params, "commands")) {
    const pa::JsonObject& command = require_object(item, "command");
    InputCommand input;
    if (command.get_value("press") != nullptr) {
      for (const pa::JsonValue& button : require_array(command, "press")) {
        const std::string* name = button.to_string();
        const KeyMask bit = name == nullptr ? KeyMask{0} : button_mask(*name);
        if (bit == 0) {
          throw RpcError(kInvalidParams, "unknown button in press");
        }
        input.buttons = static_cast<KeyMask>(input.buttons | bit);
      }
      input.left_stick = optional_stick(command, "left_stick");
      input.right_stick = optional_stick(command, "right_stick");
      input.hold_ms = optional_ms(command, "hold_ms");
      input.cooldown_ms = optional_ms(command, "cooldown_ms");
    } else if (command.get_value("wait_ms") != nullptr) {
      input.is_wait = true;
      input.wait_ms = optional_ms(command, "wait_ms");
    } else {
      throw RpcError(kInvalidParams, "command needs press or wait_ms");
    }
    submit.commands.push_back(input);
  }
  return submit;
}

CancelParams decode_cancel(const pa::JsonObject& params) {
  CancelParams cancel;
  if (params.get_value("then") != nullptr) {
    cancel.then =
        decode_submit(require_object(*params.get_value("then"), "then"));
  }
  return cancel;
}

LeaseAcquireParams decode_lease_acquire(const pa::JsonObject& params) {
  LeaseAcquireParams lease;
  lease.owner = require_string(params, "owner");
  if (lease.owner.empty()) {
    throw RpcError(kInvalidParams, "owner must not be empty");
  }
  if (params.get_value("ttl_ms") != nullptr) {
    lease.ttl_ms = require_number(params, "ttl_ms");
    if (!(lease.ttl_ms > 0)) {
      throw RpcError(kInvalidParams, "ttl_ms must be positive");
    }
  }
  return lease;
}

pa::JsonValue result_message(const pa::JsonValue& id, pa::JsonObject result) {
  pa::JsonObject message;
  message["jsonrpc"] = "2.0";
  message["id"] = id.clone();
  message["result"] = std::move(result);
  return message;
}

pa::JsonValue error_message(const pa::JsonValue& id, const RpcError& error) {
  pa::JsonObject body;
  body["code"] = static_cast<std::int64_t>(error.code());
  body["message"] = std::string(error.what());
  if (!error.data().is_null()) {
    body["data"] = error.data().clone();
  }
  pa::JsonObject message;
  message["jsonrpc"] = "2.0";
  message["id"] = id.clone();
  message["error"] = std::move(body);
  return message;
}

pa::JsonObject hello_result(const BackendInfo& backend) {
  pa::JsonObject info;
  info["kind"] = backend.kind;
  info["game_code"] = backend.game_code;
  info["frame_rate"] = backend.frame_rate;
  info["width"] = static_cast<std::int64_t>(backend.width);
  info["height"] = static_cast<std::int64_t>(backend.height);
  const Box& picture = backend.viewport.picture;
  pa::JsonObject viewport;
  viewport["x"] = picture.x;
  viewport["y"] = picture.y;
  viewport["w"] = picture.w;
  viewport["h"] = picture.h;
  info["viewport"] = std::move(viewport);
  pa::JsonObject game_size;
  game_size["width"] = static_cast<std::int64_t>(backend.viewport.game_width);
  game_size["height"] = static_cast<std::int64_t>(backend.viewport.game_height);
  info["game_size"] = std::move(game_size);
  pa::JsonArray kinds;
  for (const std::string& kind : probe_kinds()) {
    kinds.push_back(kind);
  }
  pa::JsonObject result;
  result["protocol"] = kProtocolVersion;
  result["daemon"] = kDaemonName;
  result["backend"] = std::move(info);
  result["probe_kinds"] = std::move(kinds);
  return result;
}

pa::JsonObject load_state_result(std::int64_t seq, std::int64_t load) {
  pa::JsonObject result;
  result["seq"] = seq;
  result["load"] = load;
  return result;
}

pa::JsonObject save_result(std::int64_t seq) {
  pa::JsonObject result;
  result["seq"] = seq;
  return result;
}

pa::JsonObject upload_template_result(const std::string& hash) {
  pa::JsonObject result;
  result["template"] = hash;
  return result;
}

pa::JsonObject subscribe_result(const std::vector<std::string>& ids) {
  pa::JsonArray list;
  for (const std::string& id : ids) {
    list.push_back(id);
  }
  pa::JsonObject result;
  result["subscribed"] = std::move(list);
  return result;
}

pa::JsonObject unsubscribe_result(const std::vector<std::string>& ids) {
  pa::JsonArray list;
  for (const std::string& id : ids) {
    list.push_back(id);
  }
  pa::JsonObject result;
  result["unsubscribed"] = std::move(list);
  return result;
}

pa::JsonObject submit_result(const std::string& batch_id,
                             std::int64_t start_seq) {
  pa::JsonObject result;
  result["batch_id"] = batch_id;
  result["start_seq"] = start_seq;
  return result;
}

pa::JsonObject cancel_result(std::int64_t released_seq) {
  pa::JsonObject result;
  result["released_seq"] = released_seq;
  return result;
}

pa::JsonObject probe_results_json(
    const std::vector<std::pair<std::string, ProbeResult>>& results) {
  pa::JsonObject probes;
  for (const auto& [id, result] : results) {
    probes[id] = probe_result_json(result);
  }
  return probes;
}

pa::JsonValue frame_notification(std::int64_t seq, std::int64_t load,
                                 double t_ms, pa::JsonObject probes) {
  pa::JsonObject params;
  params["seq"] = seq;
  params["load"] = load;
  params["t_ms"] = round_to(t_ms, 10);
  params["probes"] = std::move(probes);
  pa::JsonObject message;
  message["jsonrpc"] = "2.0";
  message["method"] = "frame";
  message["params"] = std::move(params);
  return message;
}

pa::JsonObject status_result(const DaemonStatus& status) {
  pa::JsonObject result;
  result["t_ms"] = round_to(status.t_ms, 10);
  result["backend"] = status.backend;
  if (status.client) {
    result["client"] = *status.client;
  } else {
    result["client"] = pa::JsonValue();
  }
  result["clients"] = status.clients;
  if (status.lease) {
    result["lease"] = lease_json(*status.lease, status.t_ms);
  } else {
    result["lease"] = pa::JsonValue();
  }
  result["fidelity"] = status.fidelity;
  pa::JsonArray threads;
  for (const ThreadBeat& beat : status.health.threads) {
    pa::JsonObject thread;
    thread["name"] = beat.name;
    thread["seq"] = beat.seq;
    thread["t_ms"] = round_to(beat.t_ms, 10);
    threads.push_back(std::move(thread));
  }
  result["threads"] = std::move(threads);
  pa::JsonObject ring;
  ring["depth"] = static_cast<std::int64_t>(status.health.ring_depth);
  ring["capacity"] = static_cast<std::int64_t>(status.health.ring_capacity);
  result["ring"] = std::move(ring);
  pa::JsonObject gaps;
  gaps["count"] = status.health.gaps;
  gaps["frames"] = status.health.gap_frames;
  result["gaps"] = std::move(gaps);
  return result;
}

pa::JsonObject lease_json(const LeaseHolder& holder, double now_ms) {
  pa::JsonObject lease;
  lease["owner"] = holder.owner;
  lease["client"] = holder.client;
  lease["held_ms"] = static_cast<std::int64_t>(now_ms - holder.since_ms);
  lease["ttl_ms"] = static_cast<std::int64_t>(holder.ttl_ms);
  return lease;
}

pa::JsonObject lease_acquire_result(const LeaseHolder& holder, double now_ms) {
  pa::JsonObject result;
  result["lease"] = lease_json(holder, now_ms);
  return result;
}

pa::JsonObject lease_release_result(bool released) {
  pa::JsonObject result;
  result["released"] = released;
  return result;
}

RpcError lease_refusal(const LeaseHolder& holder, double now_ms) {
  return RpcError(kLeaseHeld, "input lease held by " + holder.owner,
                  lease_json(holder, now_ms));
}

RpcError view_only_refusal(const std::string& backend,
                           const std::string& method) {
  pa::JsonObject data;
  data["backend"] = backend;
  data["method"] = method;
  return RpcError(kBackendError,
                  "the " + backend + " backend is view-only: it takes no input",
                  std::move(data));
}

pa::JsonValue batch_done_notification(const std::string& batch_id,
                                      std::int64_t seq, double t_ms) {
  pa::JsonObject params;
  params["batch_id"] = batch_id;
  params["seq"] = seq;
  params["t_ms"] = round_to(t_ms, 10);
  pa::JsonObject message;
  message["jsonrpc"] = "2.0";
  message["method"] = "batch_done";
  message["params"] = std::move(params);
  return message;
}

pa::JsonValue stop_notification(const std::string& reason) {
  pa::JsonObject params;
  params["reason"] = reason;
  pa::JsonObject message;
  message["jsonrpc"] = "2.0";
  message["method"] = "stop";
  message["params"] = std::move(params);
  return message;
}

pa::JsonValue keepawake_notification(const std::string& key, double idle_ms) {
  pa::JsonObject params;
  params["key"] = key;
  params["idle_ms"] = static_cast<std::int64_t>(idle_ms);
  pa::JsonObject message;
  message["jsonrpc"] = "2.0";
  message["method"] = "keepawake";
  message["params"] = std::move(params);
  return message;
}

pa::JsonValue wire_log_line(const char* dir, double t_ms, pa::JsonValue msg,
                            std::optional<int> conn,
                            const std::optional<std::string>& owner) {
  pa::JsonObject line;
  line["dir"] = dir;
  line["t_ms"] = round_to(t_ms, 10);
  if (conn) {
    line["conn"] = static_cast<std::int64_t>(*conn);
  }
  if (owner) {
    line["owner"] = *owner;
  }
  line["msg"] = std::move(msg);
  return line;
}

std::string to_line(const pa::JsonValue& value) { return value.dump(-1); }

}  // namespace gamepilot
