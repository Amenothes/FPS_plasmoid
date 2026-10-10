#include "stats_export.h"
#include "logging.h"

#include <atomic>
#include <chrono>
#include <fstream>
#include <string>
#include <thread>
#include <cstdio>
#include <unistd.h>

namespace {

std::atomic<bool> exporter_running{false};
std::string exporter_path;

constexpr auto EXPORT_INTERVAL = std::chrono::milliseconds(500);

void write_once()
{
    if (fps <= 0.0)
        return;

    const std::string tmp = exporter_path + ".tmp";
    {
        std::ofstream out(tmp, std::ios::trunc);
        if (!out.is_open())
            return;
        out << "{\"fps\":" << fps
            << ",\"frametime\":" << frametime
            << "}\n";
    }
    if (rename(tmp.c_str(), exporter_path.c_str()) != 0)
        unlink(tmp.c_str());
}

void exporter_loop()
{
    while (exporter_running.load(std::memory_order_relaxed)) {
        write_once();
        std::this_thread::sleep_for(EXPORT_INTERVAL);
    }
    unlink(exporter_path.c_str());
}

} // namespace

void start_stats_export(const overlay_params& params)
{
    if (params.export_file.empty())
        return;
    if (exporter_running.exchange(true))
        return;

    exporter_path = params.export_file;
    std::thread(exporter_loop).detach();
}

void stop_stats_export()
{
    exporter_running.store(false);
}
