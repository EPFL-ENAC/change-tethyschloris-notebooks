# Course image for Renku sessions: change-tethyschloris-notebooks
# The full repo (including the private TethysChloris.jl submodule) is provided
# by the build context: the GitHub Actions checkout authenticates the submodule
# with a PAT, so no credential is ever needed inside this Dockerfile.
# See .github/workflows/docker-image.yaml.

ARG JULIA_TAG=x86_64-julia-1.12.7
FROM quay.io/jupyter/julia-notebook:${JULIA_TAG}

USER root
RUN mkdir -p /opt/julia-depot \
    && chown -R jovyan:users /opt/julia-depot \
    && chown -R jovyan:users /home/jovyan

USER ${NB_UID}
ENV JULIA_DEPOT_PATH=/opt/julia-depot \
    JULIA_PROJECT=/home/jovyan/work/change-tethyschloris-notebooks

USER root
COPY --chown=jovyan:users . /home/jovyan/work/change-tethyschloris-notebooks
COPY --chown=jovyan:users TethysChloris.jl /opt/tc-seed/TethysChloris.jl

USER ${NB_UID}
WORKDIR /home/jovyan/work/change-tethyschloris-notebooks

ENV JULIA_NUM_PRECOMPILE_TASKS=1 \
    JULIA_PKG_PRECOMPILE_AUTO=0

RUN rm -f Manifest.toml && julia --project=. --heap-size-hint=5G \
    -e 'using Pkg; Pkg.instantiate()'

RUN julia --project=. --heap-size-hint=5G -e 'using Pkg; Pkg.add("IJulia")'

RUN julia --project=. --heap-size-hint=5G -e 'using Pkg; Pkg.precompile()'

RUN julia --project=. --heap-size-hint=5G \
    -e 'using TethysChloris; println("TethysChloris loaded OK")'

USER root
RUN rm -rf /usr/local/share/jupyter/kernels/julia-1.12

USER ${NB_UID}
RUN julia -e 'using IJulia; installkernel("julia-1.12"; \
    env=Dict("JULIA_PROJECT"=>ENV["JULIA_PROJECT"]))'

RUN mkdir -p exercise1/data exercise2/data exercise2d/data

USER ${NB_USER}
WORKDIR /home/jovyan/work
