// Link spike: proves the daemon links Arduino-Source's CoreLib and OpenCV.

#include <cstdio>
#include <string>

#include <opencv2/core.hpp>

#include "Common/Cpp/Json/JsonObject.h"
#include "Common/Cpp/Json/JsonValue.h"
#include "CommonFramework/Globals.h"

namespace pa = PokemonAutomation;

int main() {
  cv::Mat image(4, 4, CV_8UC1, cv::Scalar(7));
  image.at<unsigned char>(0, 0) = 23;
  cv::Scalar mean;
  cv::Scalar stddev;
  cv::meanStdDev(image, mean, stddev);

  pa::JsonObject report;
  report["pa_core_version"] = pa::PROGRAM_VERSION;
  report["opencv_version"] = std::string(cv::getVersionString());
  report["mean"] = mean[0];
  report["stddev"] = stddev[0];

  const std::string text = report.dump(2);
  const pa::JsonValue parsed = pa::parse_json(text);
  const pa::JsonObject* round_trip = parsed.to_object();
  if (round_trip == nullptr ||
      round_trip->get_string_throw("opencv_version") != cv::getVersionString()) {
    std::fputs("JSON round trip failed\n", stderr);
    return 1;
  }
  std::printf("%s\n", text.c_str());
  return 0;
}
