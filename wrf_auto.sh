#!/bin/bash
#: wrf model automation script
#written by hpp

export WRF_EM_CORE=1
export WRF_NMM_CORE=0
export WRFIO_NCD_LARGE_FILE_SUPPORT=1
ulimit -s unlimited
#########################################
#            路径及起止时间              
#########################################
# BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
BASE_DIR=/thfs1/home/qx_hyt/hpp/code/
GFS_DIR=/thfs1/home/qx_hyt/hpp/data/GFS/2023051412/
WPS_GEOG=/thfs1/home/qx_hyt/hpp/model/PWRF/WPS-4.4/WPS_GEOG               
WPS_DIR=/thfs1/home/qx_hyt/hpp/model/PWRF/WPS-4.4/ 
WRF_DIR=/thfs1/home/qx_hyt/hpp/model/PWRF/WRF-4.3.3/run/    
start_time="2023-05-14_12:00:00"
end_time="2023-05-18_00:00:00"
run_hours=84
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
./link_grib.csh ${GFS_DIR}gfs* 
ln -sf ungrib/Variable_Tables/Vtable.GFS Vtable

cd $WPS_DIR && rm FILE:* geo_em*

 cat > geogrid.sh <<EOF
#!/bin/bash
yhrun -N 1 -n 56 -p thcp1 ./geogrid.exe >&geogrid.out
EOF
chmod a+x geogrid.sh
yhbatch -p thcp1 $WPS_DIR/geogrid.sh >& jobID_geogrid
pid_geogrid=$(awk '{print $4}' jobID_geogrid)
while true; do
    job_status=$(/usr/bin/yhqueue | grep "$pid_geogrid" | awk '{print $1}')
    if [ "$job_status" == "$pid_geogrid" ]; then
        sleep 60  # 作业完成时退出循环
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
pid_ungrib=$(awk '{print $4}' jobID_ungrib)
while true; do
    job_status=$(/usr/bin/yhqueue | grep "$pid_ungrib" | awk '{print $1}')
    if [ "$job_status" == "$pid_ungrib" ]; then
        sleep 60 
    else
        break  
    fi
done

 cat > metgrid.sh <<EOF
#!/bin/bash
yhrun -N 1 -n 1 -p thcp1 ./metgrid.exe >&metgrid.out
EOF
chmod a+x metgrid.sh
yhbatch -p thcp1 metgrid.sh  >& jobID_megrid
pid_metgrid=$(awk '{print $4}' jobID_megrid)
while true; do
    job_status=$(/usr/bin/yhqueue | grep "$pid_metgrid" | awk '{print $1}')
    if [ "$job_status" == "$pid_metgrid" ]; then
        sleep 60  
    else
        break 
    fi
done

# #########################################
# #             Running wrf  
# #########################################
cd $WRF_DIR
### 新建文件夹存放 wrf 输出
if [ -d wrf_output  ];then
  rm -rf wrf_output
else
  echo wrf_output no exist
fi

mkdir wrf_output
cd wrf_output 
cd ..

### 根据 namelist_template.input 编辑 namelist.input
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
patterns["OUTNAME"]="${WRF_DIR}wrf_output/wrfout_d<domain>_<date>"

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
cd $WRF_DIR && rm met* && ln -sf ${WPS_DIR}wps_output/met* .

cat > real.sh <<EOF
#!/bin/bash
yhrun -N 1 -n 1 -p thcp1 ./real.exe >&real.out
EOF
chmod a+x real.sh
yhbatch -p thcp1 real.sh  >& jobID_real
pid_real=$(awk '{print $4}' jobID_real)
while true; do
    job_status=$(/usr/bin/yhqueue | grep "$pid_real" | awk '{print $1}')
    if [ "$job_status" == "$pid_real" ]; then
        sleep 60  
    else
        break 
    fi
done

cat > wrf.sh <<EOF
#!/bin/bash
yhrun -N 1 -n 64 -p thcp1 ./wrf.exe >&wrf.out
EOF
chmod a+x wrf.sh
yhbatch -p thcp1 wrf.sh  >& jobID_wrf
pid_wrf=$(awk '{print $4}' jobID_wrf)
while true; do
    job_status=$(/usr/bin/yhqueue | grep "$pid_wrf" | awk '{print $1}')
    if [ "$job_status" == "$pid_wrf" ]; then
        sleep 60  
    else
        break 
    fi
done