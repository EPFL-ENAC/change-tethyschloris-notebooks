# syntax=docker/dockerfile:1
ARG JULIA_TAG=x86_64-julia-1.12.7
FROM quay.io/jupyter/julia-notebook:${JULIA_TAG}

USER root
RUN mkdir -p /opt/julia-depot \
    && chown -R jovyan:users /opt/julia-depot \
    && chown -R jovyan:users /home/jovyan

USER ${NB_UID}
ENV JULIA_DEPOT_PATH=/opt/julia-depot \
    JULIA_PROJECT=/opt/tc-baked

USER root
COPY --chown=jovyan:users . /opt/tc-baked

USER ${NB_UID}
WORKDIR /opt/tc-baked

ENV JULIA_NUM_PRECOMPILE_TASKS=1 \
    JULIA_PKG_PRECOMPILE_AUTO=0

RUN --mount=type=secret,id=tethyschloris_pat,uid=1000,gid=1000 \
    git config --global url."https://x-access-token:$(cat /run/secrets/tethyschloris_pat)@github.com/".insteadOf "https://github.com/" \
    && julia --project=. --heap-size-hint=5G -e 'using Pkg; Pkg.instantiate()' \
    && git config --global --unset-all url."https://x-access-token:$(cat /run/secrets/tethyschloris_pat)@github.com/".insteadOf

RUN julia --project=. --heap-size-hint=5G -e 'using Pkg; Pkg.add("IJulia")'

RUN julia --project=. --heap-size-hint=5G -e 'using Pkg; Pkg.precompile()'

RUN julia --project=. --heap-size-hint=5G \
    -e 'using TethysChloris; println("TethysChloris loaded OK")'

USER root
RUN rm -rf /usr/local/share/jupyter/kernels/julia-1.12

USER ${NB_UID}
RUN julia -e 'using IJulia; installkernel("julia-1.12"; \
    env=Dict("JULIA_PROJECT"=>ENV["JULIA_PROJECT"]))'

USER ${NB_USER}
WORKDIR /home/jovyan/work
