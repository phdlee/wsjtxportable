subroutine extract(s3,nadd,mode65,ntrials,naggressive,ndepth,nflip,     &
     mycall_12,hiscall_12,hisgrid,nexp_decode,ncount,nhist,decoded,     &
     ltext,nft,qual)

! Input:
!   s3       64-point spectra for each of 63 data symbols
!   nadd     number of spectra summed into s3
!   nqd      0/1 to indicate decode attempt at QSO frequency

! Output:
!   ncount   number of symbols requiring correction (-1 for no KV decode)
!   nhist    maximum number of identical symbol values
!   decoded  decoded message (if ncount >=0)
!   ltext    true if decoded message is free text
!   nft      0=no decode; 1=FT decode; 2=hinted decode

  use prog_args                       !shm_key, exe_dir, data_dir
  use packjt
  use jt65_mod
  use timer_module, only: timer

  real s3(64,63)
  character decoded*22
  character*12 mycall_12,hiscall_12
  character*6 mycall,hiscall,hisgrid
  integer dat4(12)
  integer mrsym(63),mr2sym(63),mrprob(63),mr2prob(63)
  integer correct(63),tmp(63)
  logical ltext
  common/chansyms65/correct
  save

  if(mode65.eq.-99) stop                   !Silence compiler warning
  mycall=mycall_12(1:6)
  hiscall=hiscall_12(1:6)
  qual=0.
  nbirdie=20
  npct=50
  afac1=1.1
  nft=0
  nfail=0
  decoded='                      '
  call pctile(s3,4032,npct,base)
  s3=s3/base
  s3a=s3                                            !###

! Get most reliable and second-most-reliable symbol values, and their
! probabilities
1 call demod64a(s3,nadd,afac1,mrsym,mrprob,mr2sym,mr2prob,ntest,nlow)

  call chkhist(mrsym,nhist,ipk)       !Test for birdies and QRM
  if(nhist.ge.nbirdie) then
     nfail=nfail+1
     call pctile(s3,4032,npct,base)
     s3(ipk,1:63)=base
     if(nfail.gt.30) then
        decoded='                      '
        ncount=-1
        go to 900
     endif
     go to 1
  endif

  mrs=mrsym
  mrs2=mr2sym

  call graycode65(mrsym,63,-1)        !Remove gray code 
  call interleave63(mrsym,-1)         !Remove interleaving
  call interleave63(mrprob,-1)

  call graycode65(mr2sym,63,-1)      !Remove gray code and interleaving
  call interleave63(mr2sym,-1)       !from second-most-reliable symbols
  call interleave63(mr2prob,-1)
  ntry=0

  call timer('ftrsd   ',0)
  param=0
  call ftrsd2(mrsym,mrprob,mr2sym,mr2prob,ntrials,correct,param,ntry)
  call timer('ftrsd   ',1)
  ncandidates=param(0)
  nhard=param(1)
  nsoft=param(2)
  nerased=param(3)
  rtt=0.001*param(4)
  ntotal=param(5)
  qual=0.001*param(7)
  nd0=81
  r0=0.87
  if(naggressive.eq.10) then
     nd0=83
     r0=0.90
  endif
  if(ntotal.le.nd0 .and. rtt.le.r0) nft=1

  if(nft.eq.0 .and. iand(ndepth,32).eq.32) then
     qmin=2.0 - 0.1*naggressive
     call timer('hint65  ',0)
     call hint65(s3,mrs,mrs2,nadd,nflip,mycall,hiscall,hisgrid,qual,decoded)
     if(qual.ge.qmin) then
        nft=2
        ncount=0
     else
        decoded='                      '
        ntry=0
     endif
     call timer('hint65  ',1)
     go to 900
  endif

  ncount=-1
  decoded='                      '
  ltext=.false.
  if(nft.gt.0) then
! Turn the corrected symbol array into channel symbols for subtraction;
! pass it back to jt65a via common block "chansyms65".
     do i=1,12
        dat4(i)=correct(13-i)
     enddo
     do i=1,63
       tmp(i)=correct(64-i)
     enddo
     correct(1:63)=tmp(1:63)
     call interleave63(correct,63,1)
     call graycode65(correct,63,1)
     call unpackmsg(dat4,decoded,.false.,'      ')     !Unpack the user message
     ncount=0
     if(iand(dat4(10),8).ne.0) ltext=.true.
  endif
900 continue
  if(nft.eq.1 .and. nhard.lt.0) decoded='                      '

  return
end subroutine extract

subroutine getpp(workdat,p)

  use jt65_mod
  integer workdat(63)
  integer a(63)

  a(1:63)=workdat(63:1:-1)
  call interleave63(a,1)
  call graycode(a,63,1,a)

  psum=0.
  do j=1,63
     i=a(j)+1
     x=s3a(i,j)
     s3a(i,j)=0.
     psum=psum + x
     s3a(i,j)=x
  enddo
  p=psum/63.0

  return
end subroutine getpp
