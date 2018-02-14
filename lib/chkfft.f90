program chkfft

! Tests and times one-dimensional FFTs computed by four2a().
! An all-Fortran version of four2a() is available, but the preferred
! version uses calls to the FFTW library.

  parameter (NMAX=8*1024*1024)            !Maximum FFT length
  complex a(NMAX),b(NMAX)
  real ar(NMAX),br(NMAX)
  real mflops
  character infile*12,arg*8
  logical list
  common/patience/npatience
  equivalence (a,ar),(b,br)

  nargs=iargc()
  if(nargs.ne.5) then
     print*,'Usage: chkfft <nfft | infile> nr nw nc np'
     print*,'       nfft:   length of FFT'
     print*,'       nfft=0: do lengths 2^n, n=2^4 to 2^23'
     print*,'       infile: name of file with nfft values, one per line'
     print*,'       nr:     0/1 to not read (or read) wisdom'
     print*,'       nw:     0/1 to not write (or write) wisdom'
     print*,'       nc:     0/1 for real or complex data'
     print*,'       np:     0-4 patience for finding best algorithm'
     go to 999
  endif

  list=.false.
  nfft=-1
  call getarg(1,infile)
  open(10,file=infile,status='old',err=1)
  list=.true.                          !A valid file name was provided
  go to 2
1 read(infile,*) nfft                  !Takje first argument to be nfft
2  call getarg(2,arg)
  read(arg,*) nr
  call getarg(3,arg)
  read(arg,*) nw
  call getarg(4,arg)
  read(arg,*) ncomplex
  call getarg(5,arg)
  read(arg,*) npatience

  call sgran()

  if(list) write(*,1000) infile,nr,nw,ncomplex,npatience
1000 format(/'infile: ',a12,'   nr:',i2,'   nw',i2,'   nc:',i2,'   np:',i2/)
  if(.not.list) write(*,1002) nfft,nr,nw,ncomplex,npatience
1002 format(/'nfft: ',i10,'   nr:',i2,'   nw',i2,'   nc:',i2,'   np:',i2/)

  open(12,file='chkfft.out',status='unknown')
  open(13,file='fftwf_wisdom.dat',status='unknown')

  if(nr.ne.0) then
     call import_wisdom_from_file(isuccess,13)
     if(isuccess.eq.0) then
        write(*,1010) 
1010    format('Failed to import FFTW wisdom.')
        go to 999
     endif
  endif

  idum=-1                               !Set random seed
  ndim=1				!One-dimensional transforms
  do i=1,NMAX                           !Set random data
     x=gran()
     y=gran()
     b(i)=cmplx(x,y)                    !Generate random data
  enddo

  iters=1000000
  if(list .or. (nfft.gt.0)) then
     n1=1
     n2=1
     if(nfft.eq.-1) n2=999999
     write(*,1020) 
1020 format('    NFFT     Time        rms      MHz   MFlops  iters',    &
          '  tplan'/61('-'))
  else
     n1=4
     n2=23
     write(*,1030) 
1030 format(' n   N=2^n     Time        rms      MHz   MFlops  iters',  &
          '  tplan'/63('-'))
  endif

  do ii=n1,n2                           !Test one or more FFT lengths
     if(list) then
        read(10,*,end=900) nfft         !Read nfft from file
     else if(n2.gt.n1) then
        nfft=2**ii                      !Do powers of 2
     endif

     iformf=1
     iformb=1
     if(ncomplex.eq.0) then
        iformf=0                        !Real-to-complex transform
        iformb=-1                       !Complex-to-real (inverse) transform
     endif

     if(nfft.gt.NMAX) go to 900
     a(1:nfft)=b(1:nfft)                !Copy test data into a()
     t0=second()
     call four2a(a,nfft,ndim,-1,iformf) !Get planning time for forward FFT
     call four2a(a,nfft,ndim,+1,iformb) !Get planning time for backward FFT
     t2=second()
     tplan=t2-t0                        !Total planning time for this length
     
     total=0.
     do iter=1,iters                    !Now do many iterations
        a(1:nfft)=b(1:nfft)             !Copy test data into a()

        t0=second()
        call four2a(a,nfft,ndim,-1,iformf) !Forward FFT
        call four2a(a,nfft,ndim,+1,iformb) !Backward FFT on same data
        t1=second()
        total=total+t1-t0
        if(total.ge.1.0) go to 40       !Cut iterations short if t>1 s
     enddo
     iter=iters

40   time=0.5*total/iter                !Time for one FFT of current length
     tplan=0.5*tplan-time               !Planning time for one FFT
     if(tplan.lt.0) tplan=0.
     a(1:nfft)=a(1:nfft)/nfft

! Compute RMS difference between original array and back-transformed array.
     sq=0.
     if(ncomplex.eq.1) then
        do i=1,nfft
           sq=sq + real(a(i)-b(i))**2 + imag(a(i)-b(i))**2
        enddo
     else
        do i=1,nfft
           sq=sq + (ar(i)-br(i))**2
        enddo
     endif
     rms=sqrt(sq/nfft)

     freq=1.e-6*nfft/time
     mflops=5.0/(1.e6*time/(nfft*log(float(nfft))/log(2.0)))
     if(n2.eq.1 .or. n2.eq.999999) then
        write(*,1050) nfft,time,rms,freq,mflops,iter,tplan
        write(12,1050) nfft,time,rms,freq,mflops,iter,tplan
1050    format(i8,f11.7,f12.8,f7.2,f8.1,i8,f6.1)
     else
        write(*,1060) ii,nfft,time,rms,freq,mflops,iter,tplan
        write(12,1060) ii,nfft,time,rms,freq,mflops,iter,tplan
1060    format(i2,i8,f11.7,f12.8,f7.2,f8.1,i8,f6.1)
     endif
     if(mod(ii,50).eq.0) call four2a(0,-1,0,0,0)
  enddo

900  continue 
  if(nw.eq.1) then
     rewind 13
     call export_wisdom_to_file(13)
!     write(*,1070) 
!1070 format(/'Exported FFTW wisdom')
  endif

999 call four2a(0,-1,0,0,0)
end program chkfft
