program msk144d2

  ! Test the msk144 decoder for WSJT-X

  use options
  use timer_module, only: timer
  use timer_impl, only: init_timer
  use readwav

  character c
  character*80 line
  character*512 datadir
  character*500 infile
  character*12 mycall,hiscall
  character*6 mygrid
  character(len=500) optarg

  logical :: display_help=.false.
  logical*1 bShMsgs
  logical*1 bcontest
  logical*1 btrain
  logical*1 bswl

  type(wav_header) :: wav

  integer*2 id2(30*12000)
  integer*2 ichunk(7*1024)

  real*8 pcoeffs(5)

  type (option) :: long_options(9) = [ &
       option ('ndepth',.true.,'c','ndepth',''), &  
       option ('dxcall',.true.,'d','hiscall',''), &  
       option ('evemode',.true.,'e','Must be used with -s.',''), &
       option ('frequency',.true.,'f','rxfreq',''), &
       option ('help',.false.,'h','Display this help message',''), &
       option ('mycall',.true.,'m','mycall',''), &
       option ('nftol',.true.,'n','nftol',''), &
       option ('rxequalize',.false.,'r','Rx Equalize',''), &
       option ('short',.false.,'s','enable Sh','') &
       ]
  t0=0.0
  ndepth=3
  ntol=100
  nrxfreq=1500
  mycall=''
  mygrid='EN50WC'
  hiscall=''
  bShMsgs=.false.
  bcontest=.false.
  btrain=.false.
  bswl=.false.
  datadir='.'
  pcoeffs=0.d0
 
  do
     call getopt('c:d:ef:hm:n:rs',long_options,c,optarg,narglen,nstat,noffset,nremain,.true.)
     if( nstat .ne. 0 ) then
        exit
     end if
     select case (c)
     case ('c')
        read (optarg(:narglen), *) ndepth 
     case ('d')
        read (optarg(:narglen), *) hiscall
     case ('e')
        bswl=.true. 
     case ('f')
        read (optarg(:narglen), *) nrxfreq
     case ('h')
        display_help = .true.
     case ('m')
        read (optarg(:narglen), *) mycall
     case ('n')
        read (optarg(:narglen), *) ntol
     case ('r')
        btrain=.true. 
     case ('s')
        bShMsgs=.true. 
     end select
  end do

  if(display_help .or. nstat.lt.0 .or. nremain.lt.1) then
     print *, ''
     print *, 'Usage: msk144d [OPTIONS] file1 [file2 ...]'
     print *, ''
     print *, '       msk144 decode pre-recorded .WAV file(s)'
     print *, ''
     print *, 'OPTIONS:'
     do i = 1, size (long_options)
        call long_options(i) % print (6)
     end do
     go to 999
  endif

  call init_timer ('timer.out')
  call timer('msk144  ',0)
  ndecoded=0
  do ifile=noffset+1,noffset+nremain
     call get_command_argument(ifile,optarg,narglen)
     infile=optarg(:narglen)
     call timer('read    ',0)
     call wav%read (infile)
     i1=index(infile,'.wav')
     if( i1 .eq. 0 ) i1=index(infile,'.WAV')
     read(infile(i1-6:i1-1),*,err=998) nutc
     inquire(FILE=infile,SIZE=isize)
     npts=min((isize-216)/2,360000)
     read(unit=wav%lun) id2(1:npts)
     close(unit=wav%lun)
     call timer('read    ',1)

     do i=1,npts-7*1024+1,7*512
       ichunk=id2(i:i+7*1024-1)
       tsec=(i-1)/12000.0
       tt=sum(float(abs(id2(i:i+7*512-1))))
       if( tt .ne. 0.0 ) then
         call mskrtd(ichunk,nutc,tsec,ntol,nrxfreq,ndepth,mycall,mygrid,hiscall,bShMsgs, &
                     bcontest,btrain,pcoeffs,bswl,datadir,line)
         if( index(line,"&") .ne. 0 .or.   &
              index(line,"^") .ne. 0 .or.   &
              index(line,"!") .ne. 0 .or.   &
              index(line,"@") .ne. 0 ) then 
           write(*,*) line
         endif
       endif
     enddo 
  enddo

  call timer('msk144  ',1)
  call timer('msk144  ',101)
  go to 999

998 print*,'Cannot read from file:'
  print*,infile

999 continue
end program msk144d2
