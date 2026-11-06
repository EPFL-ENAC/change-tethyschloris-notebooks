# Course image for Renku sessions: change-tethyschloris-notebooks
# The full repo (including the private TethysChloris.jl submodule) is provided
# by the build context: the GitHub Actions checkout authenticates the submodule
# with a PAT, so no credential is ever needed inside this Dockerfile.
# See .github/workflows/docker-image.yaml.

FROM quay.io/jupyter/julia-notebook:x86_64-julia-1.12.7

USER root

# Julia depot must be writable by the session user (jovyan, uid 1000)
RUN mkdir -p /opt/julia-depot \
    && chown -R jovyan:users /opt/julia-depot \
    && chown -R jovyan:users /home/jovyan

USER ${NB_UID}

ENV JULIA_DEPOT_PATH=/opt/julia-depot

USER root
COPY --chown=jovyan:users . /home/jovyan/change-tethyschloris-notebooks

USER ${NB_UID}
WORKDIR /home/jovyan/change-tethyschloris-notebooks

# Instantiate + precompile the full environment (incl. the path-sourced
# TethysChloris package) so student sessions start without compile delay.
RUN julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile(); \
    using TethysChloris; println("TethysChloris loaded OK")'

# Exercise data directories may be shadowed by Renku data-connector mounts;
# ensure the expected mount points exist with correct ownership.
RUN mkdir -p exercise1/data exercise2/data exercise2d/data \
    && chown -R jovyan:users /home/jovyan/change-tethyschloris-notebooks

USER ${NB_USER}
WORKDIR /home/jovyan/work
