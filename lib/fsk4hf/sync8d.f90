subroutine sync8d(cd0,i0,ctwk,itwk,sync)

! Compute sync power for a complex, downsampled FT8 signal.

  parameter(NP2=2812,NDOWN=60)
  complex cd0(3125)
  complex csync(0:6,32)
  complex csync2(32)
  complex ctwk(32)
  complex z1,z2,z3
  logical first
  integer icos7(0:6)
  data icos7/2,5,6,0,4,1,3/
  data first/.true./
  save first,twopi,fs2,dt2,taus,baud,csync

  p(z1)=real(z1)**2 + aimag(z1)**2          !Statement function for power

! Set some constants and compute the csync array.  
  if( first ) then
    twopi=8.0*atan(1.0)
    fs2=12000.0/NDOWN                       !Sample rate after downsampling
    dt2=1/fs2                               !Corresponding sample interval
    taus=32*dt2                             !Symbol duration
    baud=1.0/taus                           !Keying rate
    do i=0,6
      phi=0.0
      dphi=twopi*icos7(i)*baud*dt2  
      do j=1,32
        csync(i,j)=cmplx(cos(phi),sin(phi)) !Waveform for 7x7 Costas array
        phi=mod(phi+dphi,twopi)
      enddo
    enddo
    first=.false.
  endif

  sync=0
  do i=0,6                              !Sum over 7 Costas frequencies and
     i1=i0+i*32                         !three Costas arrays
     i2=i1+36*32
     i3=i1+72*32
     csync2=csync(i,1:32)
     if(itwk.eq.1) csync2=ctwk*csync2      !Tweak the frequency
     z1=0.
     z2=0.
     z3=0.
     if(i1.ge.1 .and. i1+31.le.NP2) z1=sum(cd0(i1:i1+31)*conjg(csync2))
     if(i2.ge.1 .and. i2+31.le.NP2) z2=sum(cd0(i2:i2+31)*conjg(csync2))
     if(i3.ge.1 .and. i3+31.le.NP2) z3=sum(cd0(i3:i3+31)*conjg(csync2))
     sync = sync + p(z1) + p(z2) + p(z3)
  enddo

  return
end subroutine sync8d
