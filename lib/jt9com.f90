  use, intrinsic :: iso_c_binding, only: c_int, c_short, c_float, c_char, c_bool

  include 'constants.f90'

  !
  ! these structures must be kept in sync with ../commons.h
  !
  type, bind(C) :: params_block
     integer(c_int) :: nutc
     logical(c_bool) :: ndiskdat
     integer(c_int) :: ntr
     integer(c_int) :: nQSOProgress ! See MainWindow::m_QSOProgress for values
     integer(c_int) :: nfqso
     integer(c_int) :: nftx
     logical(c_bool) :: newdat
     integer(c_int) :: npts8
     integer(c_int) :: nfa
     integer(c_int) :: nfsplit
     integer(c_int) :: nfb
     integer(c_int) :: ntol
     integer(c_int) :: kin
     integer(c_int) :: nzhsym
     integer(c_int) :: nsubmode
     logical(c_bool) :: nagain
     integer(c_int) :: ndepth
     logical(c_bool) :: lapon 
     integer(c_int) :: napwid
     integer(c_int) :: ntxmode
     integer(c_int) :: nmode
     integer(c_int) :: minw
     logical(c_bool) :: nclearave
     integer(c_int) :: minsync
     real(c_float) :: emedelay
     real(c_float) :: dttol
     integer(c_int) :: nlist
     integer(c_int) :: listutc(10)
     integer(c_int) :: n2pass
     integer(c_int) :: nranera
     integer(c_int) :: naggressive
     logical(c_bool) :: nrobust
     integer(c_int) :: nexp_decode
     character(kind=c_char, len=20) :: datetime
     character(kind=c_char, len=12) :: mycall
     character(kind=c_char, len=6) :: mygrid
     character(kind=c_char, len=12) :: hiscall
     character(kind=c_char, len=6) :: hisgrid
  end type params_block

  type, bind(C) :: dec_data
     real(c_float) :: ss(184,NSMAX)
     real(c_float) :: savg(NSMAX)
     real(c_float) :: sred(5760)
     integer(c_short) :: id2(NMAX)
     type(params_block) :: params
  end type dec_data
