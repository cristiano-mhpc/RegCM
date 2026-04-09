!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
!
!    This file is part of ICTP RegCM.
!
!    Use of this source code is governed by an MIT-style license that can
!    be found in the LICENSE file or at
!
!         https://opensource.org/licenses/MIT.
!
!    ICTP RegCM is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
!
!::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

module mod_regcm_interface

  use mod_realkinds
  use mod_intkinds
  use mod_dynparam
  use mod_memutil
  use mod_stdio
  use mod_date
  use mod_service
  use mod_che_interface
  use mod_lm_interface
  use mod_atm_interface
  use mod_pbl_interface
  use mod_rad_interface
  use mod_runparams
  use mod_mppparam
  use mod_mpmessage
  use mod_ncio
  use mod_ncout
  use mod_output
  use mod_split
  use mod_bdycod
  use mod_init
  use mod_header
  use mod_params
  use mod_tendency
  use mod_service
  use mod_moloch
  use mod_ensemble
#ifdef CPL
  use mod_update, only: rcm_get, rcm_put
#endif
#ifdef OASIS
  use mod_oasis_interface
#endif
#ifdef TIMING_STUDY
#ifdef CLM45
  use mod_clm_regcm, only : t_cpl_a2l, t_cpl_l2a, t_clm_drv, n_clm_calls
  use mod_clm_decomp, only : get_proc_total
  use mod_clm_driver, only : t_clm_hyd1, t_clm_bio1, t_clm_urbanflux, &
                              t_clm_canopy, t_clm_bio2, t_clm_hyd2, t_clm_map2gcell
  use mod_clm_canopyfluxes, only : n_canopy_calls, canopy_pft_total, canopy_pft_iter_total, &
                                    canopy_iter_max, canopy_irrig_active_total, canopy_dense_total, &
                                    canopy_day_layers_total, canopy_ci_solve_total, &
                                    canopy_hybrid_iter_total, canopy_brent_total, &
                                    canopy_ci_func_eval_total
#endif
#endif
  use mpi
  implicit none

  private
  public :: RCM_initialize
  public :: RCM_run
  public :: RCM_finalize
  public :: atm_model

  real(rk8) :: extime

#ifdef TIMING_STUDY
  real(rk8) :: t_atm_moloch = 0.0_rk8
  real(rk8) :: t_wait_barrier = 0.0_rk8
#endif

  type atm_model
    character(len=5) :: model_name = 'RegCM'
    character(len=31) :: model_longname = 'The ICTP Regional Climate Model'
  end type atm_model

  data extime /0.0_rk8/
  contains

  subroutine RCM_initialize(mpiCommunicator)
    implicit none
    integer, intent(in), optional :: mpiCommunicator
    real(rkx), allocatable, dimension(:,:) :: rcemip_noise
    integer(ik4) :: ierr, k
    real(rkx) :: rnl
    !
    ! MPI Initialization
    !
    if (present(mpiCommunicator)) then
      call mpi_comm_dup(mpiCommunicator, mycomm, ierr)
      if ( ierr /= 0 ) then
        call fatal(__FILE__,__LINE__,'Cannot get communicator!')
      end if
    else
      call mpi_comm_dup(MPI_COMM_WORLD, mycomm, ierr)
      if ( ierr /= 0 ) then
        call fatal(__FILE__,__LINE__,'Cannot get communicator!')
      end if
    end if
    call mpi_comm_rank(mycomm, myid, ierr)
    if ( ierr /= 0 ) then
      call fatal(__FILE__,__LINE__,'mpi_comm_rank Failure!')
    end if
    call mpi_comm_size(mycomm, nproc, ierr)
    if ( ierr /= 0 ) then
      call fatal(__FILE__,__LINE__,'mpi_comm_size Failure!')
    end if
#ifdef OPENACC
    call setup_openacc(myid)
#endif
#ifndef MPI_SERIAL
#ifdef DEBUG
    call mpi_comm_set_errhandler(mycomm, mpi_errors_return, ierr)
    if ( ierr /= 0 ) then
      call fatal(__FILE__,__LINE__,'mpi_comm_set_errhandler Failure!')
    end if
#endif
#endif

    call whoami(myid)
    call setup_mesg(myid)

#ifdef DEBUG
    call activate_debug()
#endif
    !
    ! Read input global namelist
    !
    if ( myid == iocpu ) then
      call get_command_argument(0,value=prgname)
      call get_command_argument(1,value=namelistfile)
      call initparam(namelistfile, ierr)
      if ( ierr /= 0 ) then
        write ( 6, * ) 'Parameter initialization not completed'
        write ( 6, * ) 'Usage : '
        write ( 6, * ) '          ', trim(prgname), ' regcm.in'
        write ( 6, * ) ' '
        write ( 6, * ) 'Check argument and namelist syntax'
        write ( 6, * ) 'ERROR : ', ierr
        stop
      end if
    end if

    call broadcast_params

    call memory_init

    call header(myid,nproc)
#ifdef OASIS
    call oasisxregcm_header
#endif
    call set_nproc
    call setup_model_indexes

#ifdef DEBUG
    call start_debug()
#endif
    !
    ! Parameter Setup
    !
    call param
    !
    ! OASIS Setup
    !
#ifdef OASIS
    if ( ioasiscpl == 1 ) then
      !
      ! OASIS Variables Setup
      !
      call oasisxregcm_params
      !
      ! OASIS Definition Phase (grids, partitions, fields)
      !
      call oasisxregcm_def
    end if
#endif
    !
    ! Read IC and BC data.
    !
    if ( .not. ifrest ) then
      if ( irceideal /= 1 ) then
        call init_bdy
      end if
    end if
    !
    ! Initialize data (from IC or restart)
    !
    call init
    !
    ! Initialize split explicit scheme ( hydrostatic )
    !
    if ( idynamic == 1 ) call spinit
    !
    ! Setup the output files
    !
    call init_output_streams(do_parallel_netcdf_out)
    !
    ! Setup valid BC's
    !
    if ( irceideal == 1 ) then
      if ( lrcemip_perturb ) then
        allocate(rcemip_noise(njcross,nicross))
        if ( idynamic == 3 ) then
          do k = kz, kz - 5, -1
            rnl = mo_atm%t(jci1,ici1,k)
            rcemip_noise(:,:) = rnl
            rnl =  lrcemip_noise_level * (1.0 - (kz-k)/6.0_rkx)
            call randify(rcemip_noise,rnl,nicross,njcross)
            mo_atm%t(jce1:jce2,ice1:ice2,k) = rcemip_noise(jce1:jce2,ice1:ice2)
          end do
        else
          do k = kz, kz - 5, -1
            rnl = atm1%t(jci1,ici1,k)/sfs%psb(jci1,ici1)
            rcemip_noise(:,:) = rnl
            rnl =  lrcemip_noise_level * (1.0 - (kz-k)/6.0_rkx)
            call randify(rcemip_noise,rnl,nicross,njcross)
            atm1%t(jce1:jce2,ice1:ice2,k) = &
              rcemip_noise(jce1:jce2,ice1:ice2)*sfs%psb(jce1:jce2,ice1:ice2)
          end do
        end if
        deallocate(rcemip_noise)
      end if
      call output
    else
      call output
      call bdyval
    end if
    !
    ! Clean up and logging
    !
#ifdef DEBUG
    call time_print(6,'inizialization phase')
    call time_reset()
#endif
  end subroutine RCM_initialize
  !
  !=======================================================================
  !                                                                      !
  !     This routine runs RegCM model from specified starting (TimeStr)  !
  !     to ending (TimeEnd) time-steps.                                  !
  !                                                                      !
  !=======================================================================
  !
  subroutine RCM_run(timestr, timeend)
    implicit none
    real(rk8), intent(in) :: timestr   ! starting time-step
    real(rk8), intent(in) :: timeend   ! ending   time-step
#ifdef TIMING_STUDY
    real(rk8) :: t0ts
    integer(ik4) :: ierr
#endif

    do while ( extime >= timestr .and. extime < timeend )
      !
      ! Retrieve information from the driver
      !
#ifdef CPL
      if ( iocncpl == 1 .or. iwavcpl == 1 ) then
        if ( rcmtimer%integrating( ) ) then
          call rcm_get(myid)
        end if
      end if
#endif
      !
      ! Receive OASIS fields
      !
#ifdef OASIS
      if ( ioasiscpl == 1 ) then
        if ( oasis_sync_lag > 0 .and. int(extime,ik4) == 0 ) then
          call oasisxregcm_sync_wait(int(extime,ik4))
        end if
        call oasisxregcm_rcv_all(int(extime,ik4)+oasis_lag)
      end if
#endif
      !
      ! Compute tendencies
      !
      if ( idynamic == 3 ) then
#ifdef TIMING_STUDY
        t0ts = mpi_wtime()
#endif
        call moloch
#ifdef TIMING_STUDY
        t_atm_moloch = t_atm_moloch + (mpi_wtime() - t0ts)
#endif
      else
        call tend
      end if
      !
      ! Send OASIS fields
      !
#ifdef OASIS
      if ( ioasiscpl == 1 ) then
        call oasisxregcm_snd_all(int(extime,ik4)+oasis_lag)
        if ( oasis_sync_lag < 0 .and. rcmtimer%reached_endtime) then
          call oasisxregcm_sync_wait(int(extime,ik4))
        end if
      end if
#endif
      !
      ! Write output for this timestep if requested
      !
      call output
      !
      ! Boundary code
      !
      if ( .not. rcmtimer%reached_endtime ) then
        if ( alarm_in_bdy%act( ) ) then
          !
          ! Read in new boundary conditions
          !
          if ( irceideal /= 1 ) call bdyin
        end if
        !
        ! fill up the boundary values for xxb and xxa variables:
        !
        if ( irceideal /= 1 ) then
          call bdyval
        end if
      end if
      !
      ! Send information to the driver
      !
#ifdef CPL
      if ( iocncpl == 1 .or. iwavcpl == 1 ) then
        call rcm_put(myid)
      end if
#endif
      !
      ! Increment execution time and boundary time
      !
      extime = extime + real(dtsec,rk8)
      if ( debug_level > 3 ) then
        if ( myid == italk ) then
          write(6,'(a,a,f12.2)') 'Simulation time: ', rcmtimer%str( )
        end if
      end if

#ifdef TIMING_STUDY
      t0ts = mpi_wtime()
      call mpi_barrier(mycomm, ierr)
      t_wait_barrier = t_wait_barrier + (mpi_wtime() - t0ts)
#endif

    end do

#ifdef DEBUG
    call time_print(6,'evolution phase')
    call stop_debug()
#endif

  end subroutine RCM_run

  subroutine RCM_finalize
    implicit none
#ifdef TIMING_STUDY
    real(rk8) :: tloc, tmin, tmax, tsum
    integer(ik8) :: cmin, cmax, csum
    integer(ik4) :: ierr, irank
    integer(ik4) :: lndpts_local, idx_min, idx_max
    integer(ik4) :: ncells_local, nlunits_local, ncols_local, npfts_local
    integer(ik4) :: ncols_min, ncols_max, npfts_min, npfts_max
    integer(ik4) :: isum
    integer(ik4), allocatable :: lndpts_all(:)
    real(rk8), allocatable :: rank_clm_canopy(:)
    integer(ik8), allocatable :: rank_canopy_work(:), rank_canopy_pfts(:), rank_canopy_itmax(:)
    integer(ik8), allocatable :: rank_canopy_daylayers(:), rank_canopy_ci_solve(:)
    integer(ik8), allocatable :: rank_canopy_hybrid_iter(:), rank_canopy_brent(:)
    integer(ik8), allocatable :: rank_canopy_ci_eval(:)
#endif

    if ( myid == italk ) then
      write(stdout,*) 'Final time ', trim(rcmtimer%str( )), ' reached.'
    end if

    call close_icbc
    if ( ichem == 1 ) call close_chbc( )
    call dispose_output_streams
    call checktime(myid,trim(dirout)//pthsep//trim(prestr)//trim(domname)// &
                       '.'//tochar10(lastout),'final timeslice')
#ifdef CLM
    call t_prf('timing_all',mpicom)
    call t_finalizef()
#endif

#ifdef TIMING_STUDY
    if ( myid == italk ) then
      write(stdout,*) 'TIMING_STUDY: min avg max across ranks (seconds)'
    end if

    tloc = t_atm_moloch
    call mpi_reduce(tloc, tmin, 1, mpi_double_precision, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(tloc, tmax, 1, mpi_double_precision, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(tloc, tsum, 1, mpi_double_precision, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,f12.3))') 'TIMING_STUDY atm_moloch    :', &
                                      tmin, tsum/real(nproc,rk8), tmax
    end if

    tloc = t_wait_barrier
    call mpi_reduce(tloc, tmin, 1, mpi_double_precision, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(tloc, tmax, 1, mpi_double_precision, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(tloc, tsum, 1, mpi_double_precision, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,f12.3))') 'TIMING_STUDY wait_barrier  :', &
                                      tmin, tsum/real(nproc,rk8), tmax
    end if

#ifdef CLM45
    call get_proc_total(ncells_local, nlunits_local, ncols_local, npfts_local)

    lndpts_local = lndcomm%linear_npoint_sg(myid+1)
    if ( myid == italk ) then
      allocate(lndpts_all(nproc))
    end if
    call mpi_gather(lndpts_local, 1, mpi_integer, lndpts_all, 1, mpi_integer, &
                    italk, mycomm, ierr)
    if ( myid == italk ) then
      idx_min = minloc(lndpts_all, dim=1)
      idx_max = maxloc(lndpts_all, dim=1)
      write(stdout,'(a,3(1x,i12),a,i6,a,i6)') 'TIMING_STUDY lnd_points   :', &
        minval(lndpts_all), nint(real(sum(lndpts_all),rk8)/real(nproc,rk8)), &
        maxval(lndpts_all), ' min_rank=', idx_min-1, ' max_rank=', idx_max-1
      deallocate(lndpts_all)
    end if

    call mpi_reduce(ncols_local, ncols_min, 1, mpi_integer, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(ncols_local, ncols_max, 1, mpi_integer, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(ncols_local, isum, 1, mpi_integer, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,i12))') 'TIMING_STUDY clm_ncols    :', &
                                  ncols_min, isum/nproc, ncols_max
    end if

    call mpi_reduce(npfts_local, npfts_min, 1, mpi_integer, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(npfts_local, npfts_max, 1, mpi_integer, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(npfts_local, isum, 1, mpi_integer, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,i12))') 'TIMING_STUDY clm_npfts    :', &
                                  npfts_min, isum/nproc, npfts_max
    end if

    tloc = t_cpl_a2l
    call mpi_reduce(tloc, tmin, 1, mpi_double_precision, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(tloc, tmax, 1, mpi_double_precision, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(tloc, tsum, 1, mpi_double_precision, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,f12.3))') 'TIMING_STUDY cpl_atm2land :', &
                                      tmin, tsum/real(nproc,rk8), tmax
    end if

    tloc = t_clm_drv
    call mpi_reduce(tloc, tmin, 1, mpi_double_precision, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(tloc, tmax, 1, mpi_double_precision, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(tloc, tsum, 1, mpi_double_precision, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,f12.3))') 'TIMING_STUDY clm_drv       :', &
                                      tmin, tsum/real(nproc,rk8), tmax
    end if

    tloc = t_clm_hyd1
    call mpi_reduce(tloc, tmin, 1, mpi_double_precision, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(tloc, tmax, 1, mpi_double_precision, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(tloc, tsum, 1, mpi_double_precision, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,f12.3))') 'TIMING_STUDY clm_hyd1      :', &
                                      tmin, tsum/real(nproc,rk8), tmax
    end if

    tloc = t_clm_bio1
    call mpi_reduce(tloc, tmin, 1, mpi_double_precision, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(tloc, tmax, 1, mpi_double_precision, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(tloc, tsum, 1, mpi_double_precision, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,f12.3))') 'TIMING_STUDY clm_bio1      :', &
                                      tmin, tsum/real(nproc,rk8), tmax
    end if

    tloc = t_clm_urbanflux
    call mpi_reduce(tloc, tmin, 1, mpi_double_precision, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(tloc, tmax, 1, mpi_double_precision, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(tloc, tsum, 1, mpi_double_precision, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,f12.3))') 'TIMING_STUDY clm_urbanflux :', &
                                      tmin, tsum/real(nproc,rk8), tmax
    end if

    tloc = t_clm_canopy
    call mpi_reduce(tloc, tmin, 1, mpi_double_precision, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(tloc, tmax, 1, mpi_double_precision, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(tloc, tsum, 1, mpi_double_precision, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,f12.3))') 'TIMING_STUDY clm_canopy    :', &
                                      tmin, tsum/real(nproc,rk8), tmax
    end if

    tloc = t_clm_bio2
    call mpi_reduce(tloc, tmin, 1, mpi_double_precision, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(tloc, tmax, 1, mpi_double_precision, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(tloc, tsum, 1, mpi_double_precision, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,f12.3))') 'TIMING_STUDY clm_bio2      :', &
                                      tmin, tsum/real(nproc,rk8), tmax
    end if

    tloc = t_clm_hyd2
    call mpi_reduce(tloc, tmin, 1, mpi_double_precision, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(tloc, tmax, 1, mpi_double_precision, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(tloc, tsum, 1, mpi_double_precision, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,f12.3))') 'TIMING_STUDY clm_hyd2      :', &
                                      tmin, tsum/real(nproc,rk8), tmax
    end if

    tloc = t_clm_map2gcell
    call mpi_reduce(tloc, tmin, 1, mpi_double_precision, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(tloc, tmax, 1, mpi_double_precision, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(tloc, tsum, 1, mpi_double_precision, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,f12.3))') 'TIMING_STUDY clm_map2gcell :', &
                                      tmin, tsum/real(nproc,rk8), tmax
    end if

    tloc = t_cpl_l2a
    call mpi_reduce(tloc, tmin, 1, mpi_double_precision, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(tloc, tmax, 1, mpi_double_precision, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(tloc, tsum, 1, mpi_double_precision, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,f12.3))') 'TIMING_STUDY cpl_land2atm :', &
                                      tmin, tsum/real(nproc,rk8), tmax
    end if

    tloc = t_cpl_a2l + t_clm_drv + t_cpl_l2a
    call mpi_reduce(tloc, tmin, 1, mpi_double_precision, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(tloc, tmax, 1, mpi_double_precision, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(tloc, tsum, 1, mpi_double_precision, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,f12.3))') 'TIMING_STUDY clm_total     :', &
                                      tmin, tsum/real(nproc,rk8), tmax
    end if

    call mpi_reduce(n_clm_calls, cmin, 1, mpi_integer8, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(n_clm_calls, cmax, 1, mpi_integer8, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(n_clm_calls, csum, 1, mpi_integer8, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,i12))') 'TIMING_STUDY clm_calls     :', cmin, csum/nproc, cmax
    end if

    call mpi_reduce(n_canopy_calls, cmin, 1, mpi_integer8, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(n_canopy_calls, cmax, 1, mpi_integer8, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(n_canopy_calls, csum, 1, mpi_integer8, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,i12))') 'TIMING_STUDY canopy_calls  :', cmin, csum/nproc, cmax
    end if

    call mpi_reduce(canopy_pft_total, cmin, 1, mpi_integer8, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(canopy_pft_total, cmax, 1, mpi_integer8, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(canopy_pft_total, csum, 1, mpi_integer8, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,i12))') 'TIMING_STUDY canopy_pfts   :', cmin, csum/nproc, cmax
    end if

    call mpi_reduce(canopy_pft_iter_total, cmin, 1, mpi_integer8, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(canopy_pft_iter_total, cmax, 1, mpi_integer8, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(canopy_pft_iter_total, csum, 1, mpi_integer8, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,i12))') 'TIMING_STUDY canopy_work   :', cmin, csum/nproc, cmax
    end if

    call mpi_reduce(canopy_iter_max, cmin, 1, mpi_integer8, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(canopy_iter_max, cmax, 1, mpi_integer8, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(canopy_iter_max, csum, 1, mpi_integer8, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,i12))') 'TIMING_STUDY canopy_itmax  :', cmin, csum/nproc, cmax
    end if

    call mpi_reduce(canopy_irrig_active_total, cmin, 1, mpi_integer8, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(canopy_irrig_active_total, cmax, 1, mpi_integer8, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(canopy_irrig_active_total, csum, 1, mpi_integer8, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,i12))') 'TIMING_STUDY canopy_irrig  :', cmin, csum/nproc, cmax
    end if

    call mpi_reduce(canopy_dense_total, cmin, 1, mpi_integer8, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(canopy_dense_total, cmax, 1, mpi_integer8, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(canopy_dense_total, csum, 1, mpi_integer8, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,i12))') 'TIMING_STUDY canopy_dense  :', cmin, csum/nproc, cmax
    end if

    call mpi_reduce(canopy_day_layers_total, cmin, 1, mpi_integer8, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(canopy_day_layers_total, cmax, 1, mpi_integer8, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(canopy_day_layers_total, csum, 1, mpi_integer8, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,i12))') 'TIMING_STUDY canopy_daylay :', cmin, csum/nproc, cmax
    end if

    call mpi_reduce(canopy_ci_solve_total, cmin, 1, mpi_integer8, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(canopy_ci_solve_total, cmax, 1, mpi_integer8, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(canopy_ci_solve_total, csum, 1, mpi_integer8, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,i12))') 'TIMING_STUDY canopy_cisolv :', cmin, csum/nproc, cmax
    end if

    call mpi_reduce(canopy_hybrid_iter_total, cmin, 1, mpi_integer8, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(canopy_hybrid_iter_total, cmax, 1, mpi_integer8, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(canopy_hybrid_iter_total, csum, 1, mpi_integer8, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,i12))') 'TIMING_STUDY canopy_hyiter :', cmin, csum/nproc, cmax
    end if

    call mpi_reduce(canopy_brent_total, cmin, 1, mpi_integer8, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(canopy_brent_total, cmax, 1, mpi_integer8, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(canopy_brent_total, csum, 1, mpi_integer8, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,i12))') 'TIMING_STUDY canopy_brent  :', cmin, csum/nproc, cmax
    end if

    call mpi_reduce(canopy_ci_func_eval_total, cmin, 1, mpi_integer8, mpi_min, italk, mycomm, ierr)
    call mpi_reduce(canopy_ci_func_eval_total, cmax, 1, mpi_integer8, mpi_max, italk, mycomm, ierr)
    call mpi_reduce(canopy_ci_func_eval_total, csum, 1, mpi_integer8, mpi_sum, italk, mycomm, ierr)
    if ( myid == italk ) then
      write(stdout,'(a,3(1x,i12))') 'TIMING_STUDY canopy_cieval :', cmin, csum/nproc, cmax
    end if

    allocate(rank_clm_canopy(max(1,nproc)))
    allocate(rank_canopy_work(max(1,nproc)), rank_canopy_pfts(max(1,nproc)), &
             rank_canopy_itmax(max(1,nproc)))
    allocate(rank_canopy_daylayers(max(1,nproc)), rank_canopy_ci_solve(max(1,nproc)))
    allocate(rank_canopy_hybrid_iter(max(1,nproc)), rank_canopy_brent(max(1,nproc)), &
             rank_canopy_ci_eval(max(1,nproc)))

    call mpi_gather(t_clm_canopy, 1, mpi_double_precision, rank_clm_canopy, 1, &
                    mpi_double_precision, italk, mycomm, ierr)
    call mpi_gather(canopy_pft_iter_total, 1, mpi_integer8, rank_canopy_work, 1, &
                    mpi_integer8, italk, mycomm, ierr)
    call mpi_gather(canopy_pft_total, 1, mpi_integer8, rank_canopy_pfts, 1, &
                    mpi_integer8, italk, mycomm, ierr)
    call mpi_gather(canopy_iter_max, 1, mpi_integer8, rank_canopy_itmax, 1, &
                    mpi_integer8, italk, mycomm, ierr)
    call mpi_gather(canopy_day_layers_total, 1, mpi_integer8, rank_canopy_daylayers, 1, &
                    mpi_integer8, italk, mycomm, ierr)
    call mpi_gather(canopy_ci_solve_total, 1, mpi_integer8, rank_canopy_ci_solve, 1, &
                    mpi_integer8, italk, mycomm, ierr)
    call mpi_gather(canopy_hybrid_iter_total, 1, mpi_integer8, rank_canopy_hybrid_iter, 1, &
                    mpi_integer8, italk, mycomm, ierr)
    call mpi_gather(canopy_brent_total, 1, mpi_integer8, rank_canopy_brent, 1, &
                    mpi_integer8, italk, mycomm, ierr)
    call mpi_gather(canopy_ci_func_eval_total, 1, mpi_integer8, rank_canopy_ci_eval, 1, &
                    mpi_integer8, italk, mycomm, ierr)

    if ( myid == italk ) then
      write(stdout,'(a,1x,i0)') 'TIMING_STUDY_RANK_BEGIN nproc=', nproc
      write(stdout,'(a)') 'TIMING_STUDY_RANK rank clm_canopy_s canopy_work canopy_pfts canopy_itmax canopy_daylay canopy_cisolv canopy_hyiter canopy_brent canopy_cieval canopy_s_per_work'
      do irank = 1, nproc
        if ( rank_canopy_work(irank) > 0_ik8 ) then
          write(stdout,'(a,1x,i4,1x,f12.3,1x,i14,1x,i14,1x,i8,1x,i14,1x,i14,1x,i14,1x,i14,1x,i14,1x,es12.4)') &
              'TIMING_STUDY_RANK', irank-1, rank_clm_canopy(irank), rank_canopy_work(irank), &
              rank_canopy_pfts(irank), rank_canopy_itmax(irank), rank_canopy_daylayers(irank), &
              rank_canopy_ci_solve(irank), rank_canopy_hybrid_iter(irank), rank_canopy_brent(irank), &
              rank_canopy_ci_eval(irank), &
              rank_clm_canopy(irank)/real(rank_canopy_work(irank),rk8)
        else
          write(stdout,'(a,1x,i4,1x,f12.3,1x,i14,1x,i14,1x,i8,1x,i14,1x,i14,1x,i14,1x,i14,1x,i14,1x,a)') &
              'TIMING_STUDY_RANK', irank-1, rank_clm_canopy(irank), rank_canopy_work(irank), &
              rank_canopy_pfts(irank), rank_canopy_itmax(irank), rank_canopy_daylayers(irank), &
              rank_canopy_ci_solve(irank), rank_canopy_hybrid_iter(irank), rank_canopy_brent(irank), &
              rank_canopy_ci_eval(irank), 'nan'
        end if
      end do
      write(stdout,'(a)') 'TIMING_STUDY_RANK_END'
      flush(stdout)
    end if
    deallocate(rank_clm_canopy, rank_canopy_work, rank_canopy_pfts, rank_canopy_itmax, &
               rank_canopy_daylayers, rank_canopy_ci_solve, rank_canopy_hybrid_iter, &
               rank_canopy_brent, rank_canopy_ci_eval)
#endif
#endif

    if ( iclimao3 == 1 ) then
      call closeo3
    end if

    if ( iclimaaer == 1 ) then
      call closeaerosol
    end if

    call rcmtimer%dismiss( )
    call memory_destroy
    call finaltime(myid)

#ifdef OASIS
    if ( ioasiscpl == 1 ) then
      !
      ! OASIS Variables Release
      !
      call oasisxregcm_release
    end if
#endif

    if ( myid == italk ) then
      write(stdout,*) 'RegCM V5 simulation successfully reached end'
    end if
  end subroutine RCM_finalize

#ifdef OPENACC
  subroutine setup_openacc(mpi_rank)
    use openacc, only: acc_device_default, acc_device_kind, &
                  acc_get_device_type, acc_get_num_devices, &
                  acc_set_device_num
    implicit none
    integer, intent(in) :: mpi_rank
    integer(ik4) :: idev, ndev
    integer(acc_device_kind) :: dev_type

    dev_type = acc_get_device_type()
    ndev = acc_get_num_devices(acc_device_default)
    idev = mod(mpi_rank, ndev)
    call acc_set_device_num(idev, dev_type)
  end subroutine setup_openacc
#endif

end module mod_regcm_interface
! vim: tabstop=8 expandtab shiftwidth=2 softtabstop=2
