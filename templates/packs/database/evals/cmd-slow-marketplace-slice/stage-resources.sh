#!/bin/bash
# Copies this case's read-only fixture files into the run's empty workspace, so the prompt's
# "resources directory" exists where the agent looks (context.add_dirs grants read access only;
# it does not place the files in the working directory).
set -eu
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -R "$here/resources" ./resources
