// Subscribed probes run on a frame: the checks subscribe makes and the
// evaluation of each probe. Shared by the daemon's frame loop and the offline
// probe_images tool.

#pragma once

#include <opencv2/core.hpp>

#include "probes.h"
#include "rpc.h"
#include "template_store.h"

namespace gamepilot {

// Throws RpcError kUnknownProbeKind for an unknown kind, and kInvalidParams for
// a template_match probe whose template is not in `templates` or does not fit
// its box in a width x height frame.
void check_probe(const ProbeSpec& probe, const TemplateStore& templates,
                 int width, int height);

// The probe's result on a BGR frame. Requires check_probe to have passed for
// the frame's size with the same templates.
ProbeResult evaluate_probe(const ProbeSpec& probe, const cv::Mat& frame,
                           const TemplateStore& templates);

}  // namespace gamepilot
