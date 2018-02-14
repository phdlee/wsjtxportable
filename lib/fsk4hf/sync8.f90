subroutine sync8(dd,nfa,nfb,syncmin,nfqso,s,candidate,ncand,sbase)

  include 'ft8_params.f90'
! Search over +/- 2.5s relative to 0.5s TX start time. 
  parameter (JZ=62)                        
  complex cx(0:NH1)
  real s(NH1,NHSYM)
  real savg(NH1)
  real sbase(NH1)
  real x(NFFT1)
  real sync2d(NH1,-JZ:JZ)
  real red(NH1)
  real candidate0(3,200)
  real candidate(3,200)
  real dd(NMAX)
  integer jpeak(NH1)
  integer indx(NH1)
  integer ii(1)
  integer icos7(0:6)
  data icos7/2,5,6,0,4,1,3/                   !Costas 7x7 tone pattern
  equivalence (x,cx)

! Compute symbol spectra, stepping by NSTEP steps.  
  savg=0.
  tstep=NSTEP/12000.0                         
  df=12000.0/NFFT1                            !3.125 Hz
  fac=1.0/300.0
  do j=1,NHSYM
     ia=(j-1)*NSTEP + 1
     ib=ia+NSPS-1
     x(1:NSPS)=fac*dd(ia:ib)
     x(NSPS+1:)=0.
     call four2a(x,NFFT1,1,-1,0)              !r2c FFT
     do i=1,NH1
        s(i,j)=real(cx(i))**2 + aimag(cx(i))**2
     enddo
     savg=savg + s(1:NH1,j)                   !Average spectrum
  enddo
  call baseline(savg,nfa,nfb,sbase)
!  savg=savg/NHSYM
!  do i=1,NH1
!     write(51,3051) i*df,savg(i),db(savg(i))
!3051 format(f10.3,e12.3,f12.3)
!  enddo

  ia=max(1,nint(nfa/df))
  ib=nint(nfb/df)
  nssy=NSPS/NSTEP   ! # steps per symbol
  nfos=NFFT1/NSPS   ! # frequency bin oversampling factor
  jstrt=0.5/tstep

  do i=ia,ib
     do j=-JZ,+JZ
        ta=0.
        tb=0.
        tc=0.
        t0a=0.
        t0b=0.
        t0c=0.
        do n=0,6
           k=j+jstrt+nssy*n
           if(k.ge.1.and.k.le.NHSYM) then
              ta=ta + s(i+nfos*icos7(n),k)
              t0a=t0a + sum(s(i:i+nfos*6:nfos,k))
           endif
           tb=tb + s(i+nfos*icos7(n),k+nssy*36)
           t0b=t0b + sum(s(i:i+nfos*6:nfos,k+nssy*36))
           if(k+nssy*72.le.NHSYM) then
              tc=tc + s(i+nfos*icos7(n),k+nssy*72)
              t0c=t0c + sum(s(i:i+nfos*6:nfos,k+nssy*72))
           endif
        enddo
        t=ta+tb+tc
        t0=t0a+t0b+t0c
        t0=(t0-t)/6.0
        sync_abc=t/t0

        t=tb+tc
        t0=t0b+t0c
        t0=(t0-t)/6.0
        sync_bc=t/t0
        sync2d(i,j)=max(sync_abc,sync_bc)
     enddo
  enddo

  red=0.
  do i=ia,ib
     ii=maxloc(sync2d(i,-JZ:JZ)) - 1 - JZ
     j0=ii(1)
     jpeak(i)=j0
     red(i)=sync2d(i,j0)
!     write(52,3052) i*df,red(i),db(red(i))
!3052 format(3f12.3)
  enddo
  iz=ib-ia+1
  call indexx(red(ia:ib),iz,indx)
  ibase=indx(nint(0.40*iz)) - 1 + ia
  base=red(ibase)
  red=red/base

  candidate0=0.
  k=0
  do i=1,200
     n=ia + indx(iz+1-i) - 1
     if(red(n).lt.syncmin) exit
     if(k.lt.200) k=k+1
     candidate0(1,k)=n*df
     candidate0(2,k)=(jpeak(n)-1)*tstep
     candidate0(3,k)=red(n)
  enddo
  ncand=k

! Put nfqso at top of list, and save only the best of near-dupe freqs.  
  do i=1,ncand
     if(abs(candidate0(1,i)-nfqso).lt.10.0) candidate0(1,i)=-candidate0(1,i)
     if(i.ge.2) then
        do j=1,i-1
           fdiff=abs(candidate0(1,i))-abs(candidate0(1,j))
           if(abs(fdiff).lt.4.0) then
              if(candidate0(3,i).ge.candidate0(3,j)) candidate0(3,j)=0.
              if(candidate0(3,i).lt.candidate0(3,j)) candidate0(3,i)=0.
           endif
        enddo
!        write(*,3001) i,candidate0(1,i-1),candidate0(1,i),candidate0(3,i-1),  &
!             candidate0(3,i)
!3001    format(i2,4f8.1)
     endif
  enddo
  
  fac=20.0/maxval(s)
  s=fac*s

! Sort by sync
!  call indexx(candidate0(3,1:ncand),ncand,indx)
! Sort by frequency 
  call indexx(candidate0(1,1:ncand),ncand,indx)
  k=1
!  do i=ncand,1,-1
  do i=1,ncand
     j=indx(i)
!     if( candidate0(3,j) .ge. syncmin .and. candidate0(2,j).ge.-1.5 ) then
     if( candidate0(3,j) .ge. syncmin ) then
       candidate(1,k)=abs(candidate0(1,j))
       candidate(2,k)=candidate0(2,j)
       candidate(3,k)=candidate0(3,j)
       k=k+1
     endif
  enddo
  ncand=k-1
  return
end subroutine sync8
