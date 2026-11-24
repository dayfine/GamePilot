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
// goes to 640x360; the GBA's 240x160 is sent as it is).
constexpr int kWatchFrameWidth = 640;
constexpr int kWatchJpegQuality = 85;

pa::JsonObject box_json(const Box& box) {
  pa::JsonObject json;
  json["x"] = box.x;
  json["y"] = box.y;
  json["w"] = box.w;
  json["h"] = box.h;
  return json;
}

std::string encode_jpeg(const cv::Mat& frame) {
  cv::Mat scaled = frame;
  if (frame.cols > kWatchFrameWidth) {
    const double scale = static_cast<double>(kWatchFrameWidth) / frame.cols;
    cv::resize(frame, scaled, cv::Size(), scale, scale, cv::INTER_AREA);
  }
  std::vector<unsigned char> jpeg;
  cv::imencode(".jpg", scaled, jpeg,
               {cv::IMWRITE_JPEG_QUALITY, kWatchJpegQuality});
  return std::string(jpeg.begin(), jpeg.end());
}

}  // namespace

std::uint16_t Server::watch_port() const { return watch_ ? watch_->port() : 0; }

void Server::start_watch() {
  watch_ = std::make_unique<WatchServer>(
      *options_.watch, WatchHooks{[this] { return frame_jpeg(); },
                                  [this] { return stop_program(); }});
  watch_->set_info(to_line(pa::JsonValue(hello_result(backend_.info()))));
}

// A `watch.plan` or `watch.log` notification from the program: the page's,
// so it never reaches dispatch or the wire log. Without a page it is dropped.
bool Server::take_watch_note(const pa::JsonValue& message) {
  const pa::JsonObject* object = message.to_object();
  if (object == nullptr || object->get_value("id") != nullptr) {
    return false;
  }
  const std::string* method = object->get_string("method");
  if (method == nullptr ||
      (*method != "watch.plan" && *method != "watch.log")) {
    return false;
  }
  const pa::JsonObject* params = object->get_object("params");
  if (watch_ && params != nullptr) {
    std::string json = to_line(pa::JsonValue(params->clone()));
    if (*method == "watch.plan") {
      watch_->set_plan(std::move(json));
    } else {
      watch_->add_log(std::move(json));
    }
  }
  return true;
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

// The current frame as a JPEG, encoded at most every kWatchFrameMs: the
// frame the probes last ran on when it is current, else the backend's.
std::string Server::frame_jpeg() {
  const double now = clock_.now_ms();
  if (!frame_jpeg_.empty() && now - frame_jpeg_ms_ < kWatchFrameMs) {
    return frame_jpeg_;
  }
  try {
    const bool probed = !probed_frame_.empty() && probed_seq_ == backend_.seq();
    frame_jpeg_ = encode_jpeg(probed ? probed_frame_ : backend_.frame());
    frame_jpeg_ms_ = now;
    watch_cost_.frames_encoded++;
  } catch (const BackendError& error) {
    std::fprintf(stderr, "daemon: watch frame: %s\n", error.what());
  }
  return frame_jpeg_;
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

// Each loop pass: the health once a second (and at once for a new viewer),
// and an empty probe list once the
// probes are gone (no frame shows them any more).
void Server::watch_tick() {
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
