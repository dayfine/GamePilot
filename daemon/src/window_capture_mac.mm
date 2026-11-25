// open_window_capture on macOS (window_capture.h): an SCStream on one window,
// BGRA frames converted to BGR. Seeded by the 2026-11-23 experiments
// (sck.swift: the stream; wins.swift: the window list).

// OpenCV before the Apple headers: their YES/NO macros clash with it.
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <condition_variable>
#include <mutex>
#include <vector>

#include "backend.h"
#include "window_capture.h"

#import <AppKit/AppKit.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>

namespace gamepilot {
namespace {

// The latest frame, shared between the stream's queue and read().
struct FrameSlot {
  std::mutex lock;
  std::condition_variable ready;
  cv::Mat frame;
  std::int64_t seq = 0;
  bool failed = false;
};

// Waits for an asynchronous ScreenCaptureKit call.
constexpr auto kCallTimeout = std::chrono::seconds(10);
// The first frame may take a while (the stream starts).
constexpr double kFirstFrameMs = 5000;
// visibility() reads the window list at most this often.
constexpr double kVisibilityEveryMs = 1000;
// Widest frame asked for: the window's pixels, at most this wide.
constexpr double kMaxWidth = 2560;

double now_ms() {
  return std::chrono::duration<double, std::milli>(
             std::chrono::steady_clock::now().time_since_epoch())
      .count();
}

}  // namespace
}  // namespace gamepilot

@interface GamePilotFrameOutput : NSObject <SCStreamOutput, SCStreamDelegate>
- (instancetype)initWithSlot:(gamepilot::FrameSlot*)slot;
@end

@implementation GamePilotFrameOutput {
  gamepilot::FrameSlot* _slot;
}

- (instancetype)initWithSlot:(gamepilot::FrameSlot*)slot {
  self = [super init];
  if (self != nil) {
    _slot = slot;
  }
  return self;
}

- (void)stream:(SCStream*)stream
    didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                   ofType:(SCStreamOutputType)type {
  (void)stream;
  if (type != SCStreamOutputTypeScreen) {
    return;
  }
  CFArrayRef attachments =
      CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
  if (attachments == nullptr || CFArrayGetCount(attachments) == 0) {
    return;
  }
  NSDictionary* info =
      (__bridge NSDictionary*)CFArrayGetValueAtIndex(attachments, 0);
  NSNumber* status = info[SCStreamFrameInfoStatus];
  if (status == nil || status.integerValue != SCFrameStatusComplete) {
    return;  // idle: nothing changed since the last frame
  }
  CVPixelBufferRef pixels = CMSampleBufferGetImageBuffer(sampleBuffer);
  if (pixels == nullptr) {
    return;
  }
  CVPixelBufferLockBaseAddress(pixels, kCVPixelBufferLock_ReadOnly);
  const cv::Mat bgra(static_cast<int>(CVPixelBufferGetHeight(pixels)),
                     static_cast<int>(CVPixelBufferGetWidth(pixels)), CV_8UC4,
                     CVPixelBufferGetBaseAddress(pixels),
                     CVPixelBufferGetBytesPerRow(pixels));
  cv::Mat bgr;
  cv::cvtColor(bgra, bgr, cv::COLOR_BGRA2BGR);
  CVPixelBufferUnlockBaseAddress(pixels, kCVPixelBufferLock_ReadOnly);
  {
    const std::lock_guard<std::mutex> hold(_slot->lock);
    _slot->frame = std::move(bgr);
    _slot->seq++;
  }
  _slot->ready.notify_all();
}

- (void)stream:(SCStream*)stream didStopWithError:(NSError*)error {
  (void)stream;
  NSLog(@"gamepilot: window capture stopped: %@", error);
  {
    const std::lock_guard<std::mutex> hold(_slot->lock);
    _slot->failed = true;
  }
  _slot->ready.notify_all();
}

@end

namespace gamepilot {
namespace {

std::string utf8(NSString* text) {
  return text != nil ? std::string(text.UTF8String) : std::string();
}

// Waits for a completion handler; throws BackendError on a timeout.
void wait_for(dispatch_semaphore_t done, const char* what) {
  const auto ns = std::chrono::nanoseconds(kCallTimeout).count();
  if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, ns)) !=
      0) {
    throw BackendError(std::string("window capture: ") + what + " timed out");
  }
}

SCShareableContent* shareable_content() {
  __block SCShareableContent* content = nil;
  __block NSError* failure = nil;
  dispatch_semaphore_t done = dispatch_semaphore_create(0);
  [SCShareableContent
      getShareableContentExcludingDesktopWindows:YES
                             onScreenWindowsOnly:NO
                               completionHandler:^(SCShareableContent* result,
                                                   NSError* error) {
                                 content = result;
                                 failure = error;
                                 dispatch_semaphore_signal(done);
                               }];
  wait_for(done, "listing windows");
  if (content == nil) {
    throw BackendError(
        "window capture: cannot list windows (Screen Recording permission?): " +
        utf8(failure.localizedDescription));
  }
  return content;
}

bool app_matches(SCRunningApplication* app, const WindowCaptureConfig& config) {
  if (config.pid != 0) {
    return app.processID == config.pid;
  }
  NSRunningApplication* running = [NSRunningApplication
      runningApplicationWithProcessIdentifier:app.processID];
  return running != nil &&
         utf8(running.bundleURL.path) ==
             utf8([[NSURL fileURLWithPath:@(config.app_path.c_str())]
                     URLByStandardizingPath]
                      .path);
}

// The largest normal window of the app whose title has `config.title`.
SCWindow* find_window(SCShareableContent* content,
                      const WindowCaptureConfig& config) {
  SCWindow* best = nil;
  for (SCWindow* window in content.windows) {
    if (window.owningApplication == nil || window.windowLayer != 0 ||
        !app_matches(window.owningApplication, config) ||
        utf8(window.title).find(config.title) == std::string::npos) {
      continue;
    }
    const double area = window.frame.size.width * window.frame.size.height;
    if (best == nil ||
        area > best.frame.size.width * best.frame.size.height) {
      best = window;
    }
  }
  return best;
}

cv::Rect2d rect_from(NSDictionary* bounds) {
  CGRect rect;
  if (!CGRectMakeWithDictionaryRepresentation(
          (__bridge CFDictionaryRef)bounds, &rect)) {
    return {};
  }
  return {rect.origin.x, rect.origin.y, rect.size.width, rect.size.height};
}

class WindowCapture : public FrameSource {
 public:
  explicit WindowCapture(const WindowCaptureConfig& config)
      : frame_rate_(config.frame_rate) {
    [NSApplication sharedApplication];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    SCWindow* window = find_window(shareable_content(), config);
    if (window == nil) {
      throw BackendError("window capture: no window of " +
                         (config.pid != 0 ? "pid " + std::to_string(config.pid)
                                          : config.app_path) +
                         " titled \"" + config.title + "\"");
    }
    window_id_ = window.windowID;
    std::fprintf(stderr, "daemon: capturing window %u \"%s\" of pid %d\n",
                 window_id_, utf8(window.title).c_str(),
                 window.owningApplication.processID);
    SCStreamConfiguration* settings = [[SCStreamConfiguration alloc] init];
    const double scale = NSScreen.mainScreen.backingScaleFactor;
    const double width =
        std::min(window.frame.size.width * scale, kMaxWidth);
    settings.width = static_cast<size_t>(width);
    settings.height = static_cast<size_t>(
        width * window.frame.size.height / window.frame.size.width);
    settings.minimumFrameInterval =
        CMTimeMake(1, static_cast<int32_t>(config.frame_rate));
    settings.showsCursor = NO;
    settings.queueDepth = 3;
    settings.pixelFormat = kCVPixelFormatType_32BGRA;
    output_ = [[GamePilotFrameOutput alloc] initWithSlot:&slot_];
    SCContentFilter* filter =
        [[SCContentFilter alloc] initWithDesktopIndependentWindow:window];
    stream_ = [[SCStream alloc] initWithFilter:filter
                                 configuration:settings
                                      delegate:output_];
    queue_ = dispatch_queue_create("gamepilot.window-capture",
                                   DISPATCH_QUEUE_SERIAL);
    NSError* error = nil;
    if (![stream_ addStreamOutput:output_
                             type:SCStreamOutputTypeScreen
               sampleHandlerQueue:queue_
                            error:&error]) {
      throw BackendError("window capture: " +
                         utf8(error.localizedDescription));
    }
    call_stream(/*start=*/true);
  }

  ~WindowCapture() override {
    try {
      call_stream(/*start=*/false);
    } catch (const BackendError&) {
      // Stopping is best effort: the process is ending.
    }
  }

  // The next frame; the last one again when none came within two frame
  // times (the window did not change).
  bool read(cv::Mat& frame) override {
    std::unique_lock<std::mutex> hold(slot_.lock);
    const double wait_ms = slot_.seq == 0 ? kFirstFrameMs : 2000 / frame_rate_;
    slot_.ready.wait_for(
        hold, std::chrono::duration<double, std::milli>(wait_ms),
        [&] { return slot_.failed || slot_.seq > read_seq_; });
    if (slot_.failed || slot_.frame.empty()) {
      return false;
    }
    read_seq_ = slot_.seq;
    frame = slot_.frame.clone();
    return true;
  }

  double frame_rate() const override { return frame_rate_; }

  std::optional<SourceStatus> visibility() override {
    const double now = now_ms();
    if (visibility_ && now - visibility_ms_ < kVisibilityEveryMs) {
      return visibility_;
    }
    visibility_ms_ = now;
    visibility_ = read_visibility();
    return visibility_;
  }

 private:
  void call_stream(bool start) {
    __block NSError* failure = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    void (^handler)(NSError*) = ^(NSError* error) {
      failure = error;
      dispatch_semaphore_signal(done);
    };
    if (start) {
      [stream_ startCaptureWithCompletionHandler:handler];
    } else {
      [stream_ stopCaptureWithCompletionHandler:handler];
    }
    wait_for(done, start ? "starting" : "stopping");
    if (failure != nil) {
      throw BackendError("window capture: " +
                         utf8(failure.localizedDescription));
    }
  }

  // The on-screen window list, front to back: the normal windows in front of
  // ours, and whether ours is on screen.
  SourceStatus read_visibility() const {
    CFArrayRef list = CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
        kCGNullWindowID);
    if (list == nullptr) {
      return {SourceState::kLive, "window list unavailable"};
    }
    NSArray* windows = CFBridgingRelease(list);
    std::vector<ScreenWindow> in_front;
    for (NSDictionary* window in windows) {
      const auto number = [window[(__bridge NSString*)kCGWindowNumber]
          unsignedIntValue];
      const cv::Rect2d bounds =
          rect_from(window[(__bridge NSString*)kCGWindowBounds]);
      if (number == window_id_) {
        return window_visibility(bounds, /*on_screen=*/true, in_front);
      }
      const int layer =
          [window[(__bridge NSString*)kCGWindowLayer] intValue];
      const double alpha =
          [window[(__bridge NSString*)kCGWindowAlpha] doubleValue];
      if (layer == 0 && alpha > 0) {
        in_front.push_back(ScreenWindow{
            bounds, utf8(window[(__bridge NSString*)kCGWindowOwnerName])});
      }
    }
    return window_visibility({}, /*on_screen=*/false, in_front);
  }

  double frame_rate_;
  CGWindowID window_id_ = 0;
  FrameSlot slot_;
  std::int64_t read_seq_ = 0;
  GamePilotFrameOutput* output_ = nil;
  SCStream* stream_ = nil;
  dispatch_queue_t queue_ = nil;
  std::optional<SourceStatus> visibility_;
  double visibility_ms_ = 0;
};

}  // namespace

std::unique_ptr<FrameSource> open_window_capture(
    const WindowCaptureConfig& config) {
  @autoreleasepool {
    return std::make_unique<WindowCapture>(config);
  }
}

}  // namespace gamepilot
