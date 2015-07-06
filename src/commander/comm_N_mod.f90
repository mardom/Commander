module comm_N_mod
  use comm_param_mod
  use comm_map_mod
  implicit none

  private
  public comm_N, compute_invN_lm
  
  type, abstract :: comm_N
     ! Data variables
     character(len=512)       :: type
     integer(i4b)             :: nside, nmaps, np
     logical(lgt)             :: pol
     class(comm_map), pointer :: invN_diag
   contains
     ! Data procedures
     procedure(matmulInvN),     deferred :: invN
     procedure(matmulSqrtInvN), deferred :: sqrtInvN
     procedure(returnRMS),      deferred :: rms
  end type comm_N

  abstract interface
     ! Return map_out = invN * map
     subroutine matmulInvN(self, map)
       import comm_map, comm_N, dp, i4b
       implicit none
       class(comm_N),   intent(in)    :: self
       class(comm_map), intent(inout) :: map
     end subroutine matmulInvN

     ! Return map_out = sqrtInvN * map
     subroutine matmulSqrtInvN(self, map)
       import comm_map, comm_N, dp, i4b
       implicit none
       class(comm_N),   intent(in)    :: self
       class(comm_map), intent(inout) :: map
     end subroutine matmulSqrtInvN

     ! Return rms map
     subroutine returnRMS(self, res)
       import comm_map, comm_N, dp
       implicit none
       class(comm_N),   intent(in)    :: self
       class(comm_map), intent(inout) :: res
     end subroutine returnRMS
  end interface

contains

  subroutine compute_invN_lm(invN_diag)
    implicit none

    class(comm_map), intent(inout) :: invN_diag

    real(dp)     :: l0min, l0max, l1min, l1max, npix
    integer(i4b) :: i, j, k, l, m, lp, l2, ier, twolmaxp2, pos, lmax
    complex(dpc) :: val(invN_diag%info%nmaps)
    real(dp), allocatable, dimension(:)   :: threej_symbols, threej_symbols_m0
    real(dp), allocatable, dimension(:,:) :: N_lm, a_l0

    lmax      = invN_diag%info%lmax
    twolmaxp2 = 2*lmax+2
    npix      = real(invN_diag%info%npix,dp)

    allocate(threej_symbols(twolmaxp2))
    allocate(threej_symbols_m0(twolmaxp2))
    allocate(N_lm(0:invN_diag%info%nalm-1,invN_diag%info%nmaps))
    allocate(a_l0(0:lmax,invN_diag%info%nmaps))
    call invN_diag%YtW
    if (invN_diag%info%myid == 0) a_l0 = invN_diag%alm(0:lmax,:)
    call mpi_bcast(a_l0, size(a_l0), MPI_DOUBLE_PRECISION, 0, invN_diag%info%comm, ier)
    
    pos = 0
    do j = 1, invN_diag%info%nm
       m = invN_diag%info%ms(j)
       do l = m, lmax
       
          call DRC3JJ(real(l,dp), real(l,dp), 0.d0, 0.d0, l0min, l0max, &
               & threej_symbols_m0, twolmaxp2, ier)
          call DRC3JJ(real(l,dp), real(l,dp), real(-m,dp), real(m,dp), l1min, l1max, &
               & threej_symbols, twolmaxp2, ier)
             
          val = cmplx(0.d0,0.d0)
          do l2 = 1, nint(l1max-l1min)+1
             lp = nint(l1min) + l2 - 1
             if (lp > lmax) exit
             ! Only m3 = 0 contributes, because m2 = -m1 => m3 = 0
             val = val + a_l0(lp,:) * sqrt(2.d0*lp+1.d0) * &
                  & threej_symbols(l2) * threej_symbols_m0(lp-nint(l0min)+1)
          end do
          val = val * (2*l+1) / sqrt(4.d0*pi) * npix / (4.d0*pi)
          if (mod(m,2)/=0) val = -val

          if (m == 0) then
             N_lm(pos,:)   = real(val,dp)
             pos           = pos+1
          else
             N_lm(pos,:)   = real(val,dp)
             N_lm(pos+1,:) = real(val,dp)
             pos               = pos+2
          end if
       end do
    end do

    invN_diag%alm = N_lm

    deallocate(N_lm, threej_symbols, threej_symbols_m0, a_l0)
    
  end subroutine compute_invN_lm
  
end module comm_N_mod
