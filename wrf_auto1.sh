#!/usr/bin/env bash
#: wrf model automation script

export WRF_EM_CORE=1
export WRF_NMM_CORE=0
export WRFIO_NCD_LARGE_FILE_SUPPORT=1
ulimit -s unlimited

# 脚本所在目录
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 路径及变量定义
INIT_DATE=`date +%Y%m%d`                       # 模拟开始的时间
INIT_TIME='12'                                 # 模拟的小时数
NCORE=90                                       # 模拟使用的核数
GFS_DIR=/disk1/quamrul/GFS_Data                # gfs 所在目录
WRF_DIR=/disk1/quamrul/WRF413/WRF/run          # wrf run 所在目录
# ARWPOST_DIR=/disk1/quamrul/WRF413/ARWpost      # arwpost directory
WPS_DIR=/disk1/quamrul/WRF413/WPS              # wps 所在目录
# LOG_DIR=/disk1/quamrul/logs                    # log output directory
# DEBUG_LOG=$LOG_DIR/debug_12.log                # debug log location
# PERF_LOG=$LOG_DIR/perf_12.log                  # perf log location
# DOWN_LOG=$LOG_DIR/gfs_down_12.log              # gfs data download log

# download-gfs-data

# cd $GFS_DIR

# echo "::started gfs download @ `date`" >> $DEBUG_LOG

# # download gfs data (recursively wait) 
# python3 $BASE_DIR/recursive_download_gfs.py $INIT_DATE $INIT_TIME

# echo "::end gfs download @ `date`" >> $DEBUG_LOG

# # change configuration files [always for 10 day]
# python3 $BASE_DIR/namelist_editor.py $INIT_DATE $INIT_TIME


# 删除上一案例数据
cd $WPS_DIR
# rm GRIBFILE*
rm met_em.d01*
rm GFS*

# link gfs grib 
./link_grib.csh ${GFS_DIR}/${INIT_DATE}${INIT_TIME}/gfs* ./

# 运行 geogrid+ungrib+metgrid
./geogrid.exe
./ungrib.exe
./metgrid.exe


cd $WRF_DIR

#删除上一案例
rm ./met_em_d01*

#链接初始场文件并运行  real.exe
ln -sf $WPS_DIR/met_em.d01* ./
./real.exe

# drop caches before running wrf
# sudo $BASE_DIR/drop_memcache.sh > $PERF_LOG

# disable ASLR and NUMA Balancing
# sudo $BASE_DIR/disable_aslr_numabal.sh >> $PERF_LOG

# configure cpu idle state & frequency govornor
# sudo cpupower idle-set -d 2 >> $PERF_LOG
# sudo cpupower frequency-set -g performance >> $PERF_LOG

# 运行 wrf.exe
echo "::started wrf.exe @ `date` - ${NCORE} core" >> $DEBUG_LOG

mpirun.mpich -np $NCORE ./wrf.exe

echo "::end wrf.exe     @ `date`" >> $DEBUG_LOG


# revert to initial cpu state
# sudo cpupower idle-set -e 2 >> $PERF_LOG
# sudo cpupower frequency-set -g ondemand >> $PERF_LOG

# wrf data postprocessing
# cd $ARWPOST_DIR
# ./ARWpost.exe

# >> do data processing here <<


# again drop cache to clean the system at the end of run
# sudo $BASE_DIR/drop_memcache.sh >> $PERF_LOG


# file checking and cleanup
