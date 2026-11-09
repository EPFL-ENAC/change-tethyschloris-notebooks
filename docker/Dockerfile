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

USER ${NB_USER}
WORKDIR /home/jovyan/work
