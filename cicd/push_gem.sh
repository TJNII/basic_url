#!/bin/bash
# Pulled out of the Makefile because Make's variable handling is screwball.

set -euo pipefail

out_version=$(./cicd/current_gem_version.sh)
out_file="out/basic_url.$(./cicd/current_gem_version.sh).gem"

gem push --otp "${out_file}"
git tag "${out_version}"
