SUBROUTINE read_field

  !==========================================================================
  !
  ! Purpose
  ! -------
  !
  ! Read test model output to advect trajectories.
  ! Will be called by the loop each time step.
  !
  ! Method
  ! ------
  !
  ! Read velocities and optionally some tracers from netCDF files and
  ! update velocity fields for TRACMASS.
  !
  ! Updates the variables:
  !   uflux and vflux
  ! ==========================================================================


   USE mod_precdef
   USE mod_param
   USE mod_vel
   USE mod_time
   USE mod_grid
   USE mod_getfile
   USE mod_tracervars
   USE mod_tracers
   USE mod_calendar
   USE mod_swap

   USE netcdf

   IMPLICIT none

   INTEGER        :: kk, itrac

   REAL(DP), ALLOCATABLE, DIMENSION(:,:,:)  :: tmp3d
   CHARACTER (len=200)                      :: fieldFile, dateprefix

   ! Reassign the time index of uflux and vflux, dzt, dzdt, hs, ...
   CALL swap_time()

   ! Data files
   dateprefix = ' '

   ! Reading 3-time step variables
   ! In this case: hs and zstot
   ! ===========================================================================
   IF (ints == 0) THEN

     ! 1 - Past
     IF (loopYears) THEN

       nctstep = prevMon
       IF (l_onestep) nctstep = 1

       dateprefix = filledFileName(dateFormat, prevYear, prevMon, prevDay)

       fieldFile = TRIM(physDataDir)//TRIM(physPrefixForm)//TRIM(dateprefix)//TRIM(tGridName)//TRIM(fileSuffix)
       hs(1:imt,1:jmt,-1) = get2DfieldNC(fieldFile, hs_name,[imindom,jmindom,nctstep,1],[imt,jmt,1,1,1])
       hs(imt+1,:,-1)     = hs(1,:,-1)

     END IF

     ! 2 - Present
     nctstep = currMon
     IF (l_onestep) nctstep = 1

     dateprefix = filledFileName(dateFormat, currYear, currMon, currDay)

     fieldFile = TRIM(physDataDir)//TRIM(physPrefixForm)//TRIM(dateprefix)//TRIM(tGridName)//TRIM(fileSuffix)
     hs(1:imt,1:jmt,0) = get2DfieldNC(fieldFile, hs_name,[imindom,jmindom,nctstep,1],[imt,jmt,1,1])
     hs(imt+1,:,0)     = hs(1,:,0)

     WHERE (SUM(dzt(:,:,:,2),3) /= 0)
          zstot(1:imt,1:jmt,-1) = hs(1:imt,1:jmt,-1)/SUM(dzt(:,:,:,2),3) + 1
          zstot(1:imt,1:jmt, 0) = hs(1:imt,1:jmt, 0)/SUM(dzt(:,:,:,2),3) + 1
     ELSEWHERE
          zstot(:,:,-1) = 0.d0
          zstot(:,:, 0) = 0.d0
     END WHERE     

   END IF

   ! 3 - Future
   IF (ints<intrun-1 .OR. loopYears) THEN

     nctstep = nextMon
     IF (l_onestep) nctstep = 1

     dateprefix = filledFileName(dateFormat, nextYear, nextMon, nextDay)

     fieldFile = TRIM(physDataDir)//TRIM(physPrefixForm)//TRIM(dateprefix)//TRIM(tGridName)//TRIM(fileSuffix)
     hs(1:imt,1:jmt,1) = get2DfieldNC(fieldFile, hs_name,[imindom,jmindom,nctstep,1],[imt,jmt,1,1])
     hs(imt+1,:,1)     = hs(1,:,1)

   END IF

   ! Calculate SSH/depth
   WHERE (SUM(dzt(:,:,:,2),3) /= 0)
        zstot(1:imt,1:jmt,1)  = hs(1:imt,1:jmt,1)/SUM(dzt(:,:,:,2),3) + 1
   ELSEWHERE
        zstot(:,:,1) = 0.d0
   END WHERE

   WHERE (SUM(dzu(:,:,:,2),3) /= 0)
        zstou(1:imt,1:jmt) = 0.5*(hs(1:imt,1:jmt,0)+hs(2:imt+1,1:jmt,0))/SUM(dzu(:,:,:,2),3) + 1
   ELSEWHERE
        zstou = 0.d0
   END WHERE


   WHERE (SUM(dzv(:,1:jmt-1,:,2),3) /= 0)
        zstov(1:imt,1:jmt-1) = 0.5*(hs(1:imt,1:jmt-1,0)+hs(1:imt,2:jmt,0))/SUM(dzv(:,1:jmt-1,:,2),3) + 1
   ELSEWHERE
        zstov = 0.d0
   END WHERE

   ! Reading 2-time step variables
   ! In this case: velocities and tracers
   ! ===========================================================================
   ALLOCATE(tmp3d(imt,jmt,km))

   nctstep = currMon
   IF (l_onestep) nctstep = 1

   dateprefix = filledFileName(dateFormat, currYear, currMon, currDay)

   fieldFile = TRIM(physDataDir)//TRIM(physPrefixForm)//TRIM(dateprefix)//TRIM(uGridName)//TRIM(fileSuffix)
   uvel(1:imt,1:jmt,km:1:-1) = get3DfieldNC(fieldFile, ueul_name,[imindom,jmindom,1,nctstep],[imt,jmt,km,1],'st')

   IF (usgs_name/='') THEN
     tmp3d(1:imt,1:jmt,km:1:-1)  = get3DfieldNC(fieldFile, usgs_name,[imindom,jmindom,1,nctstep],[imt,jmt,km,1],'st')
     uvel(1:imt,1:jmt,1:km) = uvel(1:imt,1:jmt,1:km) + tmp3d(1:imt,1:jmt,1:km)
   END IF

   fieldFile = TRIM(physDataDir)//TRIM(physPrefixForm)//TRIM(dateprefix)//TRIM(vGridName)//TRIM(fileSuffix)
   vvel(1:imt,1:jmt,km:1:-1) = get3DfieldNC(fieldFile, veul_name,[imindom,jmindom,1,nctstep],[imt,jmt,km,1],'st')

   IF (vsgs_name/='') THEN
     tmp3d(1:imt,1:jmt,km:1:-1) = get3DfieldNC(fieldFile, vsgs_name,[imindom,jmindom,1,nctstep],[imt,jmt,km,1],'st')
     vvel(1:imt,1:jmt,1:km) = vvel(1:imt,1:jmt,1:km) + tmp3d(1:imt,1:jmt,1:km)
   END IF

   !! Tracers
   IF (l_tracers) THEN

     DO itrac = 1, numtracers

        ! Make sure the data array is empty
        tmp3d(:,:,:) = 0.d0

        IF (tracers(itrac)%action == 'read') THEN

            ! Read the tracer from a netcdf file
            fieldFile = TRIM(physDataDir)//TRIM(physPrefixForm)//TRIM(dateprefix)//TRIM(tGridName)//TRIM(fileSuffix)
            IF (tracers(itrac)%dimension == '3D') THEN
                tmp3d(1:imt,1:jmt,km:1:-1) = get3DfieldNC(fieldFile, tracers(itrac)%varname,[imindom,jmindom,1,nctstep] &
                          ,[imt,jmt,km,1],'st')
            ELSE IF (tracers(itrac)%dimension == '2D') THEN
                tmp3d(1:imt,1:jmt,1) = get2DfieldNC(fieldFile, tracers(itrac)%varname,[imindom,jmindom,nctstep,1] &
                                        ,[imt,jmt,1,1])
            END IF

        ELSE IF (tracers(itrac)%action == 'compute') THEN

            ! Compute the tracer from a function defined in mod_tracer.F90
            CALL compute_tracer(tracers(itrac)%name, tmp3d(1:imt,1:jmt,1:km))

        ELSE
            PRINT '(A34,I4)', 'No action defined for this tracer:', itrac
            STOP 10
        END IF

        ! Store the information
        IF (tracers(itrac)%dimension == '3D') THEN
          tracers(itrac)%data(:,1:jmt,:,2) = tmp3d(:,:,:)
        ELSE IF (tracers(itrac)%dimension == '2D') THEN
          tracers(itrac)%data(:,1:jmt,1,2) = tmp3d(:,:,1)
        END IF

     END DO
   END IF

   ! ===========================================================================

   ! uflux and vflux computation
   FORALL (kk = 1:km) uflux(:,:,kk,2)     = uvel(:,:,kk)*dyu(:,:)*dzu(:,:,kk,2)*zstou(:,:)
   FORALL (kk = 1:km) vflux(:,1:jmt,kk,2) = vvel(:,1:jmt,kk)*dxv(:,1:jmt)*dzv(:,1:jmt,kk,2)*zstov(:,:)

   ! dzdt calculation
   IF (ints == 0 .AND. ( loopYears .EQV..FALSE.)) THEN
      FORALL (kk = 1:km) dzdt(:,:,kk,2) = dzt(:,:,kk,2)*(zstot(:,:,1) - zstot(:,:,0))/tseas
   ELSE IF (ints == intrun-1 .AND. ( loopYears .EQV..FALSE.)) THEN
      FORALL (kk = 1:km) dzdt(:,:,kk,2) = dzt(:,:,kk,2)*(zstot(:,:,0) - zstot(:,:,-1))/tseas
   ELSE
      FORALL (kk = 1:km) dzdt(:,:,kk,2) = 0.5*dzt(:,:,kk,2)*(zstot(:,:,1) - zstot(:,:,-1))/tseas
   END IF

   !! Zero meridional flux at j=0 and j=jmt
   vflux(:,0  ,:,:) = 0.d0
   vflux(:,jmt,:,:) = 0.d0

   ! Reverse the sign of fluxes if trajectories are run backward in time.
   CALL swap_sign()


END SUBROUTINE read_field
