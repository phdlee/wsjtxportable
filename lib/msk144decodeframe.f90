subroutine msk144decodeframe(c,softbits,msgreceived,nsuccess,recent_calls,nrecent)
!  use timer_module, only: timer

  parameter (NSPM=864)
  character*22 msgreceived
  character*12 recent_calls(nrecent)
  complex cb(42)
  complex cfac,cca,ccb
  complex c(NSPM)
  integer*1 decoded(80)
  integer s8(8),hardbits(144)
  real*8 dt, fs, pi, twopi
  real cbi(42),cbq(42)
  real pp(12)
  real softbits(144)
  real llr(128)
  logical first
  data first/.true./
  data s8/0,1,1,1,0,0,1,0/
  save first,cb,fs,pi,twopi,dt,s8,pp

  if(first) then
! define half-sine pulse and raised-cosine edge window
     pi=4d0*datan(1d0)
     twopi=8d0*datan(1d0)
     fs=12000.0
     dt=1.0/fs

     do i=1,12
       angle=(i-1)*pi/12.0
       pp(i)=sin(angle)
     enddo

! define the sync word waveforms
     s8=2*s8-1  
     cbq(1:6)=pp(7:12)*s8(1)
     cbq(7:18)=pp*s8(3)
     cbq(19:30)=pp*s8(5)
     cbq(31:42)=pp*s8(7)
     cbi(1:12)=pp*s8(2)
     cbi(13:24)=pp*s8(4)
     cbi(25:36)=pp*s8(6)
     cbi(37:42)=pp(1:6)*s8(8)
     cb=cmplx(cbi,cbq)
     first=.false.
  endif

  nsuccess=0
  msgreceived=' '

! Estimate carrier phase. 
  cca=sum(c(1:1+41)*conjg(cb))
  ccb=sum(c(1+56*6:1+56*6+41)*conjg(cb))
  cfac=ccb*conjg(cca)
  phase0=atan2(imag(cca+ccb),real(cca+ccb))

! Remove phase error - want constellation rotated so that sample points lie on I/Q axes
  cfac=cmplx(cos(phase0),sin(phase0))
  c=c*conjg(cfac)

! matched filter - 
  softbits(1)=sum(imag(c(1:6))*pp(7:12))+sum(imag(c(864-5:864))*pp(1:6))
  softbits(2)=sum(real(c(1:12))*pp)
  do i=2,72
    softbits(2*i-1)=sum(imag(c(1+(i-1)*12-6:1+(i-1)*12+5))*pp)
    softbits(2*i)=sum(real(c(7+(i-1)*12-6:7+(i-1)*12+5))*pp)
  enddo

! sync word hard error weight is used as a discriminator for 
! frames that have reasonable probability of decoding
  hardbits=0
  do i=1,144
    if( softbits(i) .ge. 0.0 ) then
      hardbits(i)=1
    endif
  enddo
  nbadsync1=(8-sum( (2*hardbits(1:8)-1)*s8 ) )/2
  nbadsync2=(8-sum( (2*hardbits(1+56:8+56)-1)*s8 ) )/2
  nbadsync=nbadsync1+nbadsync2
  if( nbadsync .gt. 4 ) then
    return
  endif

! normalize the softsymbols before submitting to decoder
  sav=sum(softbits)/144
  s2av=sum(softbits*softbits)/144
  ssig=sqrt(s2av-sav*sav)
  softbits=softbits/ssig

  sigma=0.75
  llr(1:48)=softbits(9:9+47)
  llr(49:128)=softbits(65:65+80-1)
  llr=2.0*llr/(sigma*sigma)
  
  max_iterations=10
!  call timer('bpdec144 ',0)
  call bpdecode144(llr,max_iterations,decoded,niterations)
!  call timer('bpdec144 ',1)
  if( niterations .ge. 0.0 ) then
    call extractmessage144(decoded,msgreceived,nhashflag,recent_calls,nrecent)
    if( nhashflag .gt. 0 ) then  ! CRCs match, so print it 
      nsuccess=1
    endif
  endif

  return
end subroutine msk144decodeframe
