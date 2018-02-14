subroutine bpdecode168(llr,apmask,maxiterations,decoded,niterations)
!
! A log-domain belief propagation decoder for the (168,84) code.
!
integer, parameter:: N=168, K=84, M=N-K
integer*1 codeword(N),cw(N),apmask(N)
integer  colorder(N)
integer*1 decoded(K)
integer Nm(7,M)  ! 5, 6, or 7 bits per check 
integer Mn(3,N)  ! 3 checks per bit
integer synd(M)
real tov(3,N)
real toc(7,M)
real tanhtoc(7,M)
real zn(N)
real llr(N)
real Tmn
integer nrw(M)

data colorder/0,1,2,3,28,4,5,6,7,8,9,10,11,34,12,32,13,14,15,16,17, &
   18,36,29,42,31,20,21,41,40,30,38,22,19,47,37,46,35,44,33,49,24, &
   43,51,25,26,27,50,52,57,69,54,55,45,59,58,56,61,60,53,48,23,62, &
   63,64,67,66,65,68,39,70,71,72,74,73,75,76,77,80,81,78,82,79,83, &
   84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100,101,102,103,104, &
   105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125, &
   126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146, &
   147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167/

data Mn/               &
  1,24,67, &
  2,5,71, &
  3,31,66, &
  4,50,58, &
  6,60,65, &
  7,32,76, &
  8,49,83, &
  9,36,41, &
  10,40,63, &
  11,14,62, &
  12,72,75, &
  13,23,78, &
  15,16,80, &
  17,54,64, &
  18,51,59, &
  19,30,48, &
  20,68,81, &
  21,29,70, &
  22,25,43, &
  26,34,73, &
  27,35,37, &
  28,39,44, &
  33,53,55, &
  38,52,84, &
  42,56,57, &
  45,74,82, &
  46,69,79, &
  47,61,77, &
  1,4,5, &
  2,48,52, &
  3,47,82, &
  6,26,76, &
  7,9,16, &
  8,10,78, &
  11,36,56, &
  12,38,65, &
  13,43,81, &
  14,33,68, &
  15,18,44, &
  17,59,77, &
  19,27,69, &
  20,21,58, &
  22,45,79, &
  23,34,54, &
  24,28,40, &
  25,80,84, &
  29,37,51, &
  30,42,83, &
  31,63,72, &
  32,50,66, &
  35,67,73, &
  39,55,74, &
  41,61,71, &
  46,60,62, &
  49,70,74, &
  53,64,75, &
  25,57,67, &
  1,46,64, &
  2,51,63, &
  3,14,80, &
  4,15,78, &
  5,27,74, &
  6,13,70, &
  7,19,20, &
  8,38,77, &
  9,75,83, &
  10,36,69, &
  11,22,29, &
  12,58,82, &
  16,35,60, &
  17,32,43, &
  18,42,45, &
  21,53,84, &
  23,39,48, &
  24,52,68, &
  26,33,61, &
  28,56,76, &
  30,65,66, &
  31,34,49, &
  37,47,81, &
  16,40,54, &
  41,44,65, &
  50,73,79, &
  55,59,60, &
  54,57,71, &
  23,62,72, &
  1,36,47, &
  2,32,70, &
  3,28,69, &
  4,7,33, &
  5,20,26, &
  6,14,63, &
  8,22,68, &
  9,13,67, &
  10,55,71, &
  11,15,19, &
  12,51,56, &
  17,27,52, &
  18,34,46, &
  21,41,42, &
  24,50,80, &
  25,39,75, &
  29,54,76, &
  30,40,84, &
  31,35,58, &
  37,79,83, &
  38,43,73, &
  44,72,81, &
  7,45,62, &
  47,48,49, &
  53,57,78, &
  20,59,66, &
  28,61,64, &
  11,75,77, &
  33,54,82, &
  1,14,44, &
  2,62,73, &
  3,9,26, &
  4,37,84, &
  5,56,80, &
  6,45,71, &
  8,67,72, &
  10,76,81, &
  12,32,78, &
  13,59,82, &
  15,17,79, &
  16,42,69, &
  18,61,70, &
  19,31,64, &
  21,39,63, &
  22,30,58, &
  23,27,66, &
  24,41,49, &
  25,36,60, &
  29,65,67, &
  34,36,53, &
  35,48,76, &
  15,38,55, &
  40,43,74, &
  46,52,57, &
  50,63,77, &
  51,68,69, &
  2,44,83, &
  1,30,55, &
  3,29,78, &
  4,34,65, &
  5,31,38, &
  6,52,58, &
  7,25,51, &
  8,16,66, &
  9,46,74, &
  10,70,75, &
  11,32,84, &
  12,48,79, &
  13,50,64, &
  14,37,57, &
  17,42,72, &
  18,43,48, &
  19,24,60, &
  20,54,83, &
  21,47,62, &
  22,28,59, &
  23,61,80, &
  8,26,39, &
  27,44,53, &
  33,49,56, &
  35,68,71, &
  12,26,40/

data Nm/               &
   1,29,58,87,116,144,0,&
   2,30,59,88,117,143,0,&
   3,31,60,89,118,145,0,&
   4,29,61,90,119,146,0,&
   2,29,62,91,120,147,0,&
   5,32,63,92,121,148,0,&
   6,33,64,90,109,149,0,&
   7,34,65,93,122,150,164,&
   8,33,66,94,118,151,0,&
   9,34,67,95,123,152,0,&
   10,35,68,96,114,153,0,&
   11,36,69,97,124,154,168,&
   12,37,63,94,125,155,0,&
   10,38,60,92,116,156,0,&
   13,39,61,96,126,138,0,&
   13,33,70,81,127,150,0,&
   14,40,71,98,126,157,0,&
   15,39,72,99,128,158,0,&
   16,41,64,96,129,159,0,&
   17,42,64,91,112,160,0,&
   18,42,73,100,130,161,0,&
   19,43,68,93,131,162,0,&
   12,44,74,86,132,163,0,&
   1,45,75,101,133,159,0,&
   19,46,57,102,134,149,0,&
   20,32,76,91,118,164,168,&
   21,41,62,98,132,165,0,&
   22,45,77,89,113,162,0,&
   18,47,68,103,135,145,0,&
   16,48,78,104,131,144,0,&
   3,49,79,105,129,147,0,&
   6,50,71,88,124,153,0,&
   23,38,76,90,115,166,0,&
   20,44,79,99,136,146,0,&
   21,51,70,105,137,167,0,&
   8,35,67,87,134,136,0,&
   21,47,80,106,119,156,0,&
   24,36,65,107,138,147,0,&
   22,52,74,102,130,164,0,&
   9,45,81,104,139,168,0,&
   8,53,82,100,133,0,0,&
   25,48,72,100,127,157,0,&
   19,37,71,107,139,158,0,&
   22,39,82,108,116,143,165,&
   26,43,72,109,121,0,0,&
   27,54,58,99,140,151,0,&
   28,31,80,87,110,161,0,&
   16,30,74,110,137,154,158,&
   7,55,79,110,133,166,0,&
   4,50,83,101,141,155,0,&
   15,47,59,97,142,149,0,&
   24,30,75,98,140,148,0,&
   23,56,73,111,136,165,0,&
   14,44,81,85,103,115,160,&
   23,52,84,95,138,144,0,&
   25,35,77,97,120,166,0,&
   25,57,85,111,140,156,0,&
   4,42,69,105,131,148,0,&
   15,40,84,112,125,162,0,&
   5,54,70,84,134,159,0,&
   28,53,76,113,128,163,0,&
   10,54,86,109,117,161,0,&
   9,49,59,92,130,141,0,&
   14,56,58,113,129,155,0,&
   5,36,78,82,135,146,0,&
   3,50,78,112,132,150,0,&
   1,51,57,94,122,135,0,&
   17,38,75,93,142,167,0,&
   27,41,67,89,127,142,0,&
   18,55,63,88,128,152,0,&
   2,53,85,95,121,167,0,&
   11,49,86,108,122,157,0,&
   20,51,83,107,117,0,0,&
   26,52,55,62,139,151,0,&
   11,56,66,102,114,152,0,&
   6,32,77,103,123,137,0,&
   28,40,65,114,141,0,0,&
   12,34,61,111,124,145,0,&
   27,43,83,106,126,154,0,&
   13,46,60,101,120,163,0,&
   17,37,80,108,123,0,0,&
   26,31,69,115,125,0,0,&
   7,48,66,106,143,160,0,&
   24,46,73,104,119,153,0/

data nrw/   &
6,6,6,6,6,6,6,7,6,6,6,7,6,6,6,6,6,6,6,6,6, &
6,6,6,6,7,6,6,6,6,6,6,6,6,6,6,6,6,6,6,5,6, &
6,7,5,6,6,7,6,6,6,6,6,7,6,6,6,6,6,6,6,6,6, &
6,6,6,6,6,6,6,6,6,5,6,6,6,5,6,6,6,5,5,6,6/

ncw=3

toc=0
tov=0
tanhtoc=0
!write(*,*) llr
! initialize messages to checks
do j=1,M
  do i=1,nrw(j)
    toc(i,j)=llr((Nm(i,j)))
  enddo
enddo

ncnt=0

do iter=0,maxiterations

! Update bit log likelihood ratios (tov=0 in iteration 0).
  do i=1,N
    if( apmask(i) .ne. 1 ) then
      zn(i)=llr(i)+sum(tov(1:ncw,i))
    else
      zn(i)=llr(i)
    endif
  enddo

! Check to see if we have a codeword (check before we do any iteration).
  cw=0
  where( zn .gt. 0. ) cw=1
  ncheck=0
  do i=1,M
    synd(i)=sum(cw(Nm(1:nrw(i),i)))
    if( mod(synd(i),2) .ne. 0 ) ncheck=ncheck+1
!    if( mod(synd(i),2) .ne. 0 ) write(*,*) 'check ',i,' unsatisfied'
  enddo
!write(*,*) 'number of unsatisfied parity checks ',ncheck
  if( ncheck .eq. 0 ) then ! we have a codeword - reorder the columns and return it
    niterations=iter
    codeword=cw(colorder+1)
    decoded=codeword(M+1:N)
    return
  endif

  if( iter.gt.0 ) then  ! this code block implements an early stopping criterion
    nd=ncheck-nclast
    if( nd .lt. 0 ) then ! # of unsatisfied parity checks decreased
      ncnt=0  ! reset counter
    else
      ncnt=ncnt+1
    endif
!    write(*,*) iter,ncheck,nd,ncnt
    if( ncnt .ge. 3 .and. iter .ge. 5 .and. ncheck .gt. 10) then
      niterations=-1
      return
    endif
  endif
  nclast=ncheck

! Send messages from bits to check nodes 
  do j=1,M
    do i=1,nrw(j)
      ibj=Nm(i,j)
      toc(i,j)=zn(ibj)  
      do kk=1,ncw ! subtract off what the bit had received from the check
        if( Mn(kk,ibj) .eq. j ) then  
          toc(i,j)=toc(i,j)-tov(kk,ibj)
        endif
      enddo
    enddo
  enddo

! send messages from check nodes to variable nodes
  do i=1,M
    tanhtoc(1:7,i)=tanh(-toc(1:7,i)/2)
  enddo

  do j=1,N
    do i=1,ncw
      ichk=Mn(i,j)  ! Mn(:,j) are the checks that include bit j
      Tmn=product(tanhtoc(1:nrw(ichk),ichk),mask=Nm(1:nrw(ichk),ichk).ne.j)
      call platanh(-Tmn,y)
!      y=atanh(-Tmn)
      tov(i,j)=2*y
    enddo
  enddo

enddo
niterations=-1
return
end subroutine bpdecode168
