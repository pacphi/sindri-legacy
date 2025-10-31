#!/bin/bash
# Performance benchmarks for upgrade operations

set -euo pipefail

benchmark_upgrade_single() {
    local extension="$1"
    local start_time end_time duration

    print_status "Benchmarking upgrade: ${extension}"

    start_time=$(date +%s)
    extension-manager upgrade "$extension" >/dev/null 2>&1
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    echo "${extension}: ${duration}s"

    # Check against target (60s for most extensions)
    if [[ $duration -gt 60 ]]; then
        print_warning "${extension} upgrade took ${duration}s (target: <60s)"
    else
        print_success "${extension} upgrade within target time"
    fi
}

benchmark_upgrade_all() {
    print_status "Benchmarking upgrade-all..."

    local start_time end_time duration

    start_time=$(date +%s)
    extension-manager upgrade-all >/dev/null 2>&1
    end_time=$(date +%s)
    duration=$((end_time - start_time))

    echo "upgrade-all: ${duration}s"

    # Target: <5 minutes for all extensions
    if [[ $duration -gt 300 ]]; then
        print_warning "upgrade-all took ${duration}s (target: <300s)"
    else
        print_success "upgrade-all within target time"
    fi
}

main() {
    print_status "Running performance benchmarks..."
    echo ""

    benchmark_upgrade_single "nodejs"
    benchmark_upgrade_single "python"
    benchmark_upgrade_single "docker"

    echo ""
    benchmark_upgrade_all

    echo ""
    print_success "Benchmark completed"
}

main "$@"
