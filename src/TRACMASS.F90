PROGRAM TRACMASS
  !!------------------------------------------------------------------------------
  !!
  !!       TRACMASS main program
  !!
  !!------------------------------------------------------------------------------

  USE mod_init
  USE mod_print
  USE mod_loop
  USE mod_calendar
  USE mod_domain
  USE mod_psi
  USE mod_stream
  USE mod_param
  USE mod_subdomain
  USE mod_tracers
  USE mod_tracervars
  USE mod_postprocess
  USE mod_postprocessvars

  IMPLICIT NONE

  CHARACTER(LEN=20) :: ARG1, ARG2

  CALL GET_COMMAND_ARGUMENT(1,ARG1)
  CALL GET_COMMAND_ARGUMENT(2,ARG2)

  ! Rerun tracmass (clean output)
  IF (ARG1 == 'rerun') l_rerun = .TRUE.

  ! Only run the postprocessing (summary or/and streamfunction)
  IF (ARG1 == 'norun') l_norun = .TRUE.

  IF (ARG1 == 'summary' .OR. ARG2 == 'summary') l_summary = .TRUE.

  ! ---------------------------------------------------------------------------

  ! Read namelist
  CALL init_namelist
  IF ( l_tracers ) CALL init_tracer

  ! Define the domain and allocate the arrays
  CALL init_subdomain
  CALL init_alloc

  ! Print general info
  CALL print_header_main

  ! TRACMASS (MAIN PROGRAM)
  ! ============================================================================
  IF (l_norun .EQV. .FALSE.) THEN

      ! Setup info
      CALL writesetup_main

      ! Setup grid
      CALL setup_grid

      ! Initialise calendar and seeding
      CALL init_calendar
      CALL init_seed

      ! Online computation of streamfunction
      IF (l_psi .AND. (l_offline .EQV. .FALSE.)) CALL init_stream()

      ! Read rerun
      IF (l_rerun) CALL read_rerun

      ! Open outfiles
      CALL open_outfiles

      ! Main loop
      CALL loop

      ! Close outfiles
      CALL close_outfiles

  END IF

  ! TRACMASS (POSTPROCESSING)
  ! ============================================================================

  IF ((l_psi .AND. l_offline) .OR. l_summary) THEN

      ! Print header
      IF (l_norun .EQV. .FALSE.) CALL print_header_postprocess()

      ! Re-open open_outfiles
      CALL reopen_outfiles()

      ! Offline computation of streamfunction
      IF (l_psi .AND. l_offline) CALL init_stream()

      ! Main postprocess module
      ! - Reads the units
      ! - Compute streamfunctions (if l_offline is TRUE)
      ! - Computes the summary (if l_summary is TRUE)
      CALL postprocessing()

      ! Close outfiles
      CALL close_outfiles

  ELSE IF (l_psi) THEN
      CALL compute_stream
  END IF

  ! Print end information
  CALL print_end_main()

END PROGRAM TRACMASS
