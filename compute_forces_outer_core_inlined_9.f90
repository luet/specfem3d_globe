!=====================================================================
!
!          S p e c f e m 3 D  G l o b e  V e r s i o n  3 . 3
!          --------------------------------------------------
!
!                 Dimitri Komatitsch and Jeroen Tromp
!    Seismological Laboratory - California Institute of Technology
!        (c) California Institute of Technology September 2002
!
!    A signed non-commercial agreement is required to use this program.
!   Please check http://www.gps.caltech.edu/research/jtromp for details.
!           Free for non-commercial academic research ONLY.
!      This program is distributed WITHOUT ANY WARRANTY whatsoever.
!      Do not redistribute this program without written permission.
!
!=====================================================================

  subroutine compute_forces_outer_core(time,deltat,two_omega_earth, &
          A_array_rotation,B_array_rotation, &
          minus_rho_g_over_kappa_fluid,iter,displfluid,accelfluid, &
          xstore,ystore,zstore, &
          xix,xiy,xiz,etax,etay,etaz,gammax,gammay,gammaz,jacobian, &
          hprime_xx,hprime_yy,hprime_zz, &
          hprimewgll_xx,hprimewgll_yy,hprimewgll_zz, &
          wgll_cube,wgllwgll_yz_no_i,wgllwgll_xz_no_j,wgllwgll_xy_no_k, &
          ibool,idoubling,nspec_outer_core,nglob_outer_core,update_dof,index_fluid_i,index_fluid_k)

  implicit none

  include "constants.h"

! include values created by the mesher
! done for performance only using static allocation to allow for loop unrolling
  include "OUTPUT_FILES/values_from_mesher.h"

  integer iter

! for doubling in the outer core
  integer nspec_outer_core,nglob_outer_core

! array with the local to global mapping per slice
  integer, dimension(nspec_outer_core) :: idoubling

! displacement and acceleration
  real(kind=CUSTOM_REAL), dimension(nglob_outer_core) :: displfluid,accelfluid

! global points in the matching regions
  logical, dimension(NGLOBMAX_OUTER_CORE) :: update_dof

! arrays with mesh parameters per slice
  integer, dimension(NGLLX,NGLLY,NGLLZ,nspec_outer_core) :: ibool
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ,nspec_outer_core) :: xix,xiy,xiz, &
                      etax,etay,etaz,gammax,gammay,gammaz,jacobian

! array with derivatives of Lagrange polynomials and precalculated products
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLX) :: hprime_xx,hprimewgll_xx
  real(kind=CUSTOM_REAL), dimension(NGLLY,NGLLY) :: hprime_yy,hprimewgll_yy
  real(kind=CUSTOM_REAL), dimension(NGLLZ,NGLLZ) :: hprime_zz,hprimewgll_zz
  double precision, dimension(NGLLX,NGLLY,NGLLZ) :: wgll_cube
  double precision, dimension(NDIM,NGLLX,NGLLY,NGLLZ) :: wgllwgll_yz_no_i,wgllwgll_xz_no_j,wgllwgll_xy_no_k

  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ) :: &
    tempx1,tempx2,tempx3,tempx1loc,tempx2loc,tempx3loc, &
    tempx1inline,tempx2inline,tempx3inline,disploc,sum_terms

! for gravity
  integer int_radius
  double precision radius,theta,phi,gxl,gyl,gzl
  double precision cos_theta,sin_theta,cos_phi,sin_phi
  double precision, dimension(NRAD_GRAVITY) :: minus_rho_g_over_kappa_fluid
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ) :: gravity_term
  real(kind=CUSTOM_REAL), dimension(nglob_outer_core) :: xstore,ystore,zstore

! for the Euler scheme for rotation
  real(kind=CUSTOM_REAL) time,deltat,two_omega_earth
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ,NSPECMAX_OUTER_CORE_ROTATION) :: &
    A_array_rotation,B_array_rotation

  real(kind=CUSTOM_REAL) two_omega_deltat,cos_two_omega_t,sin_two_omega_t,A_rotation,B_rotation, &
       ux_rotation,uy_rotation,dpotentialdx_with_rot,dpotentialdy_with_rot
  real(kind=CUSTOM_REAL), dimension(NGLLX,NGLLY,NGLLZ) :: source_euler_A,source_euler_B

  integer ispec,iglob
  integer i,k,ij,ijk
  integer, dimension(NGLLSQUARE) :: index_fluid_i,index_fluid_k

  real(kind=CUSTOM_REAL) xixl,xiyl,xizl,etaxl,etayl,etazl,gammaxl,gammayl,gammazl,jacobianl
  real(kind=CUSTOM_REAL) dpotentialdxl,dpotentialdyl,dpotentialdzl

! ****************************************************
!   big loop over all spectral elements in the fluid
! ****************************************************

! set acceleration to zero where needed
  do i=1,nglob_outer_core
    if(iter == 1 .or. update_dof(i)) accelfluid(i) = 0._CUSTOM_REAL
  enddo

!CDIR NOVECTOR
  do ispec = 1,nspec_outer_core

! only matching layers if not first iteration
    if(iter == 1 .or. idoubling(ispec) == IFLAG_TOP_OUTER_CORE &
        .or. idoubling(ispec) == IFLAG_TOP_OUTER_CORE_LEV2 &
        .or. idoubling(ispec) == IFLAG_BOTTOM_OUTER_CORE &
        .or. idoubling(ispec) == IFLAG_BOTTOM_OUTER_CORE_LEV2) then

! copy global displacement to local
    do ijk=1,NGLLCUBE
      disploc(ijk,1,1) = displfluid(ibool(ijk,1,1,ispec))
    enddo

! inlined first matrix product

!CDIR NODEP(tempx2loc)
  do ij = 1,NGLLSQUARE

    i = index_fluid_i(ij)
    k = index_fluid_k(ij)

!---
!--- ij is actually jk here
    tempx1loc(1,ij,1) = &
        disploc(1,ij,1)*hprime_xx(1,1) + disploc(2,ij,1)*hprime_xx(2,1) + &
        disploc(3,ij,1)*hprime_xx(3,1) + disploc(4,ij,1)*hprime_xx(4,1) + &
        disploc(5,ij,1)*hprime_xx(5,1) + disploc(6,ij,1)*hprime_xx(6,1) + &
        disploc(7,ij,1)*hprime_xx(7,1) + disploc(8,ij,1)*hprime_xx(8,1) + &
        disploc(9,ij,1)*hprime_xx(9,1)

!---
    tempx2loc(i,1,k) = &
        disploc(i,1,k)*hprime_yy(1,1) + disploc(i,2,k)*hprime_yy(2,1) + &
        disploc(i,3,k)*hprime_yy(3,1) + disploc(i,4,k)*hprime_yy(4,1) + &
        disploc(i,5,k)*hprime_yy(5,1) + disploc(i,6,k)*hprime_yy(6,1) + &
        disploc(i,7,k)*hprime_yy(7,1) + disploc(i,8,k)*hprime_yy(8,1) + &
        disploc(i,9,k)*hprime_yy(9,1)

!---
    tempx3loc(ij,1,1) = &
        disploc(ij,1,1)*hprime_zz(1,1) + disploc(ij,1,2)*hprime_zz(2,1) + &
        disploc(ij,1,3)*hprime_zz(3,1) + disploc(ij,1,4)*hprime_zz(4,1) + &
        disploc(ij,1,5)*hprime_zz(5,1) + disploc(ij,1,6)*hprime_zz(6,1) + &
        disploc(ij,1,7)*hprime_zz(7,1) + disploc(ij,1,8)*hprime_zz(8,1) + &
        disploc(ij,1,9)*hprime_zz(9,1)

!---
!--- ij is actually jk here
    tempx1loc(2,ij,1) = &
        disploc(1,ij,1)*hprime_xx(1,2) + disploc(2,ij,1)*hprime_xx(2,2) + &
        disploc(3,ij,1)*hprime_xx(3,2) + disploc(4,ij,1)*hprime_xx(4,2) + &
        disploc(5,ij,1)*hprime_xx(5,2) + disploc(6,ij,1)*hprime_xx(6,2) + &
        disploc(7,ij,1)*hprime_xx(7,2) + disploc(8,ij,1)*hprime_xx(8,2) + &
        disploc(9,ij,1)*hprime_xx(9,2)

!---
    tempx2loc(i,2,k) = &
        disploc(i,1,k)*hprime_yy(1,2) + disploc(i,2,k)*hprime_yy(2,2) + &
        disploc(i,3,k)*hprime_yy(3,2) + disploc(i,4,k)*hprime_yy(4,2) + &
        disploc(i,5,k)*hprime_yy(5,2) + disploc(i,6,k)*hprime_yy(6,2) + &
        disploc(i,7,k)*hprime_yy(7,2) + disploc(i,8,k)*hprime_yy(8,2) + &
        disploc(i,9,k)*hprime_yy(9,2)

!---
    tempx3loc(ij,1,2) = &
        disploc(ij,1,1)*hprime_zz(1,2) + disploc(ij,1,2)*hprime_zz(2,2) + &
        disploc(ij,1,3)*hprime_zz(3,2) + disploc(ij,1,4)*hprime_zz(4,2) + &
        disploc(ij,1,5)*hprime_zz(5,2) + disploc(ij,1,6)*hprime_zz(6,2) + &
        disploc(ij,1,7)*hprime_zz(7,2) + disploc(ij,1,8)*hprime_zz(8,2) + &
        disploc(ij,1,9)*hprime_zz(9,2)

!---
!--- ij is actually jk here
    tempx1loc(3,ij,1) = &
        disploc(1,ij,1)*hprime_xx(1,3) + disploc(2,ij,1)*hprime_xx(2,3) + &
        disploc(3,ij,1)*hprime_xx(3,3) + disploc(4,ij,1)*hprime_xx(4,3) + &
        disploc(5,ij,1)*hprime_xx(5,3) + disploc(6,ij,1)*hprime_xx(6,3) + &
        disploc(7,ij,1)*hprime_xx(7,3) + disploc(8,ij,1)*hprime_xx(8,3) + &
        disploc(9,ij,1)*hprime_xx(9,3)

!---
    tempx2loc(i,3,k) = &
        disploc(i,1,k)*hprime_yy(1,3) + disploc(i,2,k)*hprime_yy(2,3) + &
        disploc(i,3,k)*hprime_yy(3,3) + disploc(i,4,k)*hprime_yy(4,3) + &
        disploc(i,5,k)*hprime_yy(5,3) + disploc(i,6,k)*hprime_yy(6,3) + &
        disploc(i,7,k)*hprime_yy(7,3) + disploc(i,8,k)*hprime_yy(8,3) + &
        disploc(i,9,k)*hprime_yy(9,3)

!---
    tempx3loc(ij,1,3) = &
        disploc(ij,1,1)*hprime_zz(1,3) + disploc(ij,1,2)*hprime_zz(2,3) + &
        disploc(ij,1,3)*hprime_zz(3,3) + disploc(ij,1,4)*hprime_zz(4,3) + &
        disploc(ij,1,5)*hprime_zz(5,3) + disploc(ij,1,6)*hprime_zz(6,3) + &
        disploc(ij,1,7)*hprime_zz(7,3) + disploc(ij,1,8)*hprime_zz(8,3) + &
        disploc(ij,1,9)*hprime_zz(9,3)

!---
!--- ij is actually jk here
    tempx1loc(4,ij,1) = &
        disploc(1,ij,1)*hprime_xx(1,4) + disploc(2,ij,1)*hprime_xx(2,4) + &
        disploc(3,ij,1)*hprime_xx(3,4) + disploc(4,ij,1)*hprime_xx(4,4) + &
        disploc(5,ij,1)*hprime_xx(5,4) + disploc(6,ij,1)*hprime_xx(6,4) + &
        disploc(7,ij,1)*hprime_xx(7,4) + disploc(8,ij,1)*hprime_xx(8,4) + &
        disploc(9,ij,1)*hprime_xx(9,4)

!---
    tempx2loc(i,4,k) = &
        disploc(i,1,k)*hprime_yy(1,4) + disploc(i,2,k)*hprime_yy(2,4) + &
        disploc(i,3,k)*hprime_yy(3,4) + disploc(i,4,k)*hprime_yy(4,4) + &
        disploc(i,5,k)*hprime_yy(5,4) + disploc(i,6,k)*hprime_yy(6,4) + &
        disploc(i,7,k)*hprime_yy(7,4) + disploc(i,8,k)*hprime_yy(8,4) + &
        disploc(i,9,k)*hprime_yy(9,4)

!---
    tempx3loc(ij,1,4) = &
        disploc(ij,1,1)*hprime_zz(1,4) + disploc(ij,1,2)*hprime_zz(2,4) + &
        disploc(ij,1,3)*hprime_zz(3,4) + disploc(ij,1,4)*hprime_zz(4,4) + &
        disploc(ij,1,5)*hprime_zz(5,4) + disploc(ij,1,6)*hprime_zz(6,4) + &
        disploc(ij,1,7)*hprime_zz(7,4) + disploc(ij,1,8)*hprime_zz(8,4) + &
        disploc(ij,1,9)*hprime_zz(9,4)

!---
!--- ij is actually jk here
    tempx1loc(5,ij,1) = &
        disploc(1,ij,1)*hprime_xx(1,5) + disploc(2,ij,1)*hprime_xx(2,5) + &
        disploc(3,ij,1)*hprime_xx(3,5) + disploc(4,ij,1)*hprime_xx(4,5) + &
        disploc(5,ij,1)*hprime_xx(5,5) + disploc(6,ij,1)*hprime_xx(6,5) + &
        disploc(7,ij,1)*hprime_xx(7,5) + disploc(8,ij,1)*hprime_xx(8,5) + &
        disploc(9,ij,1)*hprime_xx(9,5)

!---
    tempx2loc(i,5,k) = &
        disploc(i,1,k)*hprime_yy(1,5) + disploc(i,2,k)*hprime_yy(2,5) + &
        disploc(i,3,k)*hprime_yy(3,5) + disploc(i,4,k)*hprime_yy(4,5) + &
        disploc(i,5,k)*hprime_yy(5,5) + disploc(i,6,k)*hprime_yy(6,5) + &
        disploc(i,7,k)*hprime_yy(7,5) + disploc(i,8,k)*hprime_yy(8,5) + &
        disploc(i,9,k)*hprime_yy(9,5)

!---
    tempx3loc(ij,1,5) = &
        disploc(ij,1,1)*hprime_zz(1,5) + disploc(ij,1,2)*hprime_zz(2,5) + &
        disploc(ij,1,3)*hprime_zz(3,5) + disploc(ij,1,4)*hprime_zz(4,5) + &
        disploc(ij,1,5)*hprime_zz(5,5) + disploc(ij,1,6)*hprime_zz(6,5) + &
        disploc(ij,1,7)*hprime_zz(7,5) + disploc(ij,1,8)*hprime_zz(8,5) + &
        disploc(ij,1,9)*hprime_zz(9,5)

!---
!--- ij is actually jk here
    tempx1loc(6,ij,1) = &
        disploc(1,ij,1)*hprime_xx(1,6) + disploc(2,ij,1)*hprime_xx(2,6) + &
        disploc(3,ij,1)*hprime_xx(3,6) + disploc(4,ij,1)*hprime_xx(4,6) + &
        disploc(5,ij,1)*hprime_xx(5,6) + disploc(6,ij,1)*hprime_xx(6,6) + &
        disploc(7,ij,1)*hprime_xx(7,6) + disploc(8,ij,1)*hprime_xx(8,6) + &
        disploc(9,ij,1)*hprime_xx(9,6)

!---
    tempx2loc(i,6,k) = &
        disploc(i,1,k)*hprime_yy(1,6) + disploc(i,2,k)*hprime_yy(2,6) + &
        disploc(i,3,k)*hprime_yy(3,6) + disploc(i,4,k)*hprime_yy(4,6) + &
        disploc(i,5,k)*hprime_yy(5,6) + disploc(i,6,k)*hprime_yy(6,6) + &
        disploc(i,7,k)*hprime_yy(7,6) + disploc(i,8,k)*hprime_yy(8,6) + &
        disploc(i,9,k)*hprime_yy(9,6)

!---
    tempx3loc(ij,1,6) = &
        disploc(ij,1,1)*hprime_zz(1,6) + disploc(ij,1,2)*hprime_zz(2,6) + &
        disploc(ij,1,3)*hprime_zz(3,6) + disploc(ij,1,4)*hprime_zz(4,6) + &
        disploc(ij,1,5)*hprime_zz(5,6) + disploc(ij,1,6)*hprime_zz(6,6) + &
        disploc(ij,1,7)*hprime_zz(7,6) + disploc(ij,1,8)*hprime_zz(8,6) + &
        disploc(ij,1,9)*hprime_zz(9,6)

!---
!--- ij is actually jk here
    tempx1loc(7,ij,1) = &
        disploc(1,ij,1)*hprime_xx(1,7) + disploc(2,ij,1)*hprime_xx(2,7) + &
        disploc(3,ij,1)*hprime_xx(3,7) + disploc(4,ij,1)*hprime_xx(4,7) + &
        disploc(5,ij,1)*hprime_xx(5,7) + disploc(6,ij,1)*hprime_xx(6,7) + &
        disploc(7,ij,1)*hprime_xx(7,7) + disploc(8,ij,1)*hprime_xx(8,7) + &
        disploc(9,ij,1)*hprime_xx(9,7)

!---
    tempx2loc(i,7,k) = &
        disploc(i,1,k)*hprime_yy(1,7) + disploc(i,2,k)*hprime_yy(2,7) + &
        disploc(i,3,k)*hprime_yy(3,7) + disploc(i,4,k)*hprime_yy(4,7) + &
        disploc(i,5,k)*hprime_yy(5,7) + disploc(i,6,k)*hprime_yy(6,7) + &
        disploc(i,7,k)*hprime_yy(7,7) + disploc(i,8,k)*hprime_yy(8,7) + &
        disploc(i,9,k)*hprime_yy(9,7)

!---
    tempx3loc(ij,1,7) = &
        disploc(ij,1,1)*hprime_zz(1,7) + disploc(ij,1,2)*hprime_zz(2,7) + &
        disploc(ij,1,3)*hprime_zz(3,7) + disploc(ij,1,4)*hprime_zz(4,7) + &
        disploc(ij,1,5)*hprime_zz(5,7) + disploc(ij,1,6)*hprime_zz(6,7) + &
        disploc(ij,1,7)*hprime_zz(7,7) + disploc(ij,1,8)*hprime_zz(8,7) + &
        disploc(ij,1,9)*hprime_zz(9,7)

!---
!--- ij is actually jk here
    tempx1loc(8,ij,1) = &
        disploc(1,ij,1)*hprime_xx(1,8) + disploc(2,ij,1)*hprime_xx(2,8) + &
        disploc(3,ij,1)*hprime_xx(3,8) + disploc(4,ij,1)*hprime_xx(4,8) + &
        disploc(5,ij,1)*hprime_xx(5,8) + disploc(6,ij,1)*hprime_xx(6,8) + &
        disploc(7,ij,1)*hprime_xx(7,8) + disploc(8,ij,1)*hprime_xx(8,8) + &
        disploc(9,ij,1)*hprime_xx(9,8)

!---
    tempx2loc(i,8,k) = &
        disploc(i,1,k)*hprime_yy(1,8) + disploc(i,2,k)*hprime_yy(2,8) + &
        disploc(i,3,k)*hprime_yy(3,8) + disploc(i,4,k)*hprime_yy(4,8) + &
        disploc(i,5,k)*hprime_yy(5,8) + disploc(i,6,k)*hprime_yy(6,8) + &
        disploc(i,7,k)*hprime_yy(7,8) + disploc(i,8,k)*hprime_yy(8,8) + &
        disploc(i,9,k)*hprime_yy(9,8)

!---
    tempx3loc(ij,1,8) = &
        disploc(ij,1,1)*hprime_zz(1,8) + disploc(ij,1,2)*hprime_zz(2,8) + &
        disploc(ij,1,3)*hprime_zz(3,8) + disploc(ij,1,4)*hprime_zz(4,8) + &
        disploc(ij,1,5)*hprime_zz(5,8) + disploc(ij,1,6)*hprime_zz(6,8) + &
        disploc(ij,1,7)*hprime_zz(7,8) + disploc(ij,1,8)*hprime_zz(8,8) + &
        disploc(ij,1,9)*hprime_zz(9,8)

!---
!--- ij is actually jk here
    tempx1loc(9,ij,1) = &
        disploc(1,ij,1)*hprime_xx(1,9) + disploc(2,ij,1)*hprime_xx(2,9) + &
        disploc(3,ij,1)*hprime_xx(3,9) + disploc(4,ij,1)*hprime_xx(4,9) + &
        disploc(5,ij,1)*hprime_xx(5,9) + disploc(6,ij,1)*hprime_xx(6,9) + &
        disploc(7,ij,1)*hprime_xx(7,9) + disploc(8,ij,1)*hprime_xx(8,9) + &
        disploc(9,ij,1)*hprime_xx(9,9)

!---
    tempx2loc(i,9,k) = &
        disploc(i,1,k)*hprime_yy(1,9) + disploc(i,2,k)*hprime_yy(2,9) + &
        disploc(i,3,k)*hprime_yy(3,9) + disploc(i,4,k)*hprime_yy(4,9) + &
        disploc(i,5,k)*hprime_yy(5,9) + disploc(i,6,k)*hprime_yy(6,9) + &
        disploc(i,7,k)*hprime_yy(7,9) + disploc(i,8,k)*hprime_yy(8,9) + &
        disploc(i,9,k)*hprime_yy(9,9)

!---
    tempx3loc(ij,1,9) = &
        disploc(ij,1,1)*hprime_zz(1,9) + disploc(ij,1,2)*hprime_zz(2,9) + &
        disploc(ij,1,3)*hprime_zz(3,9) + disploc(ij,1,4)*hprime_zz(4,9) + &
        disploc(ij,1,5)*hprime_zz(5,9) + disploc(ij,1,6)*hprime_zz(6,9) + &
        disploc(ij,1,7)*hprime_zz(7,9) + disploc(ij,1,8)*hprime_zz(8,9) + &
        disploc(ij,1,9)*hprime_zz(9,9)

  enddo

! fused the three loops for inlined version
    do ijk=1,NGLLCUBE

!         get derivatives of velocity potential with respect to x, y and z

          xixl = xix(ijk,1,1,ispec)
          xiyl = xiy(ijk,1,1,ispec)
          xizl = xiz(ijk,1,1,ispec)
          etaxl = etax(ijk,1,1,ispec)
          etayl = etay(ijk,1,1,ispec)
          etazl = etaz(ijk,1,1,ispec)
          gammaxl = gammax(ijk,1,1,ispec)
          gammayl = gammay(ijk,1,1,ispec)
          gammazl = gammaz(ijk,1,1,ispec)
          jacobianl = jacobian(ijk,1,1,ispec)

          dpotentialdxl = xixl*tempx1loc(ijk,1,1) + etaxl*tempx2loc(ijk,1,1) + gammaxl*tempx3loc(ijk,1,1)
          dpotentialdyl = xiyl*tempx1loc(ijk,1,1) + etayl*tempx2loc(ijk,1,1) + gammayl*tempx3loc(ijk,1,1)
          dpotentialdzl = xizl*tempx1loc(ijk,1,1) + etazl*tempx2loc(ijk,1,1) + gammazl*tempx3loc(ijk,1,1)

! compute contribution of rotation and add to gradient of potential
! this term has no Z component
    if(ROTATION_VAL) then

! store the source for the Euler scheme for A_rotation and B_rotation
      two_omega_deltat = deltat * two_omega_earth

      cos_two_omega_t = cos(two_omega_earth*time)
      sin_two_omega_t = sin(two_omega_earth*time)

! time step deltat of Euler scheme is included in the source
      source_euler_A(ijk,1,1) = two_omega_deltat * (cos_two_omega_t * dpotentialdyl + sin_two_omega_t * dpotentialdxl)
      source_euler_B(ijk,1,1) = two_omega_deltat * (sin_two_omega_t * dpotentialdyl - cos_two_omega_t * dpotentialdxl)

      A_rotation = A_array_rotation(ijk,1,1,ispec)
      B_rotation = B_array_rotation(ijk,1,1,ispec)

      ux_rotation =   A_rotation*cos_two_omega_t + B_rotation*sin_two_omega_t
      uy_rotation = - A_rotation*sin_two_omega_t + B_rotation*cos_two_omega_t

      dpotentialdx_with_rot = dpotentialdxl + ux_rotation
      dpotentialdy_with_rot = dpotentialdyl + uy_rotation
    else

      dpotentialdx_with_rot = dpotentialdxl
      dpotentialdy_with_rot = dpotentialdyl

    endif  ! end of section with rotation

! precompute and store gravity term
          if(GRAVITY_VAL) then

! use mesh coordinates to get theta and phi
! x y z contain r theta phi

            iglob = ibool(ijk,1,1,ispec)
            radius = dble(xstore(iglob))
            theta = dble(ystore(iglob))
            phi = dble(zstore(iglob))

            cos_theta = dcos(theta)
            sin_theta = dsin(theta)
            cos_phi = dcos(phi)
            sin_phi = dsin(phi)

! get g, rho and dg/dr=dg
! spherical components of the gravitational acceleration
! for efficiency replace with lookup table every 100 m in radial direction
            int_radius = nint(radius * R_EARTH_KM * 10.d0)

! Cartesian components of the gravitational acceleration
! integrate and multiply by rho / Kappa
            gxl = sin_theta*cos_phi
            gyl = sin_theta*sin_phi
            gzl = cos_theta

! distinguish whether single or double precision for reals
            if(CUSTOM_REAL == SIZE_REAL) then
              gravity_term(ijk,1,1) = &
                sngl(minus_rho_g_over_kappa_fluid(int_radius) * &
                dble(jacobianl) * wgll_cube(ijk,1,1) * &
               (dble(dpotentialdx_with_rot) * gxl + &
                dble(dpotentialdy_with_rot) * gyl + dble(dpotentialdzl) * gzl))
            else
              gravity_term(ijk,1,1) = minus_rho_g_over_kappa_fluid(int_radius) * &
                 jacobianl * wgll_cube(ijk,1,1) * (dpotentialdx_with_rot * gxl + &
                 dpotentialdy_with_rot * gyl + dpotentialdzl * gzl)
            endif

          endif

          tempx1(ijk,1,1) = jacobianl*(xixl*dpotentialdx_with_rot + xiyl*dpotentialdy_with_rot + xizl*dpotentialdzl)
          tempx2(ijk,1,1) = jacobianl*(etaxl*dpotentialdx_with_rot + etayl*dpotentialdy_with_rot + etazl*dpotentialdzl)
          tempx3(ijk,1,1) = jacobianl*(gammaxl*dpotentialdx_with_rot + gammayl*dpotentialdy_with_rot + gammazl*dpotentialdzl)

      enddo

! inlined second matrix product

!CDIR NODEP(tempx2inline)
  do ij = 1,NGLLSQUARE

    i = index_fluid_i(ij)
    k = index_fluid_k(ij)

!---
!--- ij is actually jk below
  tempx1inline(1,ij,1) = &
    tempx1(1,ij,1)*hprimewgll_xx(1,1) + tempx1(2,ij,1)*hprimewgll_xx(1,2) + &
    tempx1(3,ij,1)*hprimewgll_xx(1,3) + tempx1(4,ij,1)*hprimewgll_xx(1,4) + &
    tempx1(5,ij,1)*hprimewgll_xx(1,5) + tempx1(6,ij,1)*hprimewgll_xx(1,6) + &
    tempx1(7,ij,1)*hprimewgll_xx(1,7) + tempx1(8,ij,1)*hprimewgll_xx(1,8) + &
    tempx1(9,ij,1)*hprimewgll_xx(1,9)

!---
  tempx2inline(i,1,k) = &
    tempx2(i,1,k)*hprimewgll_yy(1,1) + tempx2(i,2,k)*hprimewgll_yy(1,2) + &
    tempx2(i,3,k)*hprimewgll_yy(1,3) + tempx2(i,4,k)*hprimewgll_yy(1,4) + &
    tempx2(i,5,k)*hprimewgll_yy(1,5) + tempx2(i,6,k)*hprimewgll_yy(1,6) + &
    tempx2(i,7,k)*hprimewgll_yy(1,7) + tempx2(i,8,k)*hprimewgll_yy(1,8) + &
    tempx2(i,9,k)*hprimewgll_yy(1,9)

!---
  tempx3inline(ij,1,1) = &
    tempx3(ij,1,1)*hprimewgll_zz(1,1) + tempx3(ij,1,2)*hprimewgll_zz(1,2) + &
    tempx3(ij,1,3)*hprimewgll_zz(1,3) + tempx3(ij,1,4)*hprimewgll_zz(1,4) + &
    tempx3(ij,1,5)*hprimewgll_zz(1,5) + tempx3(ij,1,6)*hprimewgll_zz(1,6) + &
    tempx3(ij,1,7)*hprimewgll_zz(1,7) + tempx3(ij,1,8)*hprimewgll_zz(1,8) + &
    tempx3(ij,1,9)*hprimewgll_zz(1,9)

!---
!--- ij is actually jk below
  tempx1inline(2,ij,1) = &
    tempx1(1,ij,1)*hprimewgll_xx(2,1) + tempx1(2,ij,1)*hprimewgll_xx(2,2) + &
    tempx1(3,ij,1)*hprimewgll_xx(2,3) + tempx1(4,ij,1)*hprimewgll_xx(2,4) + &
    tempx1(5,ij,1)*hprimewgll_xx(2,5) + tempx1(6,ij,1)*hprimewgll_xx(2,6) + &
    tempx1(7,ij,1)*hprimewgll_xx(2,7) + tempx1(8,ij,1)*hprimewgll_xx(2,8) + &
    tempx1(9,ij,1)*hprimewgll_xx(2,9)

!---
  tempx2inline(i,2,k) = &
    tempx2(i,1,k)*hprimewgll_yy(2,1) + tempx2(i,2,k)*hprimewgll_yy(2,2) + &
    tempx2(i,3,k)*hprimewgll_yy(2,3) + tempx2(i,4,k)*hprimewgll_yy(2,4) + &
    tempx2(i,5,k)*hprimewgll_yy(2,5) + tempx2(i,6,k)*hprimewgll_yy(2,6) + &
    tempx2(i,7,k)*hprimewgll_yy(2,7) + tempx2(i,8,k)*hprimewgll_yy(2,8) + &
    tempx2(i,9,k)*hprimewgll_yy(2,9)

!---
  tempx3inline(ij,1,2) = &
    tempx3(ij,1,1)*hprimewgll_zz(2,1) + tempx3(ij,1,2)*hprimewgll_zz(2,2) + &
    tempx3(ij,1,3)*hprimewgll_zz(2,3) + tempx3(ij,1,4)*hprimewgll_zz(2,4) + &
    tempx3(ij,1,5)*hprimewgll_zz(2,5) + tempx3(ij,1,6)*hprimewgll_zz(2,6) + &
    tempx3(ij,1,7)*hprimewgll_zz(2,7) + tempx3(ij,1,8)*hprimewgll_zz(2,8) + &
    tempx3(ij,1,9)*hprimewgll_zz(2,9)

!---
!--- ij is actually jk below
  tempx1inline(3,ij,1) = &
    tempx1(1,ij,1)*hprimewgll_xx(3,1) + tempx1(2,ij,1)*hprimewgll_xx(3,2) + &
    tempx1(3,ij,1)*hprimewgll_xx(3,3) + tempx1(4,ij,1)*hprimewgll_xx(3,4) + &
    tempx1(5,ij,1)*hprimewgll_xx(3,5) + tempx1(6,ij,1)*hprimewgll_xx(3,6) + &
    tempx1(7,ij,1)*hprimewgll_xx(3,7) + tempx1(8,ij,1)*hprimewgll_xx(3,8) + &
    tempx1(9,ij,1)*hprimewgll_xx(3,9)

!---
  tempx2inline(i,3,k) = &
    tempx2(i,1,k)*hprimewgll_yy(3,1) + tempx2(i,2,k)*hprimewgll_yy(3,2) + &
    tempx2(i,3,k)*hprimewgll_yy(3,3) + tempx2(i,4,k)*hprimewgll_yy(3,4) + &
    tempx2(i,5,k)*hprimewgll_yy(3,5) + tempx2(i,6,k)*hprimewgll_yy(3,6) + &
    tempx2(i,7,k)*hprimewgll_yy(3,7) + tempx2(i,8,k)*hprimewgll_yy(3,8) + &
    tempx2(i,9,k)*hprimewgll_yy(3,9)

!---
  tempx3inline(ij,1,3) = &
    tempx3(ij,1,1)*hprimewgll_zz(3,1) + tempx3(ij,1,2)*hprimewgll_zz(3,2) + &
    tempx3(ij,1,3)*hprimewgll_zz(3,3) + tempx3(ij,1,4)*hprimewgll_zz(3,4) + &
    tempx3(ij,1,5)*hprimewgll_zz(3,5) + tempx3(ij,1,6)*hprimewgll_zz(3,6) + &
    tempx3(ij,1,7)*hprimewgll_zz(3,7) + tempx3(ij,1,8)*hprimewgll_zz(3,8) + &
    tempx3(ij,1,9)*hprimewgll_zz(3,9)

!---
!--- ij is actually jk below
  tempx1inline(4,ij,1) = &
    tempx1(1,ij,1)*hprimewgll_xx(4,1) + tempx1(2,ij,1)*hprimewgll_xx(4,2) + &
    tempx1(3,ij,1)*hprimewgll_xx(4,3) + tempx1(4,ij,1)*hprimewgll_xx(4,4) + &
    tempx1(5,ij,1)*hprimewgll_xx(4,5) + tempx1(6,ij,1)*hprimewgll_xx(4,6) + &
    tempx1(7,ij,1)*hprimewgll_xx(4,7) + tempx1(8,ij,1)*hprimewgll_xx(4,8) + &
    tempx1(9,ij,1)*hprimewgll_xx(4,9)

!---
  tempx2inline(i,4,k) = &
    tempx2(i,1,k)*hprimewgll_yy(4,1) + tempx2(i,2,k)*hprimewgll_yy(4,2) + &
    tempx2(i,3,k)*hprimewgll_yy(4,3) + tempx2(i,4,k)*hprimewgll_yy(4,4) + &
    tempx2(i,5,k)*hprimewgll_yy(4,5) + tempx2(i,6,k)*hprimewgll_yy(4,6) + &
    tempx2(i,7,k)*hprimewgll_yy(4,7) + tempx2(i,8,k)*hprimewgll_yy(4,8) + &
    tempx2(i,9,k)*hprimewgll_yy(4,9)

!---
  tempx3inline(ij,1,4) = &
    tempx3(ij,1,1)*hprimewgll_zz(4,1) + tempx3(ij,1,2)*hprimewgll_zz(4,2) + &
    tempx3(ij,1,3)*hprimewgll_zz(4,3) + tempx3(ij,1,4)*hprimewgll_zz(4,4) + &
    tempx3(ij,1,5)*hprimewgll_zz(4,5) + tempx3(ij,1,6)*hprimewgll_zz(4,6) + &
    tempx3(ij,1,7)*hprimewgll_zz(4,7) + tempx3(ij,1,8)*hprimewgll_zz(4,8) + &
    tempx3(ij,1,9)*hprimewgll_zz(4,9)

!---
!--- ij is actually jk below
  tempx1inline(5,ij,1) = &
    tempx1(1,ij,1)*hprimewgll_xx(5,1) + tempx1(2,ij,1)*hprimewgll_xx(5,2) + &
    tempx1(3,ij,1)*hprimewgll_xx(5,3) + tempx1(4,ij,1)*hprimewgll_xx(5,4) + &
    tempx1(5,ij,1)*hprimewgll_xx(5,5) + tempx1(6,ij,1)*hprimewgll_xx(5,6) + &
    tempx1(7,ij,1)*hprimewgll_xx(5,7) + tempx1(8,ij,1)*hprimewgll_xx(5,8) + &
    tempx1(9,ij,1)*hprimewgll_xx(5,9)

!---
  tempx2inline(i,5,k) = &
    tempx2(i,1,k)*hprimewgll_yy(5,1) + tempx2(i,2,k)*hprimewgll_yy(5,2) + &
    tempx2(i,3,k)*hprimewgll_yy(5,3) + tempx2(i,4,k)*hprimewgll_yy(5,4) + &
    tempx2(i,5,k)*hprimewgll_yy(5,5) + tempx2(i,6,k)*hprimewgll_yy(5,6) + &
    tempx2(i,7,k)*hprimewgll_yy(5,7) + tempx2(i,8,k)*hprimewgll_yy(5,8) + &
    tempx2(i,9,k)*hprimewgll_yy(5,9)

!---
  tempx3inline(ij,1,5) = &
    tempx3(ij,1,1)*hprimewgll_zz(5,1) + tempx3(ij,1,2)*hprimewgll_zz(5,2) + &
    tempx3(ij,1,3)*hprimewgll_zz(5,3) + tempx3(ij,1,4)*hprimewgll_zz(5,4) + &
    tempx3(ij,1,5)*hprimewgll_zz(5,5) + tempx3(ij,1,6)*hprimewgll_zz(5,6) + &
    tempx3(ij,1,7)*hprimewgll_zz(5,7) + tempx3(ij,1,8)*hprimewgll_zz(5,8) + &
    tempx3(ij,1,9)*hprimewgll_zz(5,9)

!---
!--- ij is actually jk below
  tempx1inline(6,ij,1) = &
    tempx1(1,ij,1)*hprimewgll_xx(6,1) + tempx1(2,ij,1)*hprimewgll_xx(6,2) + &
    tempx1(3,ij,1)*hprimewgll_xx(6,3) + tempx1(4,ij,1)*hprimewgll_xx(6,4) + &
    tempx1(5,ij,1)*hprimewgll_xx(6,5) + tempx1(6,ij,1)*hprimewgll_xx(6,6) + &
    tempx1(7,ij,1)*hprimewgll_xx(6,7) + tempx1(8,ij,1)*hprimewgll_xx(6,8) + &
    tempx1(9,ij,1)*hprimewgll_xx(6,9)

!---
  tempx2inline(i,6,k) = &
    tempx2(i,1,k)*hprimewgll_yy(6,1) + tempx2(i,2,k)*hprimewgll_yy(6,2) + &
    tempx2(i,3,k)*hprimewgll_yy(6,3) + tempx2(i,4,k)*hprimewgll_yy(6,4) + &
    tempx2(i,5,k)*hprimewgll_yy(6,5) + tempx2(i,6,k)*hprimewgll_yy(6,6) + &
    tempx2(i,7,k)*hprimewgll_yy(6,7) + tempx2(i,8,k)*hprimewgll_yy(6,8) + &
    tempx2(i,9,k)*hprimewgll_yy(6,9)

!---
  tempx3inline(ij,1,6) = &
    tempx3(ij,1,1)*hprimewgll_zz(6,1) + tempx3(ij,1,2)*hprimewgll_zz(6,2) + &
    tempx3(ij,1,3)*hprimewgll_zz(6,3) + tempx3(ij,1,4)*hprimewgll_zz(6,4) + &
    tempx3(ij,1,5)*hprimewgll_zz(6,5) + tempx3(ij,1,6)*hprimewgll_zz(6,6) + &
    tempx3(ij,1,7)*hprimewgll_zz(6,7) + tempx3(ij,1,8)*hprimewgll_zz(6,8) + &
    tempx3(ij,1,9)*hprimewgll_zz(6,9)

!---
!--- ij is actually jk below
  tempx1inline(7,ij,1) = &
    tempx1(1,ij,1)*hprimewgll_xx(7,1) + tempx1(2,ij,1)*hprimewgll_xx(7,2) + &
    tempx1(3,ij,1)*hprimewgll_xx(7,3) + tempx1(4,ij,1)*hprimewgll_xx(7,4) + &
    tempx1(5,ij,1)*hprimewgll_xx(7,5) + tempx1(6,ij,1)*hprimewgll_xx(7,6) + &
    tempx1(7,ij,1)*hprimewgll_xx(7,7) + tempx1(8,ij,1)*hprimewgll_xx(7,8) + &
    tempx1(9,ij,1)*hprimewgll_xx(7,9)

!---
  tempx2inline(i,7,k) = &
    tempx2(i,1,k)*hprimewgll_yy(7,1) + tempx2(i,2,k)*hprimewgll_yy(7,2) + &
    tempx2(i,3,k)*hprimewgll_yy(7,3) + tempx2(i,4,k)*hprimewgll_yy(7,4) + &
    tempx2(i,5,k)*hprimewgll_yy(7,5) + tempx2(i,6,k)*hprimewgll_yy(7,6) + &
    tempx2(i,7,k)*hprimewgll_yy(7,7) + tempx2(i,8,k)*hprimewgll_yy(7,8) + &
    tempx2(i,9,k)*hprimewgll_yy(7,9)

!---
  tempx3inline(ij,1,7) = &
    tempx3(ij,1,1)*hprimewgll_zz(7,1) + tempx3(ij,1,2)*hprimewgll_zz(7,2) + &
    tempx3(ij,1,3)*hprimewgll_zz(7,3) + tempx3(ij,1,4)*hprimewgll_zz(7,4) + &
    tempx3(ij,1,5)*hprimewgll_zz(7,5) + tempx3(ij,1,6)*hprimewgll_zz(7,6) + &
    tempx3(ij,1,7)*hprimewgll_zz(7,7) + tempx3(ij,1,8)*hprimewgll_zz(7,8) + &
    tempx3(ij,1,9)*hprimewgll_zz(7,9)

!---
!--- ij is actually jk below
  tempx1inline(8,ij,1) = &
    tempx1(1,ij,1)*hprimewgll_xx(8,1) + tempx1(2,ij,1)*hprimewgll_xx(8,2) + &
    tempx1(3,ij,1)*hprimewgll_xx(8,3) + tempx1(4,ij,1)*hprimewgll_xx(8,4) + &
    tempx1(5,ij,1)*hprimewgll_xx(8,5) + tempx1(6,ij,1)*hprimewgll_xx(8,6) + &
    tempx1(7,ij,1)*hprimewgll_xx(8,7) + tempx1(8,ij,1)*hprimewgll_xx(8,8) + &
    tempx1(9,ij,1)*hprimewgll_xx(8,9)

!---
  tempx2inline(i,8,k) = &
    tempx2(i,1,k)*hprimewgll_yy(8,1) + tempx2(i,2,k)*hprimewgll_yy(8,2) + &
    tempx2(i,3,k)*hprimewgll_yy(8,3) + tempx2(i,4,k)*hprimewgll_yy(8,4) + &
    tempx2(i,5,k)*hprimewgll_yy(8,5) + tempx2(i,6,k)*hprimewgll_yy(8,6) + &
    tempx2(i,7,k)*hprimewgll_yy(8,7) + tempx2(i,8,k)*hprimewgll_yy(8,8) + &
    tempx2(i,9,k)*hprimewgll_yy(8,9)

!---
  tempx3inline(ij,1,8) = &
    tempx3(ij,1,1)*hprimewgll_zz(8,1) + tempx3(ij,1,2)*hprimewgll_zz(8,2) + &
    tempx3(ij,1,3)*hprimewgll_zz(8,3) + tempx3(ij,1,4)*hprimewgll_zz(8,4) + &
    tempx3(ij,1,5)*hprimewgll_zz(8,5) + tempx3(ij,1,6)*hprimewgll_zz(8,6) + &
    tempx3(ij,1,7)*hprimewgll_zz(8,7) + tempx3(ij,1,8)*hprimewgll_zz(8,8) + &
    tempx3(ij,1,9)*hprimewgll_zz(8,9)

!---
!--- ij is actually jk below
  tempx1inline(9,ij,1) = &
    tempx1(1,ij,1)*hprimewgll_xx(9,1) + tempx1(2,ij,1)*hprimewgll_xx(9,2) + &
    tempx1(3,ij,1)*hprimewgll_xx(9,3) + tempx1(4,ij,1)*hprimewgll_xx(9,4) + &
    tempx1(5,ij,1)*hprimewgll_xx(9,5) + tempx1(6,ij,1)*hprimewgll_xx(9,6) + &
    tempx1(7,ij,1)*hprimewgll_xx(9,7) + tempx1(8,ij,1)*hprimewgll_xx(9,8) + &
    tempx1(9,ij,1)*hprimewgll_xx(9,9)

!---
  tempx2inline(i,9,k) = &
    tempx2(i,1,k)*hprimewgll_yy(9,1) + tempx2(i,2,k)*hprimewgll_yy(9,2) + &
    tempx2(i,3,k)*hprimewgll_yy(9,3) + tempx2(i,4,k)*hprimewgll_yy(9,4) + &
    tempx2(i,5,k)*hprimewgll_yy(9,5) + tempx2(i,6,k)*hprimewgll_yy(9,6) + &
    tempx2(i,7,k)*hprimewgll_yy(9,7) + tempx2(i,8,k)*hprimewgll_yy(9,8) + &
    tempx2(i,9,k)*hprimewgll_yy(9,9)

!---
  tempx3inline(ij,1,9) = &
    tempx3(ij,1,1)*hprimewgll_zz(9,1) + tempx3(ij,1,2)*hprimewgll_zz(9,2) + &
    tempx3(ij,1,3)*hprimewgll_zz(9,3) + tempx3(ij,1,4)*hprimewgll_zz(9,4) + &
    tempx3(ij,1,5)*hprimewgll_zz(9,5) + tempx3(ij,1,6)*hprimewgll_zz(9,6) + &
    tempx3(ij,1,7)*hprimewgll_zz(9,7) + tempx3(ij,1,8)*hprimewgll_zz(9,8) + &
    tempx3(ij,1,9)*hprimewgll_zz(9,9)

  enddo

  if(GRAVITY_VAL) then
    do ijk=1,NGLLCUBE
      sum_terms(ijk,1,1) = &
            - (wgllwgll_yz_no_i(1,ijk,1,1)*tempx1inline(ijk,1,1) + &
               wgllwgll_xz_no_j(1,ijk,1,1)*tempx2inline(ijk,1,1) + &
               wgllwgll_xy_no_k(1,ijk,1,1)*tempx3inline(ijk,1,1)) + &
               gravity_term(ijk,1,1)
    enddo
  else
    do ijk=1,NGLLCUBE
      sum_terms(ijk,1,1) = &
            - (wgllwgll_yz_no_i(1,ijk,1,1)*tempx1inline(ijk,1,1) + &
               wgllwgll_xz_no_j(1,ijk,1,1)*tempx2inline(ijk,1,1) + &
               wgllwgll_xy_no_k(1,ijk,1,1)*tempx3inline(ijk,1,1))
    enddo
  endif

! sum contributions to the global mesh
!CDIR NODEP(accelfluid)
    do ijk=1,NGLLCUBE
      iglob = ibool(ijk,1,1,ispec)
      if(iter == 1 .or. update_dof(iglob)) &
        accelfluid(iglob) = accelfluid(iglob) + sum_terms(ijk,1,1)
    enddo

! update rotation term with Euler scheme if needed depending on iteration
! only in matching layers if not first iteration
    if(ROTATION_VAL .and. (iter == 2 .or. (iter == 1 .and. idoubling(ispec) /= IFLAG_TOP_OUTER_CORE &
        .and. idoubling(ispec) /= IFLAG_TOP_OUTER_CORE_LEV2 &
        .and. idoubling(ispec) /= IFLAG_BOTTOM_OUTER_CORE &
        .and. idoubling(ispec) /= IFLAG_BOTTOM_OUTER_CORE_LEV2))) then

! use the source saved above
    do ijk=1,NGLLCUBE
      A_array_rotation(ijk,1,1,ispec) = A_array_rotation(ijk,1,1,ispec) + source_euler_A(ijk,1,1)
      B_array_rotation(ijk,1,1,ispec) = B_array_rotation(ijk,1,1,ispec) + source_euler_B(ijk,1,1)
    enddo

    endif

  endif   ! end test only matching layers if not first iteration

  enddo   ! spectral element loop

  end subroutine compute_forces_outer_core

