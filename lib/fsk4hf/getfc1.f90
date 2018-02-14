subroutine getfc1(c,fc1)

  parameter (KK=84)                     !Information bits (72 + CRC12)
  parameter (ND=168)                    !Data symbols: LDPC (168,84), r=1/2
  parameter (NS=65)                     !Sync symbols (2 x 26 + Barker 13)
  parameter (NR=3)                      !Ramp up/down
  parameter (NN=NR+NS+ND)               !Total symbols (236)
  parameter (NSPS=16)                   !Samples per MSK symbol (16)
  parameter (N2=2*NSPS)                 !Samples per OQPSK symbol (32)
  parameter (N13=13*N2)                 !Samples in central sync vector (416)
  parameter (NZ=NSPS*NN)                !Samples in baseband waveform (3760)
  parameter (NFFT1=4*NSPS,NH1=NFFT1/2)

  complex c(0:NZ-1)                     !Complex waveform
  complex c2(0:NFFT1-1)                 !Short spectra
  real s(-NH1+1:NH1)                    !Coarse spectrum

  nspec=NZ/NFFT1
  fs=12000.0/72.0
  df1=fs/NFFT1
  s=0.
  do k=1,nspec
     ia=(k-1)*N2
     ib=ia+N2-1
     c2(0:N2-1)=c(ia:ib)
     c2(N2:)=0.
     call four2a(c2,NFFT1,1,-1,1)
     do i=0,NFFT1-1
        j=i
        if(j.gt.NH1) j=j-NFFT1
        s(j)=s(j) + real(c2(i))**2 + aimag(c2(i))**2
     enddo
  enddo
!        call smo121(s,NFFT1)
  smax=0.
  ipk=0
  fc1=0.
  ia=nint(40.0/df1)
  do i=-ia,ia
     f=i*df1
     if(s(i).gt.smax) then
        smax=s(i)
        ipk=i
        fc1=f
     endif
!            write(51,3001) f,s(i),db(s(i))
! 3001       format(f10.3,e12.3,f10.3)
  enddo

! The following is for testing SNR calibration:
!        sp3n=(s(ipk-1)+s(ipk)+s(ipk+1))               !Sig + 3*noise
!        base=(sum(s)-sp3n)/(NFFT1-3.0)                !Noise per bin
!        psig=sp3n-3*base                              !Sig only
!        pnoise=(2500.0/df1)*base                      !Noise in 2500 Hz
!        xsnrdb=db(psig/pnoise)

  return
end subroutine getfc1
