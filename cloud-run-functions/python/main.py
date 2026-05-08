# Unless explicitly stated otherwise all files in this repository are licensed
# under the Apache 2.0 License.

# This product includes software developed at
# Datadog (https://www.datadoghq.com/)
# Copyright 2025-present Datadog, Inc.

import logging
import sys
import os
import subprocess
from datetime import datetime
from typing import Any

import requests
from datadog import initialize, statsd
from datadog_serverless_compat import start
from ddtrace import tracer, patch_all
from flask import Request

patch_all()

if os.getenv("COMPAT_LAYER", "false").lower() == "true":
    start()
    options = {
        "statsd_host": "127.0.0.1",
        "statsd_port": 8125,
        "statsd_namespace": "custom.kh.gcp.cloud_run_functions",
        "statsd_constant_tags": os.getenv("DD_TAGS", "").split(","),
    }
    initialize(**options)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s [%(name)s] [%(filename)s:%(lineno)d] - %(message)s',
    stream=sys.stdout,
    force=True
)
logger = logging.getLogger(__name__)


def read_file(filepath):
    """Helper to read /proc files and return content."""
    try:
        with open(filepath, 'r') as f:
            return f.read()
    except Exception as e:
        return f"Error reading {filepath}: {e}"


def check_file_exists(filepath):
    """Check if a file exists."""
    exists = os.path.exists(filepath)
    print(f"{'✓' if exists else '✗'} {filepath} {'exists' if exists else 'does not exist'}")
    return exists


def read_proc_files():
    """Read and print /proc files."""
    print("\n" + "="*60)
    print("PROC FILES EXPLORATION")
    print("="*60)

    # List /proc directory contents
    try:
        proc_files = os.listdir('/proc')
        print(f"\n/proc directory contents: {proc_files}")
    except Exception as e:
        print(f"Error listing /proc: {e}")

    # Read specific files
    files_to_read = ['/proc/stat', '/proc/uptime']

    for filepath in files_to_read:
        if os.path.exists(filepath):
            content = read_file(filepath)
            print(f"\n--- {filepath} ---")
            print(content)
        else:
            print(f"\n✗ {filepath} does not exist")


def check_cgroup_version():
    """Check cgroup version using stat -fc %T /sys/fs/cgroup/."""
    print("\n" + "="*60)
    print("CGROUP VERSION CHECK")
    print("="*60)

    try:
        # Run stat -fc %T /sys/fs/cgroup/ to get filesystem type
        result = subprocess.run(
            ['stat', '-fc', '%T', '/sys/fs/cgroup/'],
            capture_output=True,
            text=True,
            timeout=5
        )
        fs_type = result.stdout.strip()
        print(f"\nFilesystem type of /sys/fs/cgroup/: {fs_type}")

        # Interpret the result
        if fs_type == 'cgroup2fs':
            version = 'cgroup v2 (unified hierarchy)'
        elif fs_type in ('tmpfs', 'cgroup'):
            version = 'cgroup v1 (legacy hierarchy)'
        else:
            version = f'Unknown ({fs_type})'

        print(f"Cgroup version: {version}")

        if result.returncode != 0:
            print(f"stat stderr: {result.stderr}")

        return fs_type, version

    except subprocess.TimeoutExpired:
        print("Error: stat command timed out")
        return None, "timeout"
    except FileNotFoundError:
        print("Error: stat command not found")
        return None, "stat not found"
    except Exception as e:
        print(f"Error checking cgroup version: {e}")
        return None, str(e)


def list_cgroup_contents():
    """List the full contents of cgroup directories recursively."""
    print("\n" + "="*60)
    print("CGROUP DIRECTORY CONTENTS")
    print("="*60)

    cgroup_root = '/sys/fs/cgroup'

    if not os.path.exists(cgroup_root):
        print(f"✗ {cgroup_root} does not exist")
        return

    try:
        # Walk through the cgroup directory tree
        for root, dirs, files in os.walk(cgroup_root):
            # Limit depth to avoid too much output
            depth = root.replace(cgroup_root, '').count(os.sep)
            if depth > 2:
                continue

            indent = '  ' * depth
            print(f"\n{indent}📁 {root}/")

            # List files in this directory
            for f in sorted(files)[:20]:  # Limit files per directory
                filepath = os.path.join(root, f)
                print(f"{indent}  📄 {f}")

            if len(files) > 20:
                print(f"{indent}  ... and {len(files) - 20} more files")

            # Show subdirectories
            for d in sorted(dirs)[:10]:
                if depth >= 2:
                    print(f"{indent}  📁 {d}/ (not expanded)")

            if len(dirs) > 10:
                print(f"{indent}  ... and {len(dirs) - 10} more directories")

    except Exception as e:
        print(f"Error walking cgroup directory: {e}")


def read_cgroup_files():
    """Read and print cgroup files."""
    print("\n" + "="*60)
    print("CGROUP FILES EXPLORATION")
    print("="*60)

    # List cgroup directories
    cgroup_dirs = ['/sys/fs/cgroup', '/sys/fs/cgroup/cpu', '/sys/fs/cgroup/memory']

    for dirpath in cgroup_dirs:
        try:
            if os.path.exists(dirpath) and os.path.isdir(dirpath):
                contents = os.listdir(dirpath)
                print(f"\n{dirpath} directory contents: {contents}")
            else:
                print(f"\n{dirpath} does not exist or is not a directory")
        except Exception as e:
            print(f"\nError listing {dirpath}: {e}")

    # Try to read various cgroup CPU files that might exist
    cgroup_files = [
        '/sys/fs/cgroup/cpu/cpuacct.usage',
        '/sys/fs/cgroup/cpu/cpu.cfs_quota_us',
        '/sys/fs/cgroup/cpu/cpu.cfs_period_us',
        '/sys/fs/cgroup/cpu/cpu.shares',
    ]

    print("\n--- Reading cgroup CPU files ---")
    for cgroup_file in cgroup_files:
        if os.path.exists(cgroup_file):
            content = read_file(cgroup_file)
            print(f"{cgroup_file}: {content.strip()}")
        else:
            print(f"✗ {cgroup_file} does not exist")


def calculate_cpu_metrics():
    """Calculate CPU metrics from /proc and cgroup files."""
    print("\n" + "="*60)
    print("CPU METRICS CALCULATION")
    print("="*60)

    try:
        # Read /proc/stat for system CPU times
        with open('/proc/stat', 'r') as f:
            first_line = f.readline()
            cpu_times = [int(x) for x in first_line.split()[1:]]
            total_cpu_time = sum(cpu_times)
            print(f"\n/proc/stat CPU times: {cpu_times}")
            print(f"Total CPU time: {total_cpu_time}")

        # Read /proc/uptime for system uptime
        with open('/proc/uptime', 'r') as f:
            uptime_line = f.read().strip()
            uptime_seconds = float(uptime_line.split()[0])
            print(f"\nSystem uptime: {uptime_seconds} seconds")

        # Read cgroup CPU quota and period to calculate CPU limit
        quota_file = '/sys/fs/cgroup/cpu/cpu.cfs_quota_us'
        period_file = '/sys/fs/cgroup/cpu/cpu.cfs_period_us'

        if os.path.exists(quota_file) and os.path.exists(period_file):
            with open(quota_file, 'r') as f:
                quota = int(f.read().strip())
            with open(period_file, 'r') as f:
                period = int(f.read().strip())

            print(f"\nCPU quota: {quota} microseconds")
            print(f"CPU period: {period} microseconds")

            if quota > 0:
                cpu_limit = quota / period
                print(f"CPU limit (cores): {cpu_limit}")
            else:
                print("CPU limit: unlimited (quota is -1)")
        else:
            print("\n✗ CPU quota/period files not found")

        # Try to calculate CPU usage rate
        # Note: In a real scenario, you'd take multiple samples over time
        print("\n--- CPU Rate Calculation ---")
        print("Note: For accurate CPU rate, you need to sample /proc/stat over time")
        print(f"Current total CPU time: {total_cpu_time} jiffies")

        # Read CPU shares (relative weight)
        shares_file = '/sys/fs/cgroup/cpu/cpu.shares'
        if os.path.exists(shares_file):
            with open(shares_file, 'r') as f:
                shares = int(f.read().strip())
            print(f"CPU shares: {shares}")

    except Exception as e:
        print(f"Error calculating CPU metrics: {e}")

@tracer.wrap()
def main(request: Request) -> Any:
    logger.info("Hello world!")

    # Check GCP-provided env vars
    print(f"FUNCTION_NAME={os.environ.get('FUNCTION_NAME', 'NOT SET')}")
    print(f"GCP_PROJECT={os.environ.get('GCP_PROJECT', 'NOT SET')}")
    print(f"FUNCTION_TARGET={os.environ.get('FUNCTION_TARGET', 'NOT SET')}")
    print(f"K_SERVICE={os.environ.get('K_SERVICE', 'NOT SET')}")

    # Outbound request to generate a trace
    try:
        requests.get("https://dummyjson.com/http/200", timeout=5)
    except requests.exceptions.RequestException as e:
        print(f"Request failed: {e}")

    # Custom metrics via DogStatsD (only available in compat layer mode)
    if os.getenv("COMPAT_LAYER", "false").lower() == "true":
        statsd.increment("count")
        statsd.gauge("gauge", 1)
        statsd.distribution("distribution", 1)

        current_timestamp = int(datetime.now().timestamp())
        statsd.count_with_timestamp("count.timestamp", 1, timestamp=current_timestamp)
        statsd.gauge_with_timestamp("gauge.timestamp", 1, timestamp=current_timestamp)

    # Check cgroup version first
    # fs_type, version = check_cgroup_version()

    # # List cgroup directory contents
    # list_cgroup_contents()

    # # Explore proc and cgroup files
    # read_proc_files()
    # read_cgroup_files()

    # # Calculate CPU metrics
    # calculate_cpu_metrics()

    return f'Hello World!', 200
