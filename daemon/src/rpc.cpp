#include "rpc.h"

#include <array>
#include <cmath>

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

pa::JsonArray triple(const std::array<double, 3>& values) {
  pa::JsonArray array;
  for (const double value : values) {
    array.push_back(round_to(value, 100));
  }
  return array;
}

}  // namespace

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
    const Box& b = spec.box;
    if (!(b.x >= 0 && b.y >= 0 && b.w > 0 && b.h > 0 &&
          b.x + b.w <= 1.0 + 1e-9 && b.y + b.h <= 1.0 + 1e-9)) {
      throw RpcError(kInvalidParams,
                     "box must lie in 0..1 with w, h > 0: " + spec.id);
    }
    spec.delivery = require_string(probe, "delivery");
    if (spec.delivery != "every" && spec.delivery != "latest") {
      throw RpcError(kInvalidParams,
                     "delivery must be every or latest: " + spec.id);
    }
    subscribe.probes.push_back(std::move(spec));
  }
  return subscribe;
}

KeyMask button_mask(const std::string& name) {
  static constexpr std::array<const char*, 10> kButtons = {
      "A", "B", "Select", "Start", "Right", "Left", "Up", "Down", "R", "L"};
  for (std::size_t bit = 0; bit < kButtons.size(); bit++) {
    if (name == kButtons[bit]) {
      return static_cast<KeyMask>(1u << bit);
    }
  }
  return 0;
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

CancelParams decode_cancel(const pa::JsonObject&) { return CancelParams{}; }

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

pa::JsonObject load_state_result(std::int64_t seq) {
  pa::JsonObject result;
  result["seq"] = seq;
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

pa::JsonValue frame_notification(
    std::int64_t seq, double t_ms,
    const std::vector<std::pair<std::string, ColorStats>>& results) {
  pa::JsonObject probes;
  for (const auto& [id, stats] : results) {
    pa::JsonObject result;
    result["mean"] = triple(stats.mean);
    result["stddev"] = triple(stats.stddev);
    probes[id] = std::move(result);
  }
  pa::JsonObject params;
  params["seq"] = seq;
  params["t_ms"] = round_to(t_ms, 10);
  params["probes"] = std::move(probes);
  pa::JsonObject message;
  message["jsonrpc"] = "2.0";
  message["method"] = "frame";
  message["params"] = std::move(params);
  return message;
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

pa::JsonValue wire_log_line(const char* dir, double t_ms, pa::JsonValue msg) {
  pa::JsonObject line;
  line["dir"] = dir;
  line["t_ms"] = round_to(t_ms, 10);
  line["msg"] = std::move(msg);
  return line;
}

std::string to_line(const pa::JsonValue& value) { return value.dump(-1); }

}  // namespace gamepilot
