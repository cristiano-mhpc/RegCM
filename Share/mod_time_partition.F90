module mod_time_partition

  ! Exclusive wall-clock partition timer.
  !
  ! At any instant, exactly one section is active. A call to tp_switch()
  ! closes the previous section and starts the new one. This allows per-rank
  ! section accounting without overlap.

  use mod_realkinds
  use mod_intkinds

  implicit none

  private

  integer(ik4), parameter, public :: SEC_NONE     = 0_ik4
  integer(ik4), parameter, public :: SEC_ATM      = 1_ik4
  integer(ik4), parameter, public :: SEC_CLM_A2L  = 2_ik4
  integer(ik4), parameter, public :: SEC_CLM_DRV  = 3_ik4
  integer(ik4), parameter, public :: SEC_CLM_L2A  = 4_ik4
  integer(ik4), parameter, public :: SEC_IO       = 5_ik4
  integer(ik4), parameter, public :: SEC_MPI_WAIT = 6_ik4
  integer(ik4), parameter, public :: SEC_OTHER    = 7_ik4
  integer(ik4), parameter, public :: NSEC = 7_ik4

  ! Accumulated seconds for each section index [0:NSEC].
  real(rk8), save :: acc(0:NSEC) = 0.0_rk8
  ! Currently active section id.
  integer(ik4), save :: cur = SEC_NONE
  ! Timestamp of last section transition.
  real(rk8), save :: tlast = 0.0_rk8
  ! True after tp_init() has started the timer state machine.
  logical, save :: started = .false.

  public :: tp_init
  public :: tp_switch
  public :: tp_finalize
  public :: tp_get_acc
  public :: tp_get_names

contains

  subroutine tp_init()
    ! Initialize partition accumulators and start in SEC_OTHER.
    acc = 0.0_rk8
    cur = SEC_OTHER
    tlast = tp_wtime()
    started = .true.
  end subroutine tp_init

  subroutine tp_switch(next_sec)
    ! Switch active section and accumulate elapsed time into previous section.
    integer(ik4), intent(in) :: next_sec
    real(rk8) :: now

    if (.not. started) call tp_init()

    now = tp_wtime()
    if (cur >= SEC_NONE .and. cur <= NSEC) then
      acc(cur) = acc(cur) + (now - tlast)
    end if

    cur = next_sec
    tlast = now
  end subroutine tp_switch

  subroutine tp_finalize()
    ! Close the current section by transitioning to SEC_NONE.
    if (.not. started) return
    call tp_switch(SEC_NONE)
  end subroutine tp_finalize

  subroutine tp_get_acc(out_acc)
    ! Return per-section accumulated seconds.
    real(rk8), intent(out) :: out_acc(0:NSEC)
    out_acc = acc
  end subroutine tp_get_acc

  subroutine tp_get_names(names)
    ! Return human-readable section names for reporting.
    character(len=*), intent(out) :: names(0:NSEC)
    names(SEC_NONE) = 'none'
    names(SEC_ATM) = 'atm'
    names(SEC_CLM_A2L) = 'clm_a2l'
    names(SEC_CLM_DRV) = 'clm_drv'
    names(SEC_CLM_L2A) = 'clm_l2a'
    names(SEC_IO) = 'io'
    names(SEC_MPI_WAIT) = 'mpi_wait'
    names(SEC_OTHER) = 'other'
  end subroutine tp_get_names

  pure real(rk8) function tp_wtime()
    ! Monotonic wall-clock estimate from system_clock.
    integer(ik8) :: count, rate

    call system_clock(count, rate)
    if (rate > 0_ik8) then
      tp_wtime = real(count, rk8) / real(rate, rk8)
    else
      tp_wtime = 0.0_rk8
    end if
  end function tp_wtime

end module mod_time_partition
