#!/usr/bin/env bash
set -euo pipefail
# Replace QoS::BestAvailable with explicit settings for Humble
# Run from repo root before colcon build or add to Docker build step.

FILES=$(grep -RIl --exclude-dir=install --exclude-dir=build --exclude-dir=.git "BestAvailable" . || true)
if [ -z "${FILES}" ]; then
  echo "[INFO] No BestAvailable symbols found."
  exit 0
fi

echo "[INFO] Patching BestAvailable in:"
echo "${FILES}"

# Patch in-place
for f in ${FILES}; do
  sed -i \
    -e 's/rclcpp::QoS::BestAvailable()/rclcpp::QoS(rclcpp::KeepLast(10)).reliability(rmw_qos_reliability_policy_t::RMW_QOS_POLICY_RELIABILITY_RELIABLE).durability(rmw_qos_durability_policy_t::RMW_QOS_POLICY_DURABILITY_VOLATILE)/g' \
    "$f"
done

echo "[OK] Patched. Rebuild the workspace."

