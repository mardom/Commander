!================================================================================
!
! Copyright (C) 2020 Institute of Theoretical Astrophysics, University of Oslo.
!
! This file is part of Commander3.
!
! Commander3 is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! Commander3 is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with Commander3. If not, see <https://www.gnu.org/licenses/>.
!
!================================================================================
module comm_tod_pointing_mod
   use comm_tod_mod
   use comm_map_mod
   use comm_utils
   implicit none

contains

   ! Sky signal template
   subroutine project_sky(tod, map, pix_in, psi_in, flag, pmask, scan_id, &
        & s_sky, tmask, s_bp)
      implicit none
      class(comm_tod), intent(in)                       :: tod
      integer(i4b), dimension(0:), intent(in)           :: pmask
      real(sp), dimension(1:, 1:, 0:), intent(in)       :: map
      integer(i4b), dimension(:, :, :), intent(in)      :: pix_in, psi_in
      integer(i4b), dimension(:, :), intent(in)         :: flag
      integer(i4b), intent(in)                          :: scan_id
      real(sp), dimension(:, :), intent(out)            :: s_sky, tmask
      real(sp), dimension(:, :), intent(out), optional  :: s_bp

      integer(i4b)                                      :: i, p, det
      real(sp)                                          :: s
      integer(i4b), allocatable, dimension(:, :)        :: pix, psi

      if (size(pix, 2) /= 1 .or. size(psi, 2) /= 1) then
         write (*, *) "Call to project sky with nhorn /= 1. You probably want project_sky_differential."
         return
      end if

      pix = pix_in(:, :, 1)
      psi = psi_in(:, :, 1)
      ! s = T + Q * cos(2 * psi) + U * sin(2 * psi)
      ! T - temperature; Q, U - Stoke's parameters
      do det = 1, tod%ndet
         if (.not. tod%scans(scan_id)%d(det)%accept) then
            s_sky(:, det) = 0.d0
            tmask(:, det) = 0.d0
            cycle
         end if
         do i = 1, tod%scans(scan_id)%ntod
            p = tod%pix2ind(pix(i, det))
            s_sky(i, det) = map(1, p, det) + &
                         & map(2, p, det)*tod%cos2psi(psi(i, det)) + &
                         & map(3, p, det)*tod%sin2psi(psi(i, det))
!!$          s_sky(i,det) = map(det)%a(1,pix(i,det)+1) + &
!!$                       & map(det)%a(2,pix(i,det)+1) * tod%cos2psi(psi(i,det)) + &
!!$                       & map(det)%a(3,pix(i,det)+1) * tod%sin2psi(psi(i,det))
!          if (s_sky(i,det) /= s_sky(i,det)) then
!             write(*,*) det, i, map(det)%a(:,pix(i,det)+1), tod%cos2psi(psi(i,det)), tod%sin2psi(psi(i,det))
!             stop
!          end if

            tmask(i, det) = pmask(pix(i, det))
            if (iand(flag(i, det), tod%flag0) .ne. 0) tmask(i, det) = 0.
         end do
      end do

      if (present(s_bp)) then
         do det = 1, tod%ndet
            if (.not. tod%scans(scan_id)%d(det)%accept) then
               s_bp(:, det) = 0.d0
               cycle
            end if
            do i = 1, tod%scans(scan_id)%ntod
               p = tod%pix2ind(pix(i, det))
               s = map(1, p, 0) + &
                    & map(2, p, 0)*tod%cos2psi(psi(i, det)) + &
                    & map(3, p, 0)*tod%sin2psi(psi(i, det))
!!$             s =    map(0)%a(1,pix(i,det)+1) + &
!!$                  & map(0)%a(2,pix(i,det)+1) * tod%cos2psi(psi(i,det)) + &
!!$                  & map(0)%a(3,pix(i,det)+1) * tod%sin2psi(psi(i,det))
               s_bp(i, det) = s_sky(i, det) - s
            end do
         end do
      end if

   end subroutine project_sky

   ! Sky signal template
   subroutine project_sky_differential(tod, map, pix, psi, flag, x_im, pmask, scan_id,&
        & s_sky, tmask, simulate, s_bp)
      implicit none
      !class(comm_tod), intent(in)  :: tod
      ! It is only inout for simulating data
      class(comm_tod), intent(inout)  :: tod
      integer(i4b), dimension(0:), intent(in)  :: pmask
      real(sp), dimension(1:, 1:, 0:), intent(in)  :: map
      !type(shared_2d_sp),  dimension(0:),     intent(in)  :: map
      integer(i4b), dimension(:, :, :), intent(in)  :: pix, psi
      integer(i4b), dimension(:, :), intent(in)  :: flag
      integer(i4b), intent(in)  :: scan_id
      real(dp), dimension(:), intent(in)  :: x_im
      real(sp), dimension(:, :), intent(out) :: s_sky, tmask
      logical(lgt), intent(in) :: simulate
      real(sp), dimension(:, :), intent(out), optional :: s_bp

      integer(i4b) :: i, j, lpoint, rpoint, sgn
      tmask = 1d0

      do i = 1, tod%ndet
         if (.not. tod%scans(scan_id)%d(i)%accept) then
            s_sky(:, i) = 0.d0
            tmask(:, i) = 0.d0
            cycle
         end if
         sgn = (-1)**((i + 1)/2 + 1) ! 1 for 13, 14, -1 for 23, 24

         do j = 1, tod%scans(scan_id)%ntod
            lpoint = tod%pix2ind(pix(j, i, 1))
            rpoint = tod%pix2ind(pix(j, i, 2))
            ! The gain imbalance parameters x are different for each radiometer.
            ! d13 = (1+x1)*[T(pA) + P(pA,gA) + S(pA)]
            !      -(1-x1)*[T(pB) + P(pB,gB) + S(pB)]
            ! We need to make sure that the imbalance parameters are redundant,
            ! i.e., d13 and d14 have the same model,
            ! d14 = (1+x1)*[T(pA) + P(pA,gA) + S(pA)]
            !      -(1-x1)*[T(pB) + P(pB,gB) + S(pB)]
            ! but d23 and d24 have different models,
            ! i.e., d13 and d14 have the same model,
            ! d23 = (1+x2)*[T(pA) - P(pA,gA) - S(pA)]
            !      -(1-x2)*[T(pB) - P(pB,gB) - S(pB)]

            s_sky(j, i) = (1 + x_im((i + 1)/2))*(map(1, lpoint, i) + &
                                          &  sgn*( &
                                          &  map(2, lpoint, i)*tod%cos2psi(psi(j, i, 1)) + &
                                          &  map(3, lpoint, i)*tod%sin2psi(psi(j, i, 1)))) - &
                       &  (1 - x_im((i + 1)/2))*(map(1, rpoint, i) + &
                                          &  sgn*( &
                                          &  map(2, rpoint, i)*tod%cos2psi(psi(j, i, 2)) + &
                                          &  map(3, rpoint, i)*tod%sin2psi(psi(j, i, 2))))
            !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            ! Setting TOD to the sky model. Should not be in use for actual
            ! production runs!!!!
            !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            if (simulate) then
               tod%scans(scan_id)%d(i)%tod(j) = s_sky(j,i)*tod%scans(scan_id)%d(i)%gain + &
                   & + rand_normal(0d0, 1d0)*tod%scans(scan_id)%d(i)%sigma0
            end if
            !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            ! Everything below this line is fine.
            !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
            if (flag(j, i) == 0) then
                tmask(j, i) = pmask(pix(j, i, 1))*pmask(pix(j,i,2))
            else
                tmask(j, i) = 0
            end if
         end do
      end do

   end subroutine project_sky_differential

   function rand_normal(mean,stdev) result(c)
         double precision :: mean,stdev,c,temp(2),theta,r
         if (stdev <= 0.0d0) then
            write(*,*) "Standard Deviation must be positive."
         else
            call RANDOM_NUMBER(temp)
            r=(-2.0d0*log(temp(1)))**0.5
            theta = 2.0d0*PI*temp(2)
        c= mean+stdev*r*sin(theta)
      end if
   end function

end module comm_tod_pointing_mod
