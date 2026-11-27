// Subscribed probes mapped onto frames: the checks subscribe makes, the box and
// template in frame pixels, and the evaluation of each probe. Shared by the
// daemon's frame loop and the offline probe_images tool.

#pragma once

#include <opencv2/core.hpp>

#include "probes.h"
#include "rpc.h"
#include "template_store.h"
#include "viewport.h"

namespace gamepilot {

// A subscribed probe on frames of one size.
struct FrameProbe {
  ProbeSpec spec;
  Viewport viewport;
  cv::Rect pixels;  // the box in frame pixels
  // core.template_match@1 (BGR, or with ink its mask) and core.template_ncc@1
  // (8-bit grayscale): the template scaled to frame pixels.
  cv::Mat template_image;
  // core.template_match@1 with skip_seams only: the template's whole pixels
  // (whole_pixels), the ones compared.
  cv::Mat compared;
  // core.find@1 only: its params in frame pixels, with its template and shape.
  FrameFind find;
};

// Maps the probe's picture-relative box (and template, given in game pixels)
// onto a width x height frame. Throws RpcError kUnknownProbeKind for an
// unknown kind, and kInvalidParams for a template_match probe whose template
// is not in `templates` or, scaled, does not fit its box (or, with skip_seams,
// has no whole pixel), and for a find probe
// whose template or shape is not in `templates`.
FrameProbe map_probe(const ProbeSpec& probe, const TemplateStore& templates,
                     const Viewport& viewport, int width, int height);

// The probe's result on a BGR frame of the size it was mapped for. Template
// placements are normalized to the game picture.
ProbeResult evaluate_probe(const FrameProbe& probe, const cv::Mat& frame);

}  // namespace gamepilot
