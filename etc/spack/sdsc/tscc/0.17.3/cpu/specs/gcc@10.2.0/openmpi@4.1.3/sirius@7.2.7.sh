#!/usr/bin/env bash

#SBATCH --job-name=sirius@7.2.7
#SBATCH --account=sys200
#SBATCH --partition=hotel
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --time=00:30:00
#SBATCH --output=%x.o%j.%N

declare -xr LOCAL_TIME="$(date +'%Y%m%dT%H%M%S%z')"
declare -xir UNIX_TIME="$(date +'%s')"

declare -xr SYSTEM_NAME='tscc'

declare -xr SPACK_VERSION='0.17.3'
declare -xr SPACK_INSTANCE_NAME='cpu'
declare -xr SPACK_INSTANCE_DIR="/cm/shared/apps/spack/${SPACK_VERSION}/${SPACK_INSTANCE_NAME}"

declare -xr SLURM_JOB_SCRIPT="$(scontrol show job ${SLURM_JOB_ID} | awk -F= '/Command=/{print $2}')"
declare -xr SLURM_JOB_MD5SUM="$(md5sum ${SLURM_JOB_SCRIPT})"

declare -xr SCHEDULER_MODULE='slurm'

echo "${UNIX_TIME} ${SLURM_JOB_ID} ${SLURM_JOB_MD5SUM} ${SLURM_JOB_DEPENDENCY}" 
echo ""

cat "${SLURM_JOB_SCRIPT}"

module purge
module load "${SCHEDULER_MODULE}"
module list
. "${SPACK_INSTANCE_DIR}/share/spack/setup-env.sh"

# unsatisfiable, conflicts are:
#  condition(578)
#  condition(6117)
#  condition(6123)
#  condition(6307)
#  dependency_condition(6307,"sirius","elpa")
#  dependency_type(6307,"link")
#  hash("elpa","ulsjc25y5o6tadhtnyhngghu2owfcdzp")
#  imposed_constraint(6307,"variant_set","elpa","openmp","True")
#  root("sirius")
#  variant_condition(578,"elpa","openmp")
#  variant_condition(6117,"sirius","elpa")
#  variant_condition(6123,"sirius","openmp")
#  variant_set("sirius","elpa","True")
#  variant_set("sirius","openmp","True")

# unsatisfiable, conflicts are:
#  condition(4419)
#  condition(6123)
#  condition(6321)
#  dependency_type(6321,"build")
#  hash("netlib-scalapack","admhf4d4lfmax5zwdsr7ojywil2yp367")
#  imposed_constraint("admhf4d4lfmax5zwdsr7ojywil2yp367","hash","openblas","fxzqxj3ljgy5sox5pq7e4sjtqrt75pqf")
#  imposed_constraint("fxzqxj3ljgy5sox5pq7e4sjtqrt75pqf","node","openblas")
#  imposed_constraint(6321,"variant_set","openblas","threads","openmp")
#  root("sirius")
#  variant_condition(4419,"openblas","threads")
#  variant_condition(6123,"sirius","openmp")
#  variant_set("sirius","openmp","True")

declare -xr SPACK_PACKAGE='sirius@7.2.7'
declare -xr SPACK_COMPILER='gcc@10.2.0'
declare -xr SPACK_VARIANTS='+apps ~boost_filesystem ~cuda ~elpa +fortran ~ipo ~magma +memory_pool ~nlcglib ~openmp +profiler ~python +scalapack +shared ~single_precision ~tests ~vdwxc'
declare -xr SPACK_DEPENDENCIES="^fftw@3.3.10/$(spack find --format '{hash:7}' fftw@3.3.10 % ${SPACK_COMPILER} ~mpi ~openmp) ^gsl@2.7/$(spack find --format '{hash:7}' gsl@2.7 % ${SPACK_COMPILER}) ^hdf5@1.10.7/$(spack find --format '{hash:7}' hdf5@1.10.7 % ${SPACK_COMPILER} ~mpi) ^python@3.8.12/$(spack find --format '{hash:7}' python@3.8.12 % ${SPACK_COMPILER}) ^netlib-scalapack@2.1.0/$(spack find --format '{hash:7}' netlib-scalapack@2.1.0 % ${SPACK_COMPILER} ^openmpi@4.1.3)"
declare -xr SPACK_SPEC="${SPACK_PACKAGE} % ${SPACK_COMPILER} ${SPACK_VARIANTS} ${SPACK_DEPENDENCIES}"

printenv

spack config get compilers
spack config get config  
spack config get mirrors
spack config get modules
spack config get packages
spack config get repos
spack config get upstreams

spack --show-cores=minimized spec --long --namespaces --types "${SPACK_SPEC}"
if [[ "${?}" -ne 0 ]]; then
  echo 'ERROR: spack concretization failed.'
  exit 1
fi

time -p spack install --jobs "${SLURM_CPUS_PER_TASK}" --fail-fast --yes-to-all "${SPACK_SPEC}"
if [[ "${?}" -ne 0 ]]; then
  echo 'ERROR: spack install failed.'
  exit 1
fi

spack module lmod refresh --delete-tree -y

sbatch --dependency="afterok:${SLURM_JOB_ID}" 'sirius@6.5.7.sh'

sleep 20
