!=====================================================================
!
!          S p e c f e m 3 D  G l o b e  V e r s i o n  6 . 0
!          --------------------------------------------------
!
!     Main historical authors: Dimitri Komatitsch and Jeroen Tromp
!                        Princeton University, USA
!                and CNRS / University of Marseille, France
!                 (there are currently many more authors!)
! (c) Princeton University and CNRS / University of Marseille, April 2014
!
! This program is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 2 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License along
! with this program; if not, write to the Free Software Foundation, Inc.,
! 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
!
!=====================================================================

!
!--- user can modify parameters below
!

!!-----------------------------------------------------------
!!
!! Model parameterization
!!
!!-----------------------------------------------------------
! by default, this algorithm uses transverse isotropic (bulk,bulk_betav,bulk_betah,eta) kernels to sum up
! if you prefer using isotropic kernels, set flags below accordingly

  ! if you prefer using isotropic kernels (bulk,bulk_beta,rho) kernels, set this flag to true
  logical, parameter :: USE_ISO_KERNELS = .false.

  ! if you prefer isotropic  (alpha,beta,rho) kernels, set this flag to true
  logical, parameter :: USE_ALPHA_BETA_RHO = .false.

!!-----------------------------------------------------------
!!
!! Scaling laws
!!
!!-----------------------------------------------------------
  ! ignore rho kernel, but use density perturbations as a scaling of Vs perturbations
  logical, parameter :: USE_RHO_SCALING = .true.

  ! in case of rho scaling, specifies density scaling factor with shear perturbations
  ! see e.g. Montagner & Anderson (1989), Panning & Romanowicz (2006)
  real(kind=CUSTOM_REAL),parameter :: RHO_SCALING = 0.33_CUSTOM_REAL

!!-----------------------------------------------------------
!!
!! Transversely isotropic (TI) model constraints
!!
!!-----------------------------------------------------------
  ! constraint on eta model
  real(kind=CUSTOM_REAL),parameter :: LIMIT_ETA_MIN = 0.5_CUSTOM_REAL
  real(kind=CUSTOM_REAL),parameter :: LIMIT_ETA_MAX = 1.5_CUSTOM_REAL

!!-----------------------------------------------------------
!!
!! Approximate hessian
!!
!!-----------------------------------------------------------
  ! 1 permille of maximum for inverting hessian
  real(kind=CUSTOM_REAL),parameter :: THRESHOLD_HESS = 1.e-3

  ! sums all hessians before inverting and preconditioning
  ! by default should be set to .true.
  logical, parameter :: USE_HESS_SUM = .true.

!!-----------------------------------------------------------
!!
!! Maximum kernel scaling
!!
!!-----------------------------------------------------------
! kernel values are maximum at very shallow depth (due to receivers at surface) which leads to strong
! model updates closest to the surface. scaling the kernel values, such that the maximum is taken slightly below
! the surface (between 50km - 100km) leads to a "more balanced" gradient, i.e., a better model update in deeper parts

  ! by default, sets maximum update in this depth range
  logical,parameter :: USE_DEPTH_RANGE_MAXIMUM = .true.

  ! normalized radii
  ! top at 50km depth
  real(kind=CUSTOM_REAL),parameter :: R_top = (6371.0 - 50.0 ) / R_EARTH_KM ! shallow depth
  ! bottom at 100km depth
  real(kind=CUSTOM_REAL),parameter :: R_bottom = (6371.0 - 100.0 ) / R_EARTH_KM ! deep depth

!!-----------------------------------------------------------
!!
!! Source mask
!!
!!-----------------------------------------------------------
  ! uses source mask to blend out source elements
  logical, parameter :: USE_SOURCE_MASK = .false.

!!-----------------------------------------------------------
!!
!! Conjugate gradients
!!
!!-----------------------------------------------------------
! conjugate gradient step lengths are calculated based on gradient norms,
! see Polak & Ribiere (1969).

  ! this uses separate scaling for each parameters bulk,betav,betah,eta
  ! (otherwise it will calculate a single steplength to scale all gradients)
  logical,parameter :: USE_SEPARATE_CG_STEPLENGTHS = .false.

  ! directory which contains kernels/gradients from former iteration
  character(len=150),parameter :: kernel_old_dir = './KERNELS/OUTPUT_SUM.old'


!!-----------------------------------------------------------
!!
!! Kernel lists
!!
!!-----------------------------------------------------------
  ! maximum number of kernels listed
  integer, parameter :: MAX_NUM_NODES = 10000

  ! default list name
  character(len=*), parameter :: kernel_file_list = './kernels_list.txt'

