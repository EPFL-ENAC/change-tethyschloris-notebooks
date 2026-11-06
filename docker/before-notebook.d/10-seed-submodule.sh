#!/bin/bash
# Renku clones linked repositories into the session working directory,
# shadowing the baked checkout; that clone lacks the private submodule
# and the Manifest. Restore both from the baked seed before Jupyter starts.
REPO=/home/jovyan/work/change-tethyschloris-notebooks
SEED=/opt/tc-seed

if [ -d "$REPO" ]; then
    if [ -z "$(ls -A "$REPO/TethysChloris.jl/src" 2>/dev/null)" ]; then
        cp -a "$SEED/TethysChloris.jl/." "$REPO/TethysChloris.jl/"
    fi
    if [ ! -f "$REPO/Manifest.toml" ] && [ -f "$SEED/Manifest.toml" ]; then
        cp "$SEED/Manifest.toml" "$REPO/Manifest.toml"
    fi
fi
