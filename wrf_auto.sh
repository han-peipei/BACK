#!/bin/bash
#: wrf model automation script

export LD_LIBRARY_PATH="/thfs1/software/loginnode/usr/lib/aarch64-linux-gnu/:/thfs1/software/netcdf/4.8.0-gcc9.3.0-mpi-x/lib/:/thfs1/software/hdf5/1.12.0-gcc9.3.0-mpi-x/lib/:/thfs1/software/hdf5/1.12.0-gcc9.3.0-mpi-x/lib/"
export ESMF_DIR=/thfs1/software/spack/deb/liyueyan/linux-ubuntu20.04-aarch64/gcc-7.5.0/esmf-8.0.1-c2b4klc
export PATH=$PATH:$ESMF_DIR/bin
ulimit -c unlimited
#########################################
#            路径及起止时间              
#########################################
# BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# end_time=$(date -d yesterday +%Y-%m-%d)"_18:00:00"
# start_time="2023-05-14_12:00:00"
# end_time="2023-05-18_00:00:00"
start_time=$(date -d yesterday +%Y-%m-%d)"_12:00:00"
end_time=$(date -d yesterday +%Y-%m-%d --date="+3 day")"_00:00:00"
run_hours=84
BASE_DIR=/thfs1/home/qx_hyt/PWRF/hpp/wrf_auto
GFS_DIR=/thfs1/software/WRFV4.0DATA/GFS/0p50/gfs.$(date -d yesterday +%Y%m%d)"12"/
WPS_GEOG=/thfs1/home/qx_hyt/hpp/model/PWRF/WPS-4.4/WPS_GEOG               
WPS_DIR=/thfs1/home/qx_hyt/PWRF/WPS-4.4/ 
WRF_DIR=/thfs1/home/qx_hyt/PWRF/WRF-4.3.3/run/ 
ncl=/thfs1/software/spack/deb/liyueyan/linux-ubuntu20.04-aarch64/gcc-7.5.0/ncl-6.6.2-53z6sd4/bin 
set -x; exec 2>$BASE_DIR/logfile
# #########################################
# #             Running wps  
# #########################################
cd $WPS_DIR
## 新建文件夹存放 wps 输出
if [ -d wps_output  ];then
  rm -rf wps_output
else
  echo wps_output no exist
fi
if [ -d Vtable  ];then
  rm Vtable
else
  echo Vtable no exist
fi
mkdir wps_output

### 根据 namelist_template.wps 编辑 namelist.wps
declare -A patterns
patterns["INPUT_START_DATE"]=$start_time
patterns["INPUT_END_DATE"]=$end_time
patterns["GEOG_DATA"]=$WPS_GEOG
patterns["PREFIX"]='FILE'
patterns["METGRID_PATH"]=${WPS_DIR}wps_output
sed_cmd=""
for key in "${!patterns[@]}"; do
  old_pattern="$key"
  new_pattern="${patterns[$key]}"
  sed_cmd+=" -e s|$old_pattern|$new_pattern|g"
done
input_file=${BASE_DIR}/namelist_template.wps
output_file="namelist.wps"
sed $sed_cmd < "$input_file" > "$output_file"

### 运行 wps
cd $WPS_DIR && rm FILE:* geo_em* ICEDEPTH:* SST:* PFILE:* GRIBFILE* metgrid.log.0* geogrid.log.0* slurm-* 

./link_grib.csh ${GFS_DIR}gfs* 
ln -sf ungrib/Variable_Tables/Vtable.GFS Vtable

 cat > geogrid.sh <<EOF
#!/bin/bash
yhrun -N 1 -n 60 -p thcp1 ./geogrid.exe >&geogrid.out
EOF
chmod a+x geogrid.sh
yhbatch -N 1 -n 60 -p thcp1 $WPS_DIR/geogrid.sh >& jobID_geogrid
pid_geogrid=$(awk '{print $4}' jobID_geogrid)
while true; do
    job_status=$(/usr/bin/yhqueue | grep "$pid_geogrid" | awk '{print $1}')
    if [ "$job_status" == "$pid_geogrid" ]; then
        sleep 100  
    else
        break  # 作业完成或其他状态时退出循环
    fi
done

 cat > ungrib.sh <<EOF
#!/bin/bash
yhrun -N 1 -n 1 -p thcp1 ./ungrib.exe >&ungrib.out
EOF
chmod a+x ungrib.sh
yhbatch -p thcp1 $WPS_DIR/ungrib.sh >& jobID_ungrib
pid_ungrib_1=$(awk '{print $4}' jobID_ungrib)
while true; do
    job_status=$(/usr/bin/yhqueue | grep "$pid_ungrib_1" | awk '{print $1}')
    if [ "$job_status" == "$pid_ungrib_1" ]; then
        sleep 100 
    else
        break  
    fi
done
### 根据 namelist_template.wps 编辑 namelist.wps
declare -A patterns
patterns["PREFIX"]='SST'
sed_cmd=""
for key in "${!patterns[@]}"; do
  old_pattern="$key"
  new_pattern="${patterns[$key]}"
  sed_cmd+=" -e s|$old_pattern|$new_pattern|g"
done
input_file=${BASE_DIR}/namelist_template.wps
output_file="namelist.wps"
sed $sed_cmd < "$input_file" > "$output_file"

yhbatch -p thcp1 $WPS_DIR/ungrib.sh >& jobID_ungrib
pid_ungrib_2=$(awk '{print $4}' jobID_ungrib)
while true; do
    job_status=$(/usr/bin/yhqueue | grep "$pid_ungrib_2" | awk '{print $1}')
    if [ "$job_status" == "$pid_ungrib_2" ]; then
        sleep 100 
    else
        break  
    fi
done
cd $WPS_DIR 
### 根据 ICEDEPTHregrid_template.ncl 编辑 ICEDEPTHregrid.ncl
declare -A patterns
patterns["MONTH"]=${start_time:5:2}
patterns["HEFF"]=heff${start_time:0:4}${start_time:5:2}.H2023
patterns["DATE_BEG"]=${start_time:0:4}${start_time:5:2}${start_time:8:2}${start_time:11:2}

sed_cmd=""
for key in "${!patterns[@]}"; do
  old_pattern="$key"
  new_pattern="${patterns[$key]}"
  sed_cmd+=" -e s|$old_pattern|$new_pattern|g"
done
input_file=${BASE_DIR}/ICEDEPTHregrid_template.ncl
output_file="ICEDEPTHregrid.ncl"
sed $sed_cmd < "$input_file" > "$output_file"

cd $WPS_DIR 
for ((i=0; i<=run_hours/3; i++)); do
  $ncl/ncl -Q ind_date=$i ./ICEDEPTHregrid.ncl >ice.log
done
#&& ncl ICEDEPTHregrid.ncl >ice.log

 cat > metgrid.sh <<EOF
#!/bin/bash
yhrun -N 1 -n 60 -p thcp1 ./metgrid.exe >&metgrid.out
EOF
chmod a+x metgrid.sh
yhbatch -N 1 -n 60 -p thcp1 metgrid.sh  >& jobID_megrid
pid_metgrid=$(awk '{print $4}' jobID_megrid)
while true; do
    job_status=$(/usr/bin/yhqueue | grep "$pid_metgrid" | awk '{print $1}')
    if [ "$job_status" == "$pid_metgrid" ]; then
        sleep 100  
    else
        break 
    fi
done

#########################################
#             Running wrf  
#########################################
cd $BASE_DIR

### 新建文件夹存放 wrf 输出
if [ -d ${start_time:0:4}{start_time:5:2}{start_time:8:2}  ];then
  rm -rf ${start_time:0:4}${start_time:5:2}${start_time:8:2}
else
  echo ${start_time:0:4}${start_time:5:2}${start_time:8:2} no exist
fi

mkdir ${start_time:0:4}${start_time:5:2}${start_time:8:2}
cd $WRF_DIR && rm wrfbdy* wrfinput* wrflowinp*

## 根据 namelist_template.input 编辑 namelist.input
declare -A patterns
patterns["RUN_HOURS"]=$run_hours
patterns["START_YEAR_1"]=${start_time:0:4}
patterns["START_MONTH_1"]=${start_time:5:2}
patterns["START_DAY_1"]=${start_time:8:2}
patterns["START_HOUR_1"]=${start_time:11:2}
patterns["END_YEAR_1"]=${end_time:0:4}
patterns["END_MONTH_1"]=${end_time:5:2}
patterns["END_DAY_1"]=${end_time:8:2}
patterns["END_HOUR_1"]=${end_time:11:2}
patterns["OUTNAME"]="${BASE_DIR}/${start_time:0:4}${start_time:5:2}${start_time:8:2}/wrfout_d<domain>_<date>"

sed_cmd="s|<pattern_to_replace_1>|<replacement_text_1>|g"
for key in "${!patterns[@]}"; do
  old_pattern="$key"
  new_pattern="${patterns[$key]}"
  sed_cmd+=";s|$old_pattern|$new_pattern|g"
done
input_file=${BASE_DIR}/namelist_template.input
output_file="namelist.input"
sed "$sed_cmd" < "$input_file" > "$output_file"

### 运行 wrf
cd $WRF_DIR && rm met* 
ln -sf ${WPS_DIR}wps_output/met* .

cat > real.sh <<EOF
#!/bin/bash
yhrun -N 1 -n 60 -p thcp1 ./real.exe >&real.out
EOF
chmod a+x real.sh
yhbatch -N 1 -n 60 -p thcp1 real.sh  >& jobID_real
pid_real=$(awk '{print $4}' jobID_real)
while true; do
    job_status=$(/usr/bin/yhqueue | grep "$pid_real" | awk '{print $1}')
    if [ "$job_status" == "$pid_real" ]; then
        sleep 100  
    else
        break 
    fi
done

cat > wrf.sh <<EOF
#!/bin/bash
yhrun -N 2 -n 81 -p thcp1 ./wrf.exe >&wrf.out
EOF
chmod a+x wrf.sh
yhbatch -N 2 -n 81 -p thcp1 wrf.sh  >& jobID_wrf
pid_wrf=$(awk '{print $4}' jobID_wrf)
while true; do
    job_status=$(/usr/bin/yhqueue | grep "$pid_wrf" | awk '{print $1}')
    if [ "$job_status" == "$pid_wrf" ]; then
        sleep 300  
    else
        break 
    fi
done

#########################################
#                后处理  
#########################################
cd ${BASE_DIR}/${start_time:0:4}${start_time:5:2}${start_time:8:2}
rm -rf picture
mkdir picture
cd $BASE_DIR
declare -A patterns
patterns["DIR"]=${BASE_DIR}/${start_time:0:4}${start_time:5:2}${start_time:8:2}/
patterns["FILENAME"]=wrfout_d01_${start_time:0:4}-${start_time:5:2}-${start_time:8:2}_12:00:00
patterns["OUTPUT_ICEDEPTH"]=${BASE_DIR}/${start_time:0:4}${start_time:5:2}${start_time:8:2}/picture/wrfout_icedepth_winds_BJT_
patterns["OUTPUT_visibility"]=${BASE_DIR}/${start_time:0:4}${start_time:5:2}${start_time:8:2}/picture/wrfout_visibility_BJT_

sed_cmd="s|<pattern_to_replace_1>|<replacement_text_1>|g"
for key in "${!patterns[@]}"; do
  old_pattern="$key"
  new_pattern="${patterns[$key]}"
  sed_cmd+=";s|$old_pattern|$new_pattern|g"
done
input_file=${BASE_DIR}/wrfout_template.ncl
output_file="wrfout.ncl"
sed "$sed_cmd" < "$input_file" > "$output_file"

 cat > ncl.sh <<EOF
#!/bin/bash
yhrun -N 1 -n 10 -p thcp1 $ncl/ncl wrfout.ncl >wind.log
EOF
chmod a+x ncl.sh
yhbatch -N 1 -n 10 -p thcp1 $BASE_DIR/ncl.sh >& jobID_ncl_wind
pid_ncl=$(awk '{print $4}' jobID_ncl_wind)
while true; do
    job_status=$(/usr/bin/yhqueue | grep "$pid_ncl" | awk '{print $1}')
    if [ "$job_status" == "$pid_ncl" ]; then
        sleep 100  
    else
        break  # 作业完成或其他状态时退出循环
    fi
done
