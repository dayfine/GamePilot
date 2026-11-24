// The server's side of the watch page (watch_server.h): what it shows from the
// frame loop (the frame, the probes, the health), the program's plan and log
// notes, and Stop. Everything here runs on the server loop's thread and only
// while a page is connected, except the notes, which are kept for the next one.

#include <cstdio>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#include <vector>

#include "server.h"

namespace gamepilot {

namespace {

// The page's frame and probes refresh at most this often (5 per second).
constexpr double kWatchFrameMs = 200;
// The health panel's refresh.
constexpr double kWatchStatusMs = 1000;
// Frames wider than this are scaled down before encoding (a 1080p capture
// goes to 640x360) and sent as JPEG.
constexpr int kWatchFrameWidth = 640;
constexpr int kWatchJpegQuality = 85;
// Frames this wide or less (the GBA's 240x160) are sent as they are, as PNG:
// pixel art blurs in JPEG. Full compression keeps a GBA frame to 2-26 KB, about
// 1 ms to encode at 5 frames a second.
constexpr int kWatchLosslessWidth = 320;
constexpr int kWatchPngCompression = 9;

pa::JsonObject box_json(const Box& box) {
  pa::JsonObject json;
  json["x"] = box.x;
  json["y"] = box.y;
  json["w"] = box.w;
  json["h"] = box.h;
  return json;
}

WatchFrame encode_frame(const cv::Mat& frame) {
  std::vector<unsigned char> bytes;
  if (frame.cols <= kWatchLosslessWidth) {
    cv::imencode(".png", frame, bytes,
                 {cv::IMWRITE_PNG_COMPRESSION, kWatchPngCompression});
    return {"image/png", std::string(bytes.begin(), bytes.end())};
  }
  cv::Mat scaled = frame;
  if (frame.cols > kWatchFrameWidth) {
    const double scale = static_cast<double>(kWatchFrameWidth) / frame.cols;
    cv::resize(frame, scaled, cv::Size(), scale, scale, cv::INTER_AREA);
  }
  cv::imencode(".jpg", scaled, bytes,
               {cv::IMWRITE_JPEG_QUALITY, kWatchJpegQuality});
  return {"image/jpeg", std::string(bytes.begin(), bytes.end())};
}

}  // namespace

std::uint16_t Server::watch_port() const { return watch_ ? watch_->port() : 0; }

std::string Server::watch_token() const {
  return watch_ ? watch_->token() : std::string();
}

// The page, and its entry in the registry so the hub lists it.
void Server::start_watch() {
  watch_ = std::make_unique<WatchServer>(
      *options_.watch,
      WatchHooks{[this] { return watch_frame(); },
                 [this] { return stop_program(); }},
      options_.stream);
  watch_->set_info(to_line(pa::JsonValue(hello_result(backend_.info()))));
  if (!options_.registry.empty()) {
    registry_entry_.emplace(
        options_.registry,
        RegistryEntry{own_pid(), watch_->port(), options_.watch->listen,
                      backend_.info().kind, options_.run_folder,
                      options_.checkpoint, unix_now_ms()});
  }
}

// A `watch.plan`, `watch.run` or `watch.log` notification from the program:
// the page's,
// so it never reaches dispatch or the wire log. Without a page it is dropped.
bool Server::take_watch_note(const pa::JsonValue& message) {
  const pa::JsonObject* object = message.to_object();
  if (object == nullptr || object->get_value("id") != nullptr) {
    return false;
  }
  const std::string* method = object->get_string("method");
  if (method == nullptr || (*method != "watch.plan" && *method != "watch.run" &&
                            *method != "watch.log")) {
    return false;
  }
  const pa::JsonObject* params = object->get_object("params");
  if (params == nullptr) {
    return true;
  }
  std::string json = to_line(pa::JsonValue(params->clone()));
  if (journal_) {
    if (*method == "watch.plan") {
      journal_->plan(json);
    } else if (*method == "watch.run") {
      journal_->chain(json);
    } else {
      journal_->log_line(*params, static_cast<double>(unix_now_ms()));
    }
  }
  if (*method == "watch.plan") {
    note_plan(*params);
  }
  if (watch_) {
    if (*method == "watch.plan") {
      watch_->set_plan(std::move(json));
    } else if (*method == "watch.run") {
      watch_->set_run(std::move(json));
    } else {
      watch_->add_log(std::move(json));
    }
  }
  return true;
}

// A new current event: recorded frames belong to it from now on, and its
// first frame is recorded at once (a failed event's as the failure). Between
// two events (none current) the frames stay with the last one.
void Server::note_plan(const pa::JsonObject& plan) {
  const PlanStep step = current_step(plan);
  FrameStream* frames = stream();
  if (step.id.empty() || step == step_ || frames == nullptr) {
    return;
  }
  step_ = step;
  frames->set_step(step.id);
  if (step.failed) {
    mark_failure();
  } else {
    frames->mark(kRecordStep);
  }
}

// One recorded failure frame per failure: the failed event and the
// failure.png the runner then saves are the same moment.
void Server::mark_failure() {
  constexpr double kSameFailureMs = 5000;
  const double now = clock_.now_ms();
  FrameStream* frames = stream();
  if (frames == nullptr || now - failure_marked_ms_ < kSameFailureMs) {
    return;
  }
  failure_marked_ms_ = now;
  frames->mark(kRecordFailure);
}

// Stop on the page: release every button now, then tell the program, which
// ends at its next wait. False when no program is connected.
bool Server::stop_program() {
  schedule_.clear();
  live_schedule_.clear();
  backend_.set_keys(0);
  sent_mask_ = KeyMask{0};
  std::fprintf(stderr, "daemon: stop pressed on the watch page%s\n",
               client_.valid() ? "" : " (no program connected)");
  if (!client_.valid()) {
    return false;
  }
  send(stop_notification("stopped by user"));
  pa::JsonObject line;
  line["line"] = "[Watch] Stop pressed: buttons released, program told";
  watch_->add_log(to_line(pa::JsonValue(std::move(line))));
  return true;
}

// The current frame, encoded at most every kWatchFrameMs: the frame the
// probes last ran on when it is current, else the backend's.
WatchFrame Server::watch_frame() {
  const double now = clock_.now_ms();
  if (!frame_shown_.bytes.empty() && now - frame_shown_ms_ < kWatchFrameMs) {
    return frame_shown_;
  }
  try {
    const bool probed = !probed_frame_.empty() && probed_seq_ == backend_.seq();
    frame_shown_ = encode_frame(probed ? probed_frame_ : backend_.frame());
    frame_shown_ms_ = now;
    watch_cost_.frames_encoded++;
    watch_cost_.frame_bytes +=
        static_cast<std::int64_t>(frame_shown_.bytes.size());
  } catch (const BackendError& error) {
    std::fprintf(stderr, "daemon: watch frame: %s\n", error.what());
  }
  return frame_shown_;
}

void Server::show_probes(
    std::int64_t seq,
    const std::vector<std::pair<std::string, ProbeResult>>& results) {
  const double start = clock_.now_ms();
  if (start - probes_shown_ms_ < kWatchFrameMs) {
    return;
  }
  pa::JsonArray list;
  for (std::size_t i = 0; i < probes_.size() && i < results.size(); i++) {
    pa::JsonObject probe;
    probe["id"] = probes_[i].spec.id;
    probe["kind"] = probes_[i].spec.kind;
    probe["box"] = box_json(probes_[i].spec.box);
    probe["result"] = probe_result_json(results[i].second);
    list.push_back(std::move(probe));
  }
  pa::JsonObject shown;
  shown["seq"] = seq;
  shown["probes"] = std::move(list);
  watch_->set_probes(to_line(pa::JsonValue(std::move(shown))));
  probes_shown_ = !probes_.empty();
  probes_shown_ms_ = start;
  watch_cost_.ms += clock_.now_ms() - start;
}

// The live stream's frame, when it wants one: the probed frame when it is
// current (no extra read: mGBA's costs a bridge round trip), else the
// backend's. The stream encodes it on its own thread.
void Server::offer_stream_frame() {
  FrameStream& frames = *stream();
  const std::int64_t seq = backend_.seq();
  const double now = clock_.now_ms();
  if (!frames.wants_frame(seq, now)) {
    return;
  }
  try {
    const bool probed = !probed_frame_.empty() && probed_seq_ == seq;
    frames.offer(probed ? probed_frame_ : backend_.frame(), seq, now);
  } catch (const BackendError& error) {
    std::fprintf(stderr, "daemon: stream frame: %s\n", error.what());
  }
  watch_cost_.ms += clock_.now_ms() - now;
}

// Each loop pass: the stream's frame, the health once a second (and at once for a new viewer),
// and an empty probe list once the
// probes are gone (no frame shows them any more).
void Server::watch_tick() {
  offer_stream_frame();
  if (!watch_->has_viewers()) {
    return;
  }
  const double now = clock_.now_ms();
  if (watch_->take_joined() || now - status_shown_ms_ >= kWatchStatusMs) {
    watch_->broadcast("status",
                      to_line(pa::JsonValue(status_result(status()))));
    status_shown_ms_ = now;
  }
  if (probes_shown_ && (probes_.empty() || !client_.valid())) {
    watch_->set_probes("{\"seq\":" + std::to_string(backend_.seq()) +
                       ",\"probes\":[]}");
    probes_shown_ = false;
  }
  watch_cost_.ms += clock_.now_ms() - now;
}

}  // namespace gamepilot
