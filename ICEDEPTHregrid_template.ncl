load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

begin
month=MONTH
icedepth1 = fbindirread("HEFF", 0, (/month-1,360,276/),"float")
icedepth = icedepth1(month-2,:,:)
icedepth=where(icedepth.gt.9999, -1e+30, icedepth)
;;;;;HPP ADD;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DATE_begin=DATE_BEG
year_0   = DATE_begin/1000000
month_0  = (DATE_begin-year_0*1000000)/10000
day_0    = (DATE_begin-year_0*1000000-month_0*10000)/100
hour_0   = DATE_begin-year_0*1000000-month_0*10000-day_0*100
minute = 0
second = 0
units  = "hours since 1-1-1 00:00:0.0"
opt_time = 0
cd_begin = cd_inv_calendar(year_0,month_0,day_0,hour_0,minute,second,units,opt_time)
n=29
time=new(n, double)
DATE=new(n,string,"No_FillValue")
do i=0,n-1,1
time(i)=(/cd_begin+3*i/)
end do
time@units = "hours since 1-1-1 00:00:0.0"
do i=0,n-1,1
utc_date = cd_calendar(time(i),0)

year   = tointeger(utc_date(:,0))
month  = tointeger(utc_date(:,1))
day    = tointeger(utc_date(:,2))
hour   = tointeger(utc_date(:,3))

date_str = sprinti("%0.4i", year)+"-"+sprinti("%0.2i", month)+"-"+sprinti("%0.2i", day)+"_"+sprinti("%0.2i", hour)+":00:00"
DATE(i)= date_str
end do
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
f1=addfile("heff.H2022.nc","r")
LAT    = f1->lat_scaler
LON    = f1->lon_scaler

icedepth@lat2d = LAT
icedepth@lon2d = LON
; printVarSummary(icedepth)

 Opt                   = True

;---"bilinear" is the default. "patch" and "conserve" are other options.
    Opt@InterpMethod      = "bilinear"        ;;---Change (maybe)

    Opt@WgtFileName       = "WRF_to_rect.nc"

    Opt@SrcGridLat        = LAT          ; source grid
    Opt@SrcGridLon        = LON
    Opt@SrcRegional       = True              ;;--Change (maybe)
    Opt@SrcInputFileName  = f1         ; optional, but good idea

Opt@DstFileName = "World1deg_SCRIP_bilinear.nc" ;-- destination file
Opt@DstGridType = "1deg" ;-- Destination grid
Opt@DstTitle = "World Grid 1x1-degree Resolution bilinear"
 ;-- destination title
Opt@DstLLCorner = (/-89.5d, 0.0d /) ;-- destination lower
 ;-- left corner
Opt@DstURCorner = (/ 89.5d, 359.0d /) ;-- destination upper


Opt@ForceOverwrite    = True
Opt@PrintTimings      = True
Opt@Debug             = True

var_regrid = ESMF_regrid(icedepth,Opt)     ; Do the regridding
; printVarSummary(var_regrid)
    ; print(max(var_regsrid))


FIELD_T          = "ICEDEPTH"
UNITS_T          = "m"
DESC_T           = "Sea ice thickness"
WPS_IM_root_name = "ICEDEPTH"

output_file_name = WPS_IM_root_name + ":" + DATE
earth_radius     = 6367.470

;;;;HPP ADD;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; printVarSummary(output_file_name)
; do i = 0,28
; opt                   = True
; opt@level = (/200100/)
; opt@projection        = 0
; opt@date              := DATE(i);+":00:00"
; opt@map_source        = "NSIDC"
; opt@startloc          = "SWCORNER"     ; 8 chars exact
; opt@startlon          = 0
; opt@startlat          = -90
; opt@deltalon          = 1
; opt@deltalat          = 1
; opt@is_wind_earth_relative = False
; wrf_wps_write_int(WPS_IM_root_name,FIELD_T,UNITS_T,DESC_T,var_regrid,opt)
; ;;;;HPP ADD;;;;;;;;;;
; delete(opt)

; end do
opt                   = True
opt@level = (/200100/)
opt@projection        = 0
opt@date              := DATE(ind_date);+":00:00"
opt@map_source        = "NSIDC"
opt@startloc          = "SWCORNER"     ; 8 chars exact
opt@startlon          = 0
opt@startlat          = -90
opt@deltalon          = 1
opt@deltalat          = 1
opt@is_wind_earth_relative = False
wrf_wps_write_int(WPS_IM_root_name,FIELD_T,UNITS_T,DESC_T,var_regrid,opt)
delete(opt)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
end
