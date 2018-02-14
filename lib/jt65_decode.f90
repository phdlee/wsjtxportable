module jt65_decode

  integer, parameter :: NSZ=3413, NZMAX=60*12000

  type :: jt65_decoder
     procedure(jt65_decode_callback), pointer :: callback => null()
   contains
     procedure :: decode
  end type jt65_decoder

! Callback function to be called with each decode
  abstract interface
     subroutine jt65_decode_callback(this,sync,snr,dt,freq,drift,     &
          nflip,width,decoded,ft,qual,nsmo,nsum,minsync)

       import jt65_decoder
       implicit none
       class(jt65_decoder), intent(inout) :: this
       real, intent(in) :: sync
       integer, intent(in) :: snr
       real, intent(in) :: dt
       integer, intent(in) :: freq
       integer, intent(in) :: drift
       integer, intent(in) :: nflip
       real, intent(in) :: width
       character(len=22), intent(in) :: decoded
       integer, intent(in) :: ft
       integer, intent(in) :: qual
       integer, intent(in) :: nsmo
       integer, intent(in) :: nsum
       integer, intent(in) :: minsync

     end subroutine jt65_decode_callback
  end interface

contains

  subroutine decode(this,callback,dd0,npts,newdat,nutc,nf1,nf2,nfqso,     &
       ntol,nsubmode,minsync,nagain,n2pass,nrobust,ntrials,naggressive,   &
       ndepth,emedelay,clearave,mycall,hiscall,hisgrid,nexp_decode)

!  Process dd0() data to find and decode JT65 signals.

    use jt65_mod
    use timer_module, only: timer

    include 'constants.f90'

    class(jt65_decoder), intent(inout) :: this
    procedure(jt65_decode_callback) :: callback
    real, intent(in) :: dd0(NZMAX),emedelay
    integer, intent(in) :: npts, nutc, nf1, nf2, nfqso, ntol     &
         , nsubmode, minsync, n2pass, ntrials, naggressive, ndepth      &
         , nexp_decode
    logical, intent(in) :: newdat, nagain, nrobust, clearave
    character(len=12), intent(in) :: mycall, hiscall
    character(len=6), intent(in) :: hisgrid

    real dd(NZMAX)
    real ss(322,NSZ)
    real savg(NSZ)
    real a(5)
    character*22 decoded,decoded0,avemsg,deepave
    type candidate
       real freq
       real dt
       real sync
       real flip
    end type candidate
    type(candidate) ca(300)
    type accepted_decode
       real freq
       real dt
       real sync
       character*22 decoded
    end type accepted_decode
    type(accepted_decode) dec(50)
    logical :: first_time,prtavg,single_decode,bVHF

    integer h0(0:11),d0(0:11)
    real r0(0:11)
    common/decstats/ntry65a,ntry65b,n65a,n65b,num9,numfano
    common/steve/thresh0

!            0  1  2  3  4  5  6  7  8  9 10 11
    data h0/41,42,43,43,44,45,46,47,48,48,49,49/
    data d0/71,72,73,74,76,77,78,80,81,82,83,83/

!             0    1    2    3    4    5    6    7    8    9   10   11
    data r0/0.70,0.72,0.74,0.76,0.78,0.80,0.82,0.84,0.86,0.88,0.90,0.90/
    data nutc0/-999/,nfreq0/-999/,nsave/0/
    save

    this%callback => callback
    first_time=newdat
    dd=dd0
    ndecoded=0

    if(nsubmode.ge.100) then
! This is QRA64 mode
       mode64=2**(nsubmode-100)
!###
!       open(60,file='qra64_data.bin',access='stream',position='append')
!       write(60) dd,npts,nutc,nf1,nf2,nfqso,ntol,mode64,minsync,ndepth,   &
!            mycall,hiscall,hisgrid
!       close(60)
!###
       call qra64a(dd,npts,nutc,nf1,nf2,nfqso,ntol,mode64,minsync,ndepth,   &
            emedelay,mycall,hiscall,hisgrid,sync,nsnr,dtx,nfreq,decoded,nft)
       if (associated(this%callback)) then
          ndrift=0
          nflip=1
          width=1.0
          nsmo=0
          nqual=0
          call this%callback(sync,nsnr,dtx,nfreq,ndrift,  &
               nflip,width,decoded,nft,nqual,nsmo,1,minsync)
       end if
       go to 900
    endif

    do ipass=1,n2pass                             !Two-pass decoding loop
       first_time=.true.
       if(ipass.eq.1) then                        !First-pass parameters
          thresh0=2.5
          nsubtract=1
       elseif( ipass.eq.2 ) then                  !Second-pass parameters
          thresh0=2.5
          nsubtract=0
       endif
       if(n2pass.lt.2) nsubtract=0

       !  if(newdat) then
       call timer('symsp65 ',0)
       ss=0.
       call symspec65(dd,npts,ss,nhsym,savg)    !Get normalized symbol spectra
       call timer('symsp65 ',1)
       !  endif
       nfa=nf1
       nfb=nf2
       single_decode=iand(nexp_decode,32).ne.0 .or. nagain
       bVHF=iand(nexp_decode,64).ne.0

!### Q: should either of the next two uses of "single_decode" be "bVHF" instead?       
       if(single_decode .or. (bVHF .and. ntol.lt.1000)) then
          nfa=max(200,nfqso-ntol)
          nfb=min(4000,nfqso+ntol)
          thresh0=1.0
       endif
       df=12000.0/8192.0                     !df = 1.465 Hz
       if(bVHF) then
          ia=max(1,nint(nfa/df)-ntol)
          ib=min(NSZ,nint(nfb/df)+ntol)
          nz=ib-ia+1
          call lorentzian(savg(ia),nz,a)
          baseline=a(1)
          amp=a(2)
          f0=(a(3)+ia-1)*df
          width=a(4)*df
       endif

       ncand=0
       call timer('sync65  ',0)
       call sync65(ss,nfa,nfb,naggressive,ntol,nhsym,ca,ncand,0,bVHF)
       call timer('sync65  ',1)

! If a candidate was found within +/- ntol of nfqso, move it into ca(1).
       call fqso_first(nfqso,ntol,ca,ncand)
       if(single_decode) then
          if(ncand.eq.0) ncand=1
          if(abs(ca(1)%freq - f0).gt.width) width=2*df    !### ??? ###
       endif
       nvec=ntrials
       if(ncand.gt.75) then
          nvec=100
       endif

       mode65=2**nsubmode
       nflip=1
       nqd=0
       decoded='                      '
       decoded0=""
       freq0=0.
       prtavg=.false.
       if(.not.nagain) nsum=0
       if(clearave) then
          nsum=0
          nsave=0
       endif

       if(bVHF) then
! Be sure to search for shorthand message at nfqso +/- ntol
          if(ncand.lt.300) ncand=ncand+1
          ca(ncand)%sync=5.0
          ca(ncand)%dt=2.5
          ca(ncand)%freq=nfqso
       endif

       do icand=1,ncand
          sync1=ca(icand)%sync
          dtx=ca(icand)%dt
          freq=ca(icand)%freq
          if(bVHF) then
             flip=ca(icand)%flip
             nflip=flip
          endif
          if(sync1.lt.float(minsync)) nflip=0
          if(ipass.eq.1) ntry65a=ntry65a + 1
          if(ipass.eq.2) ntry65b=ntry65b + 1
          call timer('decod65a',0)
          nft=0
          nspecial=0
          call decode65a(dd,npts,first_time,nqd,freq,nflip,mode65,nvec,     &
               naggressive,ndepth,ntol,mycall,hiscall,hisgrid,              &
               nexp_decode,bVHF,sync2,a,dtx,nft,nspecial,qual,     &
               nhist,nsmo,decoded)
          if(nspecial.eq.2) decoded='RO'
          if(nspecial.eq.3) decoded='RRR'
          if(nspecial.eq.4) decoded='73'
          call timer('decod65a',1)
          if(sync1.lt.float(minsync) .and.                                  &
               decoded.eq.'                      ') nflip=0
          if(nft.ne.0) nsum=1

          nhard_min=param(1)
          nrtt1000=param(4)
          ntotal_min=param(5)
          nsmo=param(9)

          nfreq=nint(freq+a(1))
          ndrift=nint(2.0*a(2))
          if(bVHF) then
             s2db=sync1 - 30.0 + db(width/3.3)       !### VHF/UHF/microwave
             if(nspecial.gt.0) s2db=sync2
          else
             s2db=10.0*log10(sync2) - 35             !### Empirical (HF) 
          endif
          nsnr=nint(s2db)
          if(nsnr.lt.-30) nsnr=-30
          if(nsnr.gt.-1) nsnr=-1
          nftt=0

          if(nft.ne.1 .and. iand(ndepth,16).eq.16 .and. (.not.prtavg)) then
! Single-sequence FT decode failed, so try for an average FT decode.
             if(nutc.ne.nutc0 .or. abs(nfreq-nfreq0).gt.ntol) then
! This is a new minute or a new frequency, so call avg65.
                nutc0=nutc
                nfreq0=nfreq
                nsave=nsave+1
                nsave=mod(nsave-1,64)+1
                call avg65(nutc,nsave,sync1,dtx,nflip,nfreq,mode65,ntol,     &
                     ndepth,nagain,ntrials,naggressive,clearave,neme,mycall, &
                     hiscall,hisgrid,nftt,avemsg,qave,deepave,nsum,ndeepave)
                nsmo=param(9)
                nqave=qave

                if (associated(this%callback) .and. nsum.ge.2) then
                   call this%callback(sync1,nsnr,dtx-1.0,nfreq,ndrift,  &
                        nflip,width,avemsg,nftt,nqave,nsmo,nsum,minsync)
                   prtavg=.true.
                end if

             endif
          endif

          if(nftt.eq.1) then
!             nft=1
             decoded=avemsg
             go to 5
          endif
          n=naggressive
          rtt=0.001*nrtt1000
          if(nft.lt.2 .and. minsync.ge.0 .and. nspecial.eq.0) then
             if(nhard_min.gt.50) cycle
             if(nhard_min.gt.h0(n)) cycle
             if(ntotal_min.gt.d0(n)) cycle
             if(rtt.gt.r0(n)) cycle
          endif

5         continue
          if(decoded.eq.decoded0 .and. abs(freq-freq0).lt. 3.0 .and.    &
               minsync.ge.0) cycle                  !Don't display dupes
          if(decoded.ne.'                      ' .or. minsync.lt.0) then
             if(nsubtract.eq.1) then
                call timer('subtr65 ',0)
                call subtract65(dd,npts,freq,dtx)
                call timer('subtr65 ',1)
             endif

             ndupe=0 ! de-dedupe
             do i=1, ndecoded
                if(decoded==dec(i)%decoded) then
                   ndupe=1
                   exit
                endif
             enddo
             if(ndupe.ne.1 .and. sync1.ge.float(minsync)) then 
                if(ipass.eq.1) n65a=n65a + 1
                if(ipass.eq.2) n65b=n65b + 1
                if(ndecoded.lt.50) ndecoded=ndecoded+1
                dec(ndecoded)%freq=freq+a(1)
                dec(ndecoded)%dt=dtx
                dec(ndecoded)%sync=sync2
                dec(ndecoded)%decoded=decoded
                nqual=min(qual,9999.0)

                if (associated(this%callback)) then
                   call this%callback(sync1,nsnr,dtx-1.0,nfreq,ndrift,  &
                        nflip,width,decoded,nft,nqual,nsmo,1,minsync)
                end if
             endif
             decoded0=decoded
             freq0=freq
             if(decoded0.eq.'                      ') decoded0='*'
          endif
       enddo                                 !Candidate loop
       if(ndecoded.lt.1) exit
    enddo                                    !Two-pass loop

900 return
  end subroutine decode

  subroutine avg65(nutc,nsave,snrsync,dtxx,nflip,nfreq,mode65,ntol,ndepth,    &
       nagain, ntrials,naggressive,clearave,neme,mycall,hiscall,hisgrid,nftt, &
       avemsg,qave,deepave,nsum,ndeepave)

! Decodes averaged JT65 data

    use jt65_mod
    parameter (MAXAVE=64)
    character*22 avemsg,deepave,deepbest
    character mycall*12,hiscall*12,hisgrid*6
    character*1 csync,cused(64)
    logical nagain
    integer iused(64)
! Accumulated data for message averaging
    integer iutc(MAXAVE)
    integer nfsave(MAXAVE)
    integer nflipsave(MAXAVE)
    real s1b(-255:256,126)
    real s1save(-255:256,126,MAXAVE)
    real s2(66,126)
    real s3save(64,63,MAXAVE)
    real s3b(64,63)
    real s3c(64,63)
    real dtsave(MAXAVE)
    real syncsave(MAXAVE)
    logical first,clearave
    data first/.true./
    save

    if(first .or. clearave) then
       iutc=-1
       nfsave=0
       dtdiff=0.2
       first=.false.
       s3save=0.
       s1save=0.
       nsave=1           !### ???
! Silence compiler warnings
       if(nagain .and. ndeepave.eq.-99 .and. neme.eq.-99) stop
    endif

    do i=1,64
       if(iutc(i).lt.0) exit
       if(nutc.eq.iutc(i) .and. abs(nfreq-nfsave(i)).le.ntol) go to 10
    enddo

! Save data for message averaging
    iutc(nsave)=nutc
    syncsave(nsave)=snrsync
    dtsave(nsave)=dtxx
    nfsave(nsave)=nfreq
    nflipsave(nsave)=nflip
    s1save(-255:256,1:126,nsave)=s1
    s3save(1:64,1:63,nsave)=s3a

10  syncsum=0.
    dtsum=0.
    nfsum=0
    nsum=0
    s1b=0.
    s3b=0.
    s3c=0.

    do i=1,MAXAVE                               !Consider all saved spectra
       cused(i)='.'
       if(iutc(i).lt.0) cycle
       if(mod(iutc(i),2).ne.mod(nutc,2)) cycle  !Use only same (odd/even) seq
       if(abs(dtxx-dtsave(i)).gt.dtdiff) cycle  !DT must match
       if(abs(nfreq-nfsave(i)).gt.ntol) cycle   !Freq must match
       if(nflip.ne.nflipsave(i)) cycle          !Sync type (*/#) must match
       s3b=s3b + s3save(1:64,1:63,i)
       s1b=s1b + s1save(-255:256,1:126,i)
       syncsum=syncsum + syncsave(i)
       dtsum=dtsum + dtsave(i)
       nfsum=nfsum + nfsave(i)
       cused(i)='$'
       nsum=nsum+1
       iused(nsum)=i
    enddo
    if(nsum.lt.64) iused(nsum+1)=0

    syncave=0.
    dtave=0.
    fave=0.
    if(nsum.gt.0) then
       syncave=syncsum/nsum
       dtave=dtsum/nsum
       fave=float(nfsum)/nsum
    endif

    do i=1,nsave
       csync='*'
       if(nflipsave(i).lt.0.0) csync='#'
       write(14,1000) cused(i),iutc(i),syncsave(i),dtsave(i)-1.0,nfsave(i),csync
1000   format(a1,i5.4,f6.1,f6.2,i6,1x,a1)
    enddo
    if(nsum.lt.2) go to 900

    nftt=0
    df=1378.125/512.0

! Do the smoothing loop
    qualbest=0.
    minsmo=0
    maxsmo=0
    if(mode65.ge.2) then
       minsmo=nint(width/df)
       maxsmo=2*minsmo
    endif
    nn=0
    do ismo=minsmo,maxsmo
       if(ismo.gt.0) then
          do j=1,126
             call smo121(s1b(-255,j),512)
             if(j.eq.1) nn=nn+1
             if(nn.ge.4) then
                call smo121(s1b(-255,j),512)
                if(j.eq.1) nn=nn+1
             endif
          enddo
       endif

       do i=1,66
          jj=i
          if(mode65.eq.2) jj=2*i-1
          if(mode65.eq.4) then
             ff=4*(i-1)*df - 355.297852
             jj=nint(ff/df)+1
          endif
          s2(i,1:126)=s1b(jj,1:126)
       enddo

       do j=1,63
          k=mdat(j)                       !Points to data symbol
          if(nflip.lt.0) k=mdat2(j)
          do i=1,64
             s3c(i,j)=4.e-5*s2(i+2,k)
          enddo
       enddo

       nadd=nsum*ismo
       call extract(s3c,nadd,mode65,ntrials,naggressive,ndepth,nflip,mycall, &
            hiscall,hisgrid,nexp_decode,ncount,nhist,avemsg,ltext,nftt,qual)
       if(nftt.eq.1) then
          nsmo=ismo
          param(9)=nsmo
          go to 900
       else if(nftt.eq.2) then
          if(qual.gt.qualbest) then
             deepbest=avemsg
             qualbest=qual
             nnbest=nn
             nsmobest=ismo
             nfttbest=nftt
          endif
       endif
    enddo

    if(nfttbest.eq.2) then
       avemsg=deepbest       !### ???
       deepave=deepbest
       qave=qualbest
       nsmo=nsmobest
       param(9)=nsmo
       nftt=nfttbest
    endif
900 continue

    return
  end subroutine avg65

end module jt65_decode
