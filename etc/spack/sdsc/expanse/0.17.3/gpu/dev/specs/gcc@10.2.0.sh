#!/usr/bin/env bash

#SBATCH --job-name=gcc@10.2.0
#SBATCH --account=use300
#SBATCH --clusters=expanse
#SBATCH --partition=ind-gpu-shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=92G
#SBATCH --gpus=1
#SBATCH --time=01:00:00
#SBATCH --output=%x.o%j.%N

declare -xir UNIX_TIME="$(date +'%s')"
declare -xr LOCAL_TIME="$(date +'%Y%m%dT%H%M%S%z')"

declare -xr LOCAL_SCRATCH_DIR="/scratch/${USER}/job_${SLURM_JOB_ID}"

declare -xr JOB_SCRIPT="$(scontrol show job ${SLURM_JOB_ID} | awk -F= '/Command=/{print $2}')"
declare -xr JOB_SCRIPT_MD5="$(md5sum ${JOB_SCRIPT} | awk '{print $1}')"
declare -xr JOB_SCRIPT_SHA256="$(sha256sum ${JOB_SCRIPT} | awk '{print $1}')"
declare -xr JOB_SCRIPT_NUMBER_OF_LINES="$(wc -l ${JOB_SCRIPT} | awk '{print $1}')"

declare -xr SCHEDULER_NAME='slurm'
declare -xr SCHEDULER_MAJOR='23'
declare -xr SCHEDULER_MINOR='02'
declare -xr SCHEDULER_REVISION='7'
declare -xr SCHEDULER_VERSION="${SCHEDULER_MAJOR}.${SCHEDULER_MINOR}.${SCHEDULER_REVISION}"
declare -xr SCHEDULER_MODULE="${SCHEDULER_NAME}/${SLURM_CLUSTER_NAME}/${SCHEDULER_VERSION}"

declare -xr SPACK_MAJOR='0'
declare -xr SPACK_MINOR='17'
declare -xr SPACK_REVISION='3'
declare -xr SPACK_VERSION="${SPACK_MAJOR}.${SPACK_MINOR}.${SPACK_REVISION}"
declare -xr SPACK_INSTANCE_NAME='gpu'
declare -xr SPACK_INSTANCE_VERSION='dev'
declare -xr SPACK_INSTANCE_DIR='/home/mkandes/software/spack/repos/mkandes/spack'

declare -xr TMPDIR="${LOCAL_SCRATCH_DIR}/spack-stage"
declare -xr TMP="${TMPDIR}"

declare -xr SPACK_PACKAGE='gcc@10.2.0'
declare -xr SPACK_COMPILER='gcc@8.5.0'
declare -xr SPACK_VARIANTS='~binutils ~bootstrap ~graphite ~nvptx ~piclibs ~strip'
declare -xr SPACK_DEPENDENCIES=''
declare -xr SPACK_SPEC="${SPACK_PACKAGE} % ${SPACK_COMPILER} ${SPACK_VARIANTS} ${SPACK_DEPENDENCIES}"

echo "${UNIX_TIME} ${LOCAL_TIME} ${SLURM_JOB_ID} ${JOB_SCRIPT_MD5} ${JOB_SCRIPT_SHA256} ${JOB_SCRIPT_NUMBER_OF_LINES} ${JOB_SCRIPT}"
cat  "${JOB_SCRIPT}"

module purge
module load "${SCHEDULER_MODULE}"
module list
. "${SPACK_INSTANCE_DIR}/share/spack/setup-env.sh"
printenv

mkdir -p "${TMPDIR}"

spack config get compilers  
spack config get config  
spack config get mirrors
spack config get modules
spack config get packages
spack config get repos
spack config get upstreams

time -p spack spec --long --namespaces --types --reuse "$(echo ${SPACK_SPEC})"
if [[ "${?}" -ne 0 ]]; then
  echo 'ERROR: spack concretization failed.'
  exit 1
fi

time -p spack install --jobs "${SLURM_CPUS_PER_TASK}" --fail-fast --yes-to-all --reuse "$(echo ${SPACK_SPEC})"
if [[ "${?}" -ne 0 ]]; then
  echo 'ERROR: spack install failed.'
  exit 1
fi

sed -i "s|PATH_TO_GCC_10_2_0|$(spack location -i 'gcc@10.2.0')/bin/gcc|g" "${SPACK_INSTANCE_DIR}/etc/spack/compilers.yaml"
sed -i "s|PATH_TO_G++_10_2_0|$(spack location -i 'gcc@10.2.0')/bin/g++|g" "${SPACK_INSTANCE_DIR}/etc/spack/compilers.yaml"
sed -i "s|PATH_TO_GFORTRAN_10_2_0|$(spack location -i 'gcc@10.2.0')/bin/gfortran|g" "${SPACK_INSTANCE_DIR}/etc/spack/compilers.yaml"
sed -i "s|PATH_TO_GFORTRAN_10_2_0|$(spack location -i 'gcc@10.2.0')/bin/gfortran|g" "${SPACK_INSTANCE_DIR}/etc/spack/compilers.yaml"
