#ifndef MEDIAVISIONSDK_INCLUDE_MVS_MVS_HPP_
#define MEDIAVISIONSDK_INCLUDE_MVS_MVS_HPP_
#include <stdexcept>
#include <utility>

#include "models.h"
#include "sdk.h"
namespace mvs {
inline void Check(MvsStatus s) {
  if (s != MVS_OK) {
    throw std::runtime_error(mvs_status_string(s));
  }
}
class ModelPackage {
  MvsModelsHandle handle_ = nullptr;

 public:
  explicit ModelPackage(const char* path) {
    Check(mvs_models_open(path, &handle_));
  }
  ~ModelPackage() { mvs_models_close(handle_); }
  ModelPackage(const ModelPackage&) = delete;
  ModelPackage& operator=(const ModelPackage&) = delete;
  ModelPackage(ModelPackage&& other) noexcept
      : handle_(std::exchange(other.handle_, nullptr)) {}
  MvsModelsHandle get() const noexcept { return handle_; }
  MvsModelView model(uint32_t id) const {
    MvsModelView view{};
    Check(mvs_models_get(handle_, id, &view));
    return view;
  }
};
class Engine {
  MvsHandle handle_ = nullptr;

 public:
  explicit Engine(MvsConfig config = mvs_default_config()) {
    Check(mvs_create(&config, &handle_));
  }
  ~Engine() { mvs_destroy(handle_); }
  Engine(const Engine&) = delete;
  Engine& operator=(const Engine&) = delete;
  Engine(Engine&& other) noexcept
      : handle_(std::exchange(other.handle_, nullptr)) {}
  MvsHandle get() const noexcept { return handle_; }
  void setOptions(const MvsOptions& o) { Check(mvs_set_options(handle_, &o)); }
  void process(const MvsFrame& i, const MvsAnalysis& a, MvsOutput& o) {
    Check(mvs_process_with_analysis(handle_, &i, &a, &o));
  }
};
}  // namespace mvs

#endif  // MEDIAVISIONSDK_INCLUDE_MVS_MVS_HPP_
