#!/bin/bash
# Pulled out of the Makefile because Make's variable handling is screwball.

set -euo pipefail

./cicd/manage_version.sh -r

out_version=$(./cicd/current_gem_version.sh)
out_file="out/basic_url.$(./cicd/current_gem_version.sh).gem"

gem build -o "${out_file}"
