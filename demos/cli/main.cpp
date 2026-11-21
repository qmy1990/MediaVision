#include <fstream>
#include <iostream>
#include <string>
#include <vector>

#include "mvs/mvs.hpp"
// Portable RGB PPM demo. For inference, install an MvsAnalyzeFn provider or use
// platform wrappers; this CLI tests actual sharpening with no required model.
int main(int argc, char** argv) {
  if (argc != 3 && argc != 5) {
    std::cout << "Usage: mvs_demo_cli input.ppm output.ppm "
                 "[pupil_size landmarks.txt]\n"
                 "Binary P6; pupil_size: 0 smaller, 0.5 neutral, 1 larger.\n"
                 "landmarks.txt: 478 normalized x y z rows, matched to input.\n";
    return argc == 1 ? 0 : 1;
  }
  try {
    std::ifstream input(argv[1], std::ios::binary);
    std::string magic;
    unsigned w, h, maxval;
    if (!(input >> magic >> w >> h >> maxval) || magic != "P6" || !w || !h ||
        w > 1920 || h > 1920 || maxval != 255) {
      throw std::runtime_error("Unsupported PPM");
    }
    input.get();
    std::vector<uint8_t> rgb(static_cast<size_t>(w) * h * 3),
        rgba(static_cast<size_t>(w) * h * 4), output(rgba.size());
    if (!input.read(reinterpret_cast<char*>(rgb.data()), rgb.size())) {
      throw std::runtime_error("Truncated image");
    }
    for (size_t k = 0; k < static_cast<size_t>(w) * h; ++k) {
      for (unsigned c = 0; c < 3; ++c) {
        rgba[k * 4 + c] = rgb[k * 3 + c];
      }
      rgba[k * 4 + 3] = 255;
    }
    mvs::Engine engine;
    std::vector<MvsLandmark> landmarks;
    MvsAnalysis analysis{};
    if (argc == 5) {
      size_t end = 0;
      auto geometry = mvs_default_eye_geometry();
      geometry.pupil_size = std::stof(argv[3], &end);
      if (argv[3][end] != '\0') {
        throw std::runtime_error("Invalid pupil_size");
      }
      engine.setEyeGeometry(geometry);
      std::ifstream points(argv[4]);
      landmarks.resize(478);
      for (auto& point : landmarks) {
        if (!(points >> point.x >> point.y >> point.z)) {
          throw std::runtime_error("Expected 478 normalized x y z landmark rows");
        }
      }
      std::string extra;
      if (points >> extra) {
        throw std::runtime_error("Unexpected data after 478 landmarks");
      }
      analysis.landmarks = landmarks.data();
      analysis.landmark_count = static_cast<uint32_t>(landmarks.size());
    }
    auto options = mvs_default_options();
    options.sharpen = .3f;
    engine.setOptions(options);
    MvsFrame frame{rgba.data(), rgba.size(), w, h, w * 4, MVS_RGBA8, 0};
    MvsOutput dest{output.data(), output.size(), w * 4, MVS_RGBA8};
    if (argc == 5) {
      engine.process(frame, analysis, dest);
    } else {
      mvs::Check(mvs_process(engine.get(), &frame, &dest));
    }
    std::ofstream file(argv[2], std::ios::binary);
    file << "P6\n" << w << " " << h << "\n255\n";
    for (size_t k = 0; k < static_cast<size_t>(w) * h; ++k) {
      file.write(reinterpret_cast<char*>(output.data() + k * 4), 3);
    }
    if (!file) {
      throw std::runtime_error("Cannot write output");
    }
    std::cout << "SDK " << mvs_version()
              << ", backend=" << mvs_backend(engine.get()) << ", processed "
              << w << "x" << h << "\n";
  } catch (const std::exception& e) {
    std::cerr << e.what() << "\n";
    return 1;
  }
}
