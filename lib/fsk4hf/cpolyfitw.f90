subroutine cpolyfitw(c,pp,id,maxn,aa,bb,zz,nhardsync)

  include 'wsprlf_params.f90'

  complex c(0:NZ-1)                     !Complex waveform
  complex zz(NS+ND)                     !Complex symbol values (intermediate)
  complex z,z0
  real x(NS),yi(NS),yq(NS)              !For complex polyfit
  real pp(2*NSPS)                       !Shaped pulse for OQPSK
  real aa(20),bb(20)                    !Fitted polyco's
  integer id(NS+ND)                     !NRZ values (+/-1) for Sync and Data

  ib=NSPS-1
  ib2=N2-1
  n=0
  jz=(NS+ND+1)/2
  do j=1,jz                                !First-pass demodulation
     ia=ib+1
     ib=ia+N2-1
     zz(j)=sum(pp*c(ia:ib))/NSPS
     if(abs(id(j)).eq.2) then               !Save all sync symbols
        n=n+1
        x(n)=float(ia+ib)/NZ - 1.0
        yi(n)=real(zz(j))*0.5*id(j)
        yq(n)=aimag(zz(j))*0.5*id(j)
!        write(54,1225) n,x(n),yi(n),yq(n)
!1225    format(i5,3f12.4)
     endif
     if(j.lt.jz) then
        zz(j+jz)=sum(pp*c(ia+NSPS:ib+NSPS))/NSPS
     endif
  enddo
  
  aa=0.
  bb=0.
  nterms=0
  chisqa=0.
  chisqb=0.
  if(maxn.gt.0) then
     npts=n
     mode=0
     nterms=maxn
     call polyfit4(x,yi,yi,npts,nterms,mode,aa,chisqa)
     call polyfit4(x,yq,yq,npts,nterms,mode,bb,chisqb)
  endif
  
  nhardsync=0
  do j=1,205
     if(abs(id(j)).ne.2) cycle
     xx=j*2.0/205.0 - 1.0
     yii=1.
     yqq=0.
     if(nterms.gt.0) then
        yii=aa(1)
        yqq=bb(1)
        do i=2,nterms
           yii=yii + aa(i)*xx**(i-1)
           yqq=yqq + bb(i)*xx**(i-1)
        enddo
     endif
     z0=cmplx(yii,yqq)
     z=zz(j)*conjg(z0)
     p=real(z)
     if(p*id(j).lt.0) nhardsync=nhardsync+1
  enddo
  
  return
end subroutine cpolyfitw
